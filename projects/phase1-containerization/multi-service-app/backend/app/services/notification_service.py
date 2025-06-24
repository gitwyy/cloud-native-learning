"""
通知服务
处理通知的创建、发送和管理
"""

import json
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, desc, asc
from sqlalchemy.orm import selectinload

from app.core.cache import cache_manager
from app.models.user import User
from app.models.notification import (
    Notification, NotificationTemplate, NotificationSetting,
    NotificationType, NotificationPriority, NotificationStatus
)
from app.schemas.notification import (
    NotificationCreate, NotificationUpdate, NotificationListParams,
    NotificationStats, NotificationTemplateCreate, NotificationTemplateUpdate,
    NotificationSettingUpdate, NotificationBatchUpdate, NotificationBatchDelete,
    NotificationSendRequest
)
from app.utils.logger import setup_logger

logger = setup_logger(__name__)


class NotificationService:
    """通知服务类"""
    
    async def create_notification(self, notification_data: NotificationCreate, 
                                current_user: User, db: AsyncSession) -> Notification:
        """创建通知"""
        try:
            # 确定目标用户
            target_user_id = notification_data.user_id or current_user.id
            
            # 创建新通知
            new_notification = Notification(
                user_id=target_user_id,
                title=notification_data.title,
                message=notification_data.message,
                notification_type=notification_data.notification_type,
                priority=notification_data.priority,
                resource_type=notification_data.resource_type,
                resource_id=notification_data.resource_id,
                scheduled_at=notification_data.scheduled_at,
                expires_at=notification_data.expires_at,
                action_url=notification_data.action_url,
                action_text=notification_data.action_text,
                status=NotificationStatus.PENDING
            )
            
            # 设置发送渠道
            if notification_data.channels:
                new_notification.channel_list = notification_data.channels
            
            # 设置元数据
            if notification_data.metadata:
                new_notification.meta_data = json.dumps(notification_data.metadata)
            
            db.add(new_notification)
            await db.commit()
            await db.refresh(new_notification)
            
            # 立即发送或安排发送
            if not notification_data.scheduled_at or notification_data.scheduled_at <= datetime.utcnow():
                await self._send_notification(new_notification, db)
            
            # 清除相关缓存
            await self._clear_notification_cache(target_user_id)
            
            logger.info(f"创建通知: {new_notification.title} -> 用户 {target_user_id}")
            
            return new_notification
            
        except Exception as e:
            logger.error(f"创建通知失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="创建通知失败"
            )
    
    async def get_notification_by_id(self, notification_id: int, user: User, db: AsyncSession) -> Notification:
        """根据ID获取通知"""
        try:
            # 从数据库获取通知
            notification_query = await db.execute(
                select(Notification)
                .where(and_(
                    Notification.id == notification_id,
                    Notification.user_id == user.id,
                    Notification.is_deleted == False
                ))
            )
            notification = notification_query.scalar_one_or_none()
            
            if not notification:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="通知不存在"
                )
            
            return notification
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"获取通知失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="获取通知失败"
            )
    
    async def get_user_notifications(self, user: User, params: NotificationListParams, 
                                   db: AsyncSession) -> Dict[str, Any]:
        """获取用户通知列表"""
        try:
            # 构建查询条件
            conditions = [
                Notification.user_id == user.id,
                Notification.is_deleted == False
            ]
            
            # 添加筛选条件
            if params.notification_type:
                conditions.append(Notification.notification_type == params.notification_type)
            
            if params.priority:
                conditions.append(Notification.priority == params.priority)
            
            if params.status:
                conditions.append(Notification.status == params.status)
            
            if params.is_read is not None:
                conditions.append(Notification.is_read == params.is_read)
            
            if params.is_archived is not None:
                conditions.append(Notification.is_archived == params.is_archived)
            
            if params.resource_type:
                conditions.append(Notification.resource_type == params.resource_type)
            
            if params.search:
                search_term = f"%{params.search}%"
                conditions.append(
                    or_(
                        Notification.title.ilike(search_term),
                        Notification.message.ilike(search_term)
                    )
                )
            
            # 构建查询
            query = select(Notification).where(and_(*conditions))
            
            # 添加排序
            if params.sort_by == "created_at":
                order_column = Notification.created_at
            elif params.sort_by == "sent_at":
                order_column = Notification.sent_at
            elif params.sort_by == "read_at":
                order_column = Notification.read_at
            elif params.sort_by == "priority":
                order_column = Notification.priority
            else:
                order_column = Notification.created_at
            
            if params.sort_order == "asc":
                query = query.order_by(asc(order_column))
            else:
                query = query.order_by(desc(order_column))
            
            # 获取总数
            count_query = select(func.count()).select_from(
                select(Notification).where(and_(*conditions)).subquery()
            )
            total_result = await db.execute(count_query)
            total = total_result.scalar()
            
            # 分页
            offset = (params.page - 1) * params.page_size
            query = query.offset(offset).limit(params.page_size)
            
            # 执行查询
            result = await db.execute(query)
            notifications = result.scalars().all()
            
            # 计算分页信息
            total_pages = (total + params.page_size - 1) // params.page_size
            
            return {
                "notifications": notifications,
                "total": total,
                "page": params.page,
                "page_size": params.page_size,
                "total_pages": total_pages,
                "has_next": params.page < total_pages,
                "has_prev": params.page > 1
            }
            
        except Exception as e:
            logger.error(f"获取通知列表失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="获取通知列表失败"
            )
    
    async def mark_notification_read(self, notification_id: int, user: User, db: AsyncSession) -> Notification:
        """标记通知为已读"""
        try:
            # 获取通知
            notification = await self.get_notification_by_id(notification_id, user, db)
            
            # 标记为已读
            if not notification.is_read:
                notification.mark_as_read()
                await db.commit()
                
                # 清除缓存
                await self._clear_notification_cache(user.id)
                
                logger.info(f"用户 {user.username} 标记通知 {notification_id} 为已读")
            
            return notification
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"标记通知已读失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="标记通知已读失败"
            )
    
    async def mark_all_notifications_read(self, user: User, db: AsyncSession) -> Dict[str, Any]:
        """标记所有通知为已读"""
        try:
            # 获取所有未读通知
            unread_notifications_query = await db.execute(
                select(Notification).where(
                    and_(
                        Notification.user_id == user.id,
                        Notification.is_read == False,
                        Notification.is_deleted == False
                    )
                )
            )
            unread_notifications = unread_notifications_query.scalars().all()
            
            read_count = 0
            current_time = datetime.utcnow()
            
            for notification in unread_notifications:
                notification.is_read = True
                notification.read_at = current_time
                notification.status = NotificationStatus.READ
                read_count += 1
            
            await db.commit()
            
            # 清除缓存
            await self._clear_notification_cache(user.id)
            
            logger.info(f"用户 {user.username} 标记所有通知为已读，共 {read_count} 条")
            
            return {
                "read_count": read_count,
                "message": f"已标记 {read_count} 条通知为已读"
            }
            
        except Exception as e:
            logger.error(f"标记所有通知已读失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="标记所有通知已读失败"
            )
    
    async def delete_notification(self, notification_id: int, user: User, 
                                db: AsyncSession, permanent: bool = False) -> bool:
        """删除通知"""
        try:
            # 获取通知
            notification = await self.get_notification_by_id(notification_id, user, db)
            
            if permanent:
                # 永久删除
                await db.delete(notification)
                action = "永久删除"
            else:
                # 软删除
                notification.soft_delete()
                action = "删除"
            
            await db.commit()
            
            # 清除缓存
            await self._clear_notification_cache(user.id)
            
            logger.info(f"用户 {user.username} {action}通知: {notification.title}")
            
            return True
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"删除通知失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="删除通知失败"
            )
    
    async def get_notification_stats(self, user: User, db: AsyncSession) -> NotificationStats:
        """获取通知统计信息"""
        try:
            # 缓存键
            cache_key = f"notification_stats:{user.id}"
            
            # 尝试从缓存获取
            cached_stats = await cache_manager.get_json(cache_key)
            if cached_stats:
                return NotificationStats(**cached_stats)
            
            # 从数据库统计
            base_query = select(Notification).where(
                and_(Notification.user_id == user.id, Notification.is_deleted == False)
            )
            
            # 总通知数
            total_result = await db.execute(select(func.count()).select_from(base_query.subquery()))
            total_notifications = total_result.scalar()
            
            # 未读通知数
            unread_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(Notification.is_read == False).subquery()
                )
            )
            unread_notifications = unread_result.scalar()
            
            # 已读通知数
            read_notifications = total_notifications - unread_notifications
            
            # 归档通知数
            archived_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(Notification.is_archived == True).subquery()
                )
            )
            archived_notifications = archived_result.scalar()
            
            # 按状态统计
            status_stats = {}
            for status in NotificationStatus:
                status_result = await db.execute(
                    select(func.count()).select_from(
                        base_query.where(Notification.status == status).subquery()
                    )
                )
                status_stats[f"{status.value}_notifications"] = status_result.scalar()
            
            # 按类型统计
            task_types = [
                NotificationType.TASK_CREATED,
                NotificationType.TASK_UPDATED,
                NotificationType.TASK_COMPLETED,
                NotificationType.TASK_OVERDUE,
                NotificationType.TASK_DUE_SOON
            ]
            
            task_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(Notification.notification_type.in_(task_types)).subquery()
                )
            )
            task_notifications = task_result.scalar()
            
            system_types = [
                NotificationType.SYSTEM_MAINTENANCE,
                NotificationType.SYSTEM_UPDATE
            ]
            
            system_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(Notification.notification_type.in_(system_types)).subquery()
                )
            )
            system_notifications = system_result.scalar()
            
            security_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(Notification.notification_type == NotificationType.SECURITY_ALERT).subquery()
                )
            )
            security_notifications = security_result.scalar()
            
            # 按优先级统计
            priority_stats = {}
            for priority in NotificationPriority:
                priority_result = await db.execute(
                    select(func.count()).select_from(
                        base_query.where(Notification.priority == priority).subquery()
                    )
                )
                priority_stats[priority.value] = priority_result.scalar()
            
            # 构建统计结果
            stats = NotificationStats(
                total_notifications=total_notifications,
                unread_notifications=unread_notifications,
                read_notifications=read_notifications,
                archived_notifications=archived_notifications,
                task_notifications=task_notifications,
                system_notifications=system_notifications,
                security_notifications=security_notifications,
                **status_stats,
                **priority_stats
            )
            
            # 缓存结果
            await cache_manager.set_json(cache_key, stats.dict(), expire=300)  # 5分钟缓存
            
            return stats
            
        except Exception as e:
            logger.error(f"获取通知统计失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="获取通知统计失败"
            )
    
    async def send_notification(self, send_request: NotificationSendRequest, 
                              current_user: User, db: AsyncSession) -> Dict[str, Any]:
        """发送通知"""
        try:
            # 确定目标用户
            target_user_ids = send_request.user_ids or [current_user.id]
            
            # 获取模板（如果指定）
            template = None
            if send_request.template_name:
                template_query = await db.execute(
                    select(NotificationTemplate).where(
                        and_(
                            NotificationTemplate.name == send_request.template_name,
                            NotificationTemplate.is_active == True
                        )
                    )
                )
                template = template_query.scalar_one_or_none()
                
                if not template:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="通知模板不存在"
                    )
            
            sent_count = 0
            failed_count = 0
            
            for user_id in target_user_ids:
                try:
                    # 渲染通知内容
                    if template:
                        rendered = template.render(send_request.context or {})
                        title = send_request.title or rendered.get("title")
                        message = send_request.message or rendered.get("message")
                        notification_type = template.notification_type
                        priority = send_request.priority or template.default_priority
                        channels = send_request.channels or template.default_channels.split(",") if template.default_channels else None
                    else:
                        title = send_request.title
                        message = send_request.message
                        notification_type = NotificationType.REMINDER
                        priority = send_request.priority or NotificationPriority.MEDIUM
                        channels = send_request.channels
                    
                    # 创建通知
                    notification = Notification(
                        user_id=user_id,
                        title=title,
                        message=message,
                        notification_type=notification_type,
                        priority=priority,
                        scheduled_at=send_request.scheduled_at,
                        status=NotificationStatus.PENDING
                    )
                    
                    if channels:
                        notification.channel_list = channels
                    
                    db.add(notification)
                    await db.flush()
                    
                    # 发送通知
                    if not send_request.scheduled_at or send_request.scheduled_at <= datetime.utcnow():
                        await self._send_notification(notification, db)
                    
                    sent_count += 1
                    
                except Exception as e:
                    logger.error(f"发送通知给用户 {user_id} 失败: {e}")
                    failed_count += 1
            
            await db.commit()
            
            # 清除缓存
            for user_id in target_user_ids:
                await self._clear_notification_cache(user_id)
            
            logger.info(f"批量发送通知完成: 成功 {sent_count}, 失败 {failed_count}")
            
            return {
                "sent_count": sent_count,
                "failed_count": failed_count,
                "total_count": len(target_user_ids),
                "message": f"成功发送 {sent_count} 条通知"
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"发送通知失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="发送通知失败"
            )
    
    async def _send_notification(self, notification: Notification, db: AsyncSession):
        """实际发送通知"""
        try:
            # 这里实现具体的发送逻辑
            # 可以根据渠道发送到不同的地方（邮件、推送、WebSocket等）
            
            channels = notification.channel_list
            
            for channel in channels:
                if channel == "email":
                    # 发送邮件通知
                    await self._send_email_notification(notification)
                    notification.email_sent = True
                elif channel == "push":
                    # 发送推送通知
                    await self._send_push_notification(notification)
                    notification.push_sent = True
                elif channel == "websocket":
                    # 发送WebSocket通知
                    await self._send_websocket_notification(notification)
                    notification.websocket_sent = True
            
            # 标记为已发送
            notification.mark_as_sent()
            
        except Exception as e:
            logger.error(f"发送通知失败: {e}")
            notification.mark_as_failed(str(e))
    
    async def _send_email_notification(self, notification: Notification):
        """发送邮件通知"""
        # TODO: 实现邮件发送逻辑
        logger.info(f"模拟发送邮件通知: {notification.title}")
    
    async def _send_push_notification(self, notification: Notification):
        """发送推送通知"""
        # TODO: 实现推送通知逻辑
        logger.info(f"模拟发送推送通知: {notification.title}")
    
    async def _send_websocket_notification(self, notification: Notification):
        """发送WebSocket通知"""
        # TODO: 实现WebSocket通知逻辑
        logger.info(f"模拟发送WebSocket通知: {notification.title}")
    
    async def _clear_notification_cache(self, user_id: int):
        """清除通知相关缓存"""
        try:
            await cache_manager.delete(f"notification_stats:{user_id}")
            # 可以添加更多缓存清理逻辑
        except Exception as e:
            logger.error(f"清除通知缓存失败: {e}")


# 全局通知服务实例
notification_service = NotificationService()