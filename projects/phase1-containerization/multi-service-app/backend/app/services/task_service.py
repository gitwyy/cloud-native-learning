"""
任务管理服务
处理任务CRUD操作和业务逻辑
"""

from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, desc, asc
from sqlalchemy.orm import selectinload

from app.core.cache import cache_manager
from app.models.user import User
from app.models.task import Task, TaskComment, TaskActivity, TaskStatus, TaskPriority
from app.schemas.task import (
    TaskCreate, TaskUpdate, TaskListParams, TaskStats,
    TaskCommentCreate, TaskBatchUpdate, TaskBatchDelete
)
from app.utils.logger import setup_logger

logger = setup_logger(__name__)


class TaskService:
    """任务服务类"""
    
    async def create_task(self, task_data: TaskCreate, user: User, db: AsyncSession) -> Task:
        """创建任务"""
        try:
            # 创建新任务
            new_task = Task(
                title=task_data.title,
                description=task_data.description,
                priority=task_data.priority,
                category=task_data.category,
                due_date=task_data.due_date,
                estimated_hours=task_data.estimated_hours,
                notes=task_data.notes,
                owner_id=user.id,
                status=TaskStatus.PENDING,
                progress=0
            )
            
            # 设置标签
            if task_data.tags:
                new_task.tag_list = task_data.tags
            
            db.add(new_task)
            await db.commit()
            await db.refresh(new_task)
            
            # 记录活动
            await self._create_activity(
                task_id=new_task.id,
                user_id=user.id,
                activity_type="task_created",
                description=f"创建了任务 '{new_task.title}'",
                db=db
            )
            
            # 清除相关缓存
            await self._clear_task_cache(user.id)
            
            logger.info(f"用户 {user.username} 创建任务: {new_task.title}")
            
            return new_task
            
        except Exception as e:
            logger.error(f"创建任务失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="创建任务失败"
            )
    
    async def get_task_by_id(self, task_id: int, user: User, db: AsyncSession) -> Task:
        """根据ID获取任务"""
        try:
            # 先从缓存获取
            cached_task = await cache_manager.get_json(f"task:{task_id}")
            if cached_task and cached_task.get("owner_id") == user.id:
                # 从数据库获取最新数据以确保准确性
                pass
            
            # 从数据库获取任务
            task_query = await db.execute(
                select(Task)
                .options(selectinload(Task.owner))
                .where(and_(Task.id == task_id, Task.owner_id == user.id, Task.is_deleted == False))
            )
            task = task_query.scalar_one_or_none()
            
            if not task:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="任务不存在"
                )
            
            # 更新缓存
            await cache_manager.set_json(
                f"task:{task_id}",
                task.to_dict(include_owner=True),
                expire=3600
            )
            
            return task
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"获取任务失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="获取任务失败"
            )
    
    async def get_user_tasks(self, user: User, params: TaskListParams, db: AsyncSession) -> Dict[str, Any]:
        """获取用户任务列表"""
        try:
            # 构建查询条件
            conditions = [
                Task.owner_id == user.id,
                Task.is_deleted == False
            ]
            
            # 添加筛选条件
            if params.status:
                conditions.append(Task.status == params.status)
            
            if params.priority:
                conditions.append(Task.priority == params.priority)
            
            if params.category:
                conditions.append(Task.category == params.category)
            
            if params.is_starred is not None:
                conditions.append(Task.is_starred == params.is_starred)
            
            if params.is_archived is not None:
                conditions.append(Task.is_archived == params.is_archived)
            
            if params.is_overdue:
                conditions.append(
                    and_(
                        Task.due_date < datetime.utcnow(),
                        Task.status.notin_([TaskStatus.COMPLETED, TaskStatus.CANCELLED, TaskStatus.ARCHIVED])
                    )
                )
            
            if params.search:
                search_term = f"%{params.search}%"
                conditions.append(
                    or_(
                        Task.title.ilike(search_term),
                        Task.description.ilike(search_term),
                        Task.notes.ilike(search_term)
                    )
                )
            
            # 构建查询
            query = select(Task).where(and_(*conditions))
            
            # 添加排序
            if params.sort_by == "created_at":
                order_column = Task.created_at
            elif params.sort_by == "updated_at":
                order_column = Task.updated_at
            elif params.sort_by == "due_date":
                order_column = Task.due_date
            elif params.sort_by == "priority":
                order_column = Task.priority
            elif params.sort_by == "title":
                order_column = Task.title
            else:
                order_column = Task.created_at
            
            if params.sort_order == "asc":
                query = query.order_by(asc(order_column))
            else:
                query = query.order_by(desc(order_column))
            
            # 获取总数
            count_query = select(func.count()).select_from(
                select(Task).where(and_(*conditions)).subquery()
            )
            total_result = await db.execute(count_query)
            total = total_result.scalar()
            
            # 分页
            offset = (params.page - 1) * params.page_size
            query = query.offset(offset).limit(params.page_size)
            
            # 执行查询
            result = await db.execute(query)
            tasks = result.scalars().all()
            
            # 计算分页信息
            total_pages = (total + params.page_size - 1) // params.page_size
            
            return {
                "tasks": tasks,
                "total": total,
                "page": params.page,
                "page_size": params.page_size,
                "total_pages": total_pages,
                "has_next": params.page < total_pages,
                "has_prev": params.page > 1
            }
            
        except Exception as e:
            logger.error(f"获取任务列表失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="获取任务列表失败"
            )
    
    async def update_task(self, task_id: int, task_data: TaskUpdate, user: User, db: AsyncSession) -> Task:
        """更新任务"""
        try:
            # 获取任务
            task = await self.get_task_by_id(task_id, user, db)
            
            # 记录变更
            changes = []
            
            # 更新字段
            if task_data.title is not None and task_data.title != task.title:
                changes.append(f"标题: '{task.title}' -> '{task_data.title}'")
                task.title = task_data.title
            
            if task_data.description is not None and task_data.description != task.description:
                changes.append(f"描述: '{task.description or ''}' -> '{task_data.description or ''}'")
                task.description = task_data.description
            
            if task_data.status is not None and task_data.status != task.status:
                old_status = task.status.value
                changes.append(f"状态: '{old_status}' -> '{task_data.status.value}'")
                task.status = task_data.status
                
                # 状态变更的特殊处理
                if task_data.status == TaskStatus.IN_PROGRESS and not task.started_at:
                    task.started_at = datetime.utcnow()
                elif task_data.status == TaskStatus.COMPLETED:
                    task.completed_at = datetime.utcnow()
                    task.progress = 100
            
            if task_data.priority is not None and task_data.priority != task.priority:
                changes.append(f"优先级: '{task.priority.value}' -> '{task_data.priority.value}'")
                task.priority = task_data.priority
            
            if task_data.category is not None and task_data.category != task.category:
                changes.append(f"分类: '{task.category or ''}' -> '{task_data.category or ''}'")
                task.category = task_data.category
            
            if task_data.due_date is not None and task_data.due_date != task.due_date:
                old_date = task.due_date.isoformat() if task.due_date else "无"
                new_date = task_data.due_date.isoformat() if task_data.due_date else "无"
                changes.append(f"截止日期: '{old_date}' -> '{new_date}'")
                task.due_date = task_data.due_date
            
            if task_data.progress is not None and task_data.progress != task.progress:
                changes.append(f"进度: {task.progress}% -> {task_data.progress}%")
                task.progress = task_data.progress
            
            if task_data.estimated_hours is not None and task_data.estimated_hours != task.estimated_hours:
                changes.append(f"预估工时: {task.estimated_hours or 0} -> {task_data.estimated_hours}")
                task.estimated_hours = task_data.estimated_hours
            
            if task_data.actual_hours is not None and task_data.actual_hours != task.actual_hours:
                changes.append(f"实际工时: {task.actual_hours or 0} -> {task_data.actual_hours}")
                task.actual_hours = task_data.actual_hours
            
            if task_data.notes is not None and task_data.notes != task.notes:
                task.notes = task_data.notes
            
            if task_data.is_starred is not None and task_data.is_starred != task.is_starred:
                task.is_starred = task_data.is_starred
                changes.append(f"{'添加' if task_data.is_starred else '取消'}标星")
            
            if task_data.tags is not None:
                old_tags = set(task.tag_list)
                new_tags = set(task_data.tags)
                if old_tags != new_tags:
                    changes.append(f"标签: {old_tags} -> {new_tags}")
                    task.tag_list = task_data.tags
            
            # 更新时间
            task.updated_at = datetime.utcnow()
            
            await db.commit()
            
            # 记录活动
            if changes:
                await self._create_activity(
                    task_id=task.id,
                    user_id=user.id,
                    activity_type="task_updated",
                    description=f"更新了任务: {'; '.join(changes)}",
                    db=db
                )
            
            # 清除缓存
            await cache_manager.delete(f"task:{task_id}")
            await self._clear_task_cache(user.id)
            
            logger.info(f"用户 {user.username} 更新任务: {task.title}")
            
            return task
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"更新任务失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="更新任务失败"
            )
    
    async def delete_task(self, task_id: int, user: User, db: AsyncSession, permanent: bool = False) -> bool:
        """删除任务"""
        try:
            # 获取任务
            task = await self.get_task_by_id(task_id, user, db)
            
            if permanent:
                # 永久删除
                await db.delete(task)
                action = "永久删除"
            else:
                # 软删除
                task.is_deleted = True
                action = "删除"
            
            await db.commit()
            
            # 记录活动
            await self._create_activity(
                task_id=task.id,
                user_id=user.id,
                activity_type="task_deleted",
                description=f"{action}了任务 '{task.title}'",
                db=db
            )
            
            # 清除缓存
            await cache_manager.delete(f"task:{task_id}")
            await self._clear_task_cache(user.id)
            
            logger.info(f"用户 {user.username} {action}任务: {task.title}")
            
            return True
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"删除任务失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="删除任务失败"
            )
    
    async def get_task_stats(self, user: User, db: AsyncSession) -> TaskStats:
        """获取任务统计信息"""
        try:
            # 缓存键
            cache_key = f"task_stats:{user.id}"
            
            # 尝试从缓存获取
            cached_stats = await cache_manager.get_json(cache_key)
            if cached_stats:
                return TaskStats(**cached_stats)
            
            # 从数据库统计
            base_query = select(Task).where(
                and_(Task.owner_id == user.id, Task.is_deleted == False)
            )
            
            # 总任务数
            total_result = await db.execute(select(func.count()).select_from(base_query.subquery()))
            total_tasks = total_result.scalar()
            
            # 按状态统计
            status_stats = {}
            for status in TaskStatus:
                status_result = await db.execute(
                    select(func.count()).select_from(
                        base_query.where(Task.status == status).subquery()
                    )
                )
                status_stats[f"{status.value}_tasks"] = status_result.scalar()
            
            # 按优先级统计
            priority_stats = {}
            for priority in TaskPriority:
                priority_result = await db.execute(
                    select(func.count()).select_from(
                        base_query.where(Task.priority == priority).subquery()
                    )
                )
                priority_stats[f"{priority.value}_priority_tasks"] = priority_result.scalar()
            
            # 过期任务
            overdue_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(
                        and_(
                            Task.due_date < datetime.utcnow(),
                            Task.status.notin_([TaskStatus.COMPLETED, TaskStatus.CANCELLED, TaskStatus.ARCHIVED])
                        )
                    ).subquery()
                )
            )
            overdue_tasks = overdue_result.scalar()
            
            # 即将到期任务
            due_soon_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(
                        and_(
                            Task.due_date <= datetime.utcnow() + timedelta(days=1),
                            Task.due_date >= datetime.utcnow(),
                            Task.status.notin_([TaskStatus.COMPLETED, TaskStatus.CANCELLED, TaskStatus.ARCHIVED])
                        )
                    ).subquery()
                )
            )
            due_soon_tasks = due_soon_result.scalar()
            
            # 标星任务
            starred_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(Task.is_starred == True).subquery()
                )
            )
            starred_tasks = starred_result.scalar()
            
            # 归档任务
            archived_result = await db.execute(
                select(func.count()).select_from(
                    base_query.where(Task.is_archived == True).subquery()
                )
            )
            archived_tasks = archived_result.scalar()
            
            # 构建统计结果
            stats = TaskStats(
                total_tasks=total_tasks,
                overdue_tasks=overdue_tasks,
                due_soon_tasks=due_soon_tasks,
                starred_tasks=starred_tasks,
                archived_tasks=archived_tasks,
                **status_stats,
                **priority_stats
            )
            
            # 缓存结果
            await cache_manager.set_json(cache_key, stats.dict(), expire=300)  # 5分钟缓存
            
            return stats
            
        except Exception as e:
            logger.error(f"获取任务统计失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="获取任务统计失败"
            )
    
    async def batch_update_tasks(self, batch_data: TaskBatchUpdate, user: User, db: AsyncSession) -> Dict[str, Any]:
        """批量更新任务"""
        try:
            # 获取任务
            tasks_query = await db.execute(
                select(Task).where(
                    and_(
                        Task.id.in_(batch_data.task_ids),
                        Task.owner_id == user.id,
                        Task.is_deleted == False
                    )
                )
            )
            tasks = tasks_query.scalars().all()
            
            if not tasks:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="没有找到可更新的任务"
                )
            
            updated_count = 0
            
            for task in tasks:
                changes = []
                
                if batch_data.status is not None:
                    old_status = task.status
                    task.status = batch_data.status
                    changes.append(f"状态: {old_status.value} -> {batch_data.status.value}")
                    
                    # 状态变更的特殊处理
                    if batch_data.status == TaskStatus.IN_PROGRESS and not task.started_at:
                        task.started_at = datetime.utcnow()
                    elif batch_data.status == TaskStatus.COMPLETED:
                        task.completed_at = datetime.utcnow()
                        task.progress = 100
                
                if batch_data.priority is not None:
                    old_priority = task.priority
                    task.priority = batch_data.priority
                    changes.append(f"优先级: {old_priority.value} -> {batch_data.priority.value}")
                
                if batch_data.category is not None:
                    task.category = batch_data.category
                    changes.append(f"分类: {batch_data.category}")
                
                if batch_data.is_starred is not None:
                    task.is_starred = batch_data.is_starred
                    changes.append(f"{'添加' if batch_data.is_starred else '取消'}标星")
                
                if batch_data.is_archived is not None:
                    task.is_archived = batch_data.is_archived
                    changes.append(f"{'归档' if batch_data.is_archived else '取消归档'}")
                
                if changes:
                    task.updated_at = datetime.utcnow()
                    updated_count += 1
                    
                    # 记录活动
                    await self._create_activity(
                        task_id=task.id,
                        user_id=user.id,
                        activity_type="task_batch_updated",
                        description=f"批量更新: {'; '.join(changes)}",
                        db=db
                    )
            
            await db.commit()
            
            # 清除缓存
            await self._clear_task_cache(user.id)
            
            logger.info(f"用户 {user.username} 批量更新了 {updated_count} 个任务")
            
            return {
                "updated_count": updated_count,
                "total_count": len(tasks),
                "message": f"成功更新 {updated_count} 个任务"
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"批量更新任务失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="批量更新任务失败"
            )
    
    async def batch_delete_tasks(self, batch_data: TaskBatchDelete, user: User, db: AsyncSession) -> Dict[str, Any]:
        """批量删除任务"""
        try:
            # 获取任务
            tasks_query = await db.execute(
                select(Task).where(
                    and_(
                        Task.id.in_(batch_data.task_ids),
                        Task.owner_id == user.id,
                        Task.is_deleted == False
                    )
                )
            )
            tasks = tasks_query.scalars().all()
            
            if not tasks:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="没有找到可删除的任务"
                )
            
            deleted_count = 0
            
            for task in tasks:
                if batch_data.permanent:
                    # 永久删除
                    await db.delete(task)
                else:
                    # 软删除
                    task.is_deleted = True
                
                deleted_count += 1
                
                # 记录活动
                await self._create_activity(
                    task_id=task.id,
                    user_id=user.id,
                    activity_type="task_batch_deleted",
                    description=f"批量{'永久删除' if batch_data.permanent else '删除'}任务 '{task.title}'",
                    db=db
                )
            
            await db.commit()
            
            # 清除缓存
            await self._clear_task_cache(user.id)
            
            logger.info(f"用户 {user.username} 批量删除了 {deleted_count} 个任务")
            
            return {
                "deleted_count": deleted_count,
                "total_count": len(tasks),
                "message": f"成功删除 {deleted_count} 个任务"
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"批量删除任务失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="批量删除任务失败"
            )
    
    async def _create_activity(self, task_id: int, user_id: int, activity_type: str, 
                             description: str, db: AsyncSession, metadata: Dict = None):
        """创建任务活动记录"""
        try:
            activity = TaskActivity(
                task_id=task_id,
                user_id=user_id,
                activity_type=activity_type,
                description=description,
                meta_data=str(metadata) if metadata else None
            )
            db.add(activity)
            await db.commit()
            
        except Exception as e:
            logger.error(f"创建活动记录失败: {e}")
    
    async def _clear_task_cache(self, user_id: int):
        """清除任务相关缓存"""
        try:
            await cache_manager.delete(f"task_stats:{user_id}")
            # 可以添加更多缓存清理逻辑
        except Exception as e:
            logger.error(f"清除任务缓存失败: {e}")


# 全局任务服务实例
task_service = TaskService()