"""
通知系统API路由
处理用户通知的管理和推送
"""

from datetime import datetime
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, rate_limit_standard
from app.services.notification_service import notification_service
from app.schemas.notification import (
    NotificationCreate, NotificationUpdate, Notification, NotificationStats,
    NotificationListParams, NotificationSendRequest, NotificationBatchUpdate,
    NotificationBatchDelete, NotificationType, NotificationPriority, NotificationStatus
)
from app.utils.logger import setup_logger

# 日志
logger = setup_logger(__name__)

# 创建路由器
router = APIRouter()


@router.get("/", response_model=Dict[str, Any], tags=["通知系统"])
async def get_notifications(
    notification_type: Optional[NotificationType] = Query(None, description="按类型筛选"),
    priority: Optional[NotificationPriority] = Query(None, description="按优先级筛选"),
    status_filter: Optional[NotificationStatus] = Query(None, alias="status", description="按状态筛选"),
    is_read: Optional[bool] = Query(None, description="按读取状态筛选"),
    is_archived: Optional[bool] = Query(None, description="是否归档"),
    resource_type: Optional[str] = Query(None, description="按资源类型筛选"),
    search: Optional[str] = Query(None, description="搜索关键词"),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    sort_by: Optional[str] = Query("created_at", description="排序字段"),
    sort_order: Optional[str] = Query("desc", pattern="^(asc|desc)$", description="排序方向"),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(rate_limit_standard)
):
    """获取通知列表"""
    try:
        # 构建查询参数
        params = NotificationListParams(
            notification_type=notification_type,
            priority=priority,
            status=status_filter,
            is_read=is_read,
            is_archived=is_archived,
            resource_type=resource_type,
            search=search,
            page=page,
            page_size=page_size,
            sort_by=sort_by,
            sort_order=sort_order
        )
        
        result = await notification_service.get_user_notifications(current_user, params, db)
        
        # 转换通知为字典格式
        notifications_data = [notification.to_dict(include_user=False) for notification in result["notifications"]]
        result["notifications"] = notifications_data
        
        logger.info(f"获取通知列表: {current_user.username}, 数量: {result['total']}")
        
        return result
        
    except Exception as e:
        logger.error(f"获取通知列表失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取通知列表失败"
        )


@router.post("/", response_model=Dict[str, Any], tags=["通知系统"])
async def create_notification(
    notification_data: NotificationCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(rate_limit_standard)
):
    """创建新通知"""
    try:
        notification = await notification_service.create_notification(notification_data, current_user, db)
        
        logger.info(f"创建通知成功: {current_user.username}, 通知ID: {notification.id}")
        
        return notification.to_dict(include_user=False)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"创建通知失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="创建通知失败"
        )


@router.get("/{notification_id}", response_model=Dict[str, Any], tags=["通知系统"])
async def get_notification(
    notification_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取通知详情"""
    try:
        notification = await notification_service.get_notification_by_id(notification_id, current_user, db)
        
        logger.info(f"获取通知详情: {current_user.username}, 通知ID: {notification_id}")
        
        return notification.to_dict(include_user=False)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取通知详情失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取通知详情失败"
        )


@router.put("/{notification_id}/read", response_model=Dict[str, Any], tags=["通知系统"])
async def mark_notification_read(
    notification_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """标记通知为已读"""
    try:
        notification = await notification_service.mark_notification_read(notification_id, current_user, db)
        
        logger.info(f"标记通知已读: {current_user.username}, 通知ID: {notification_id}")
        
        return notification.to_dict(include_user=False)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"标记通知已读失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="标记通知已读失败"
        )


@router.put("/read-all", tags=["通知系统"])
async def mark_all_notifications_read(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """标记所有通知为已读"""
    try:
        result = await notification_service.mark_all_notifications_read(current_user, db)
        
        logger.info(f"标记所有通知已读: {current_user.username}, 数量: {result['read_count']}")
        
        return result
        
    except Exception as e:
        logger.error(f"标记所有通知已读失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="标记所有通知已读失败"
        )


@router.delete("/{notification_id}", tags=["通知系统"])
async def delete_notification(
    notification_id: int,
    permanent: bool = Query(False, description="是否永久删除"),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """删除通知"""
    try:
        success = await notification_service.delete_notification(notification_id, current_user, db, permanent)
        
        if success:
            action = "永久删除" if permanent else "删除"
            logger.info(f"{action}通知成功: {current_user.username}, 通知ID: {notification_id}")
            return {"message": f"通知已{action}"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="删除通知失败"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除通知失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="删除通知失败"
        )


@router.post("/send", response_model=Dict[str, Any], tags=["通知系统"])
async def send_notification(
    send_request: NotificationSendRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """发送通知"""
    try:
        result = await notification_service.send_notification(send_request, current_user, db)
        
        logger.info(f"发送通知: {current_user.username}, 成功数量: {result['sent_count']}")
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送通知失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送通知失败"
        )


@router.get("/stats/summary", response_model=NotificationStats, tags=["通知系统"])
async def get_notification_stats(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取通知统计信息"""
    try:
        stats = await notification_service.get_notification_stats(current_user, db)
        
        logger.info(f"获取通知统计: {current_user.username}")
        
        return stats
        
    except Exception as e:
        logger.error(f"获取通知统计失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取通知统计失败"
        )


# 健康检查
@router.get("/health", tags=["健康检查"])
async def notifications_health():
    """通知服务健康检查"""
    return {
        "service": "notifications",
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "version": "1.0.0"
    }