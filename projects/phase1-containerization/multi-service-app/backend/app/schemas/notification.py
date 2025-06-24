"""
通知相关的Pydantic模型
用于API请求和响应的数据验证
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field
from enum import Enum


class NotificationType(str, Enum):
    """通知类型枚举"""
    TASK_CREATED = "task_created"
    TASK_UPDATED = "task_updated"
    TASK_COMPLETED = "task_completed"
    TASK_OVERDUE = "task_overdue"
    TASK_DUE_SOON = "task_due_soon"
    TASK_ASSIGNED = "task_assigned"
    TASK_COMMENTED = "task_commented"
    SYSTEM_MAINTENANCE = "system_maintenance"
    SYSTEM_UPDATE = "system_update"
    SECURITY_ALERT = "security_alert"
    WELCOME = "welcome"
    REMINDER = "reminder"


class NotificationPriority(str, Enum):
    """通知优先级枚举"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


class NotificationStatus(str, Enum):
    """通知状态枚举"""
    PENDING = "pending"
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"
    CANCELLED = "cancelled"


# 基础通知模型
class NotificationBase(BaseModel):
    """通知基础模型"""
    title: str = Field(..., min_length=1, max_length=200, description="通知标题")
    message: str = Field(..., min_length=1, description="通知内容")
    notification_type: NotificationType = Field(..., description="通知类型")
    priority: NotificationPriority = Field(NotificationPriority.MEDIUM, description="通知优先级")
    resource_type: Optional[str] = Field(None, max_length=50, description="关联资源类型")
    resource_id: Optional[int] = Field(None, description="关联资源ID")
    channels: Optional[List[str]] = Field(None, description="发送渠道")
    scheduled_at: Optional[datetime] = Field(None, description="计划发送时间")
    expires_at: Optional[datetime] = Field(None, description="过期时间")
    action_url: Optional[str] = Field(None, max_length=500, description="操作链接")
    action_text: Optional[str] = Field(None, max_length=100, description="操作按钮文本")
    metadata: Optional[dict] = Field(None, description="扩展元数据")


# 创建通知请求模型
class NotificationCreate(NotificationBase):
    """创建通知请求模型"""
    user_id: Optional[int] = Field(None, description="目标用户ID，如果为空则发送给当前用户")


# 更新通知请求模型
class NotificationUpdate(BaseModel):
    """更新通知请求模型"""
    title: Optional[str] = Field(None, min_length=1, max_length=200, description="通知标题")
    message: Optional[str] = Field(None, min_length=1, description="通知内容")
    priority: Optional[NotificationPriority] = Field(None, description="通知优先级")
    status: Optional[NotificationStatus] = Field(None, description="通知状态")
    is_read: Optional[bool] = Field(None, description="是否已读")
    is_archived: Optional[bool] = Field(None, description="是否已归档")
    scheduled_at: Optional[datetime] = Field(None, description="计划发送时间")
    expires_at: Optional[datetime] = Field(None, description="过期时间")


# 通知响应模型
class Notification(NotificationBase):
    """通知响应模型"""
    id: int
    user_id: int
    status: NotificationStatus
    is_read: bool = False
    is_archived: bool = False
    is_deleted: bool = False
    sent_at: Optional[datetime] = None
    read_at: Optional[datetime] = None
    email_sent: bool = False
    push_sent: bool = False
    websocket_sent: bool = False
    retry_count: int = 0
    max_retries: int = 3
    last_error: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    # 计算属性
    is_expired: bool = False
    
    class Config:
        from_attributes = True


# 带用户信息的通知模型
class NotificationWithUser(Notification):
    """带用户信息的通知模型"""
    user: Optional[dict] = None


# 通知统计模型
class NotificationStats(BaseModel):
    """通知统计模型"""
    total_notifications: int = 0
    unread_notifications: int = 0
    read_notifications: int = 0
    archived_notifications: int = 0
    pending_notifications: int = 0
    sent_notifications: int = 0
    failed_notifications: int = 0
    
    # 按类型统计
    task_notifications: int = 0
    system_notifications: int = 0
    security_notifications: int = 0
    
    # 按优先级统计
    low_priority: int = 0
    medium_priority: int = 0
    high_priority: int = 0
    urgent_priority: int = 0


# 通知列表查询参数
class NotificationListParams(BaseModel):
    """通知列表查询参数"""
    notification_type: Optional[NotificationType] = None
    priority: Optional[NotificationPriority] = None
    status: Optional[NotificationStatus] = None
    is_read: Optional[bool] = None
    is_archived: Optional[bool] = None
    resource_type: Optional[str] = None
    search: Optional[str] = None
    page: int = Field(1, ge=1, description="页码")
    page_size: int = Field(20, ge=1, le=100, description="每页数量")
    sort_by: Optional[str] = Field("created_at", description="排序字段")
    sort_order: Optional[str] = Field("desc", pattern="^(asc|desc)$", description="排序方向")


# 通知模板模型
class NotificationTemplateBase(BaseModel):
    """通知模板基础模型"""
    name: str = Field(..., min_length=1, max_length=100, description="模板名称")
    notification_type: NotificationType = Field(..., description="通知类型")
    title_template: str = Field(..., min_length=1, max_length=200, description="标题模板")
    message_template: str = Field(..., min_length=1, description="消息模板")
    email_subject_template: Optional[str] = Field(None, max_length=200, description="邮件主题模板")
    email_body_template: Optional[str] = Field(None, description="邮件正文模板")
    default_channels: Optional[List[str]] = Field(None, description="默认发送渠道")
    default_priority: NotificationPriority = Field(NotificationPriority.MEDIUM, description="默认优先级")
    is_active: bool = Field(True, description="是否启用")


class NotificationTemplateCreate(NotificationTemplateBase):
    """创建通知模板请求模型"""
    pass


class NotificationTemplateUpdate(BaseModel):
    """更新通知模板请求模型"""
    name: Optional[str] = Field(None, min_length=1, max_length=100, description="模板名称")
    title_template: Optional[str] = Field(None, min_length=1, max_length=200, description="标题模板")
    message_template: Optional[str] = Field(None, min_length=1, description="消息模板")
    email_subject_template: Optional[str] = Field(None, max_length=200, description="邮件主题模板")
    email_body_template: Optional[str] = Field(None, description="邮件正文模板")
    default_channels: Optional[List[str]] = Field(None, description="默认发送渠道")
    default_priority: Optional[NotificationPriority] = Field(None, description="默认优先级")
    is_active: Optional[bool] = Field(None, description="是否启用")


class NotificationTemplate(NotificationTemplateBase):
    """通知模板响应模型"""
    id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


# 通知设置模型
class NotificationSettingBase(BaseModel):
    """通知设置基础模型"""
    notification_type: NotificationType = Field(..., description="通知类型")
    email_enabled: bool = Field(True, description="是否启用邮件通知")
    push_enabled: bool = Field(True, description="是否启用推送通知")
    websocket_enabled: bool = Field(True, description="是否启用WebSocket通知")
    quiet_hours_start: Optional[str] = Field(None, pattern="^([01]?[0-9]|2[0-3]):[0-5][0-9]$", description="免打扰开始时间")
    quiet_hours_end: Optional[str] = Field(None, pattern="^([01]?[0-9]|2[0-3]):[0-5][0-9]$", description="免打扰结束时间")


class NotificationSettingUpdate(BaseModel):
    """更新通知设置请求模型"""
    email_enabled: Optional[bool] = Field(None, description="是否启用邮件通知")
    push_enabled: Optional[bool] = Field(None, description="是否启用推送通知")
    websocket_enabled: Optional[bool] = Field(None, description="是否启用WebSocket通知")
    quiet_hours_start: Optional[str] = Field(None, pattern="^([01]?[0-9]|2[0-3]):[0-5][0-9]$", description="免打扰开始时间")
    quiet_hours_end: Optional[str] = Field(None, pattern="^([01]?[0-9]|2[0-3]):[0-5][0-9]$", description="免打扰结束时间")


class NotificationSetting(NotificationSettingBase):
    """通知设置响应模型"""
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


# 批量操作模型
class NotificationBatchUpdate(BaseModel):
    """批量更新通知模型"""
    notification_ids: List[int] = Field(..., min_items=1, description="通知ID列表")
    is_read: Optional[bool] = None
    is_archived: Optional[bool] = None
    status: Optional[NotificationStatus] = None


class NotificationBatchDelete(BaseModel):
    """批量删除通知模型"""
    notification_ids: List[int] = Field(..., min_items=1, description="通知ID列表")
    permanent: bool = Field(False, description="是否永久删除")


# 发送通知请求模型
class NotificationSendRequest(BaseModel):
    """发送通知请求模型"""
    template_name: Optional[str] = Field(None, description="模板名称")
    user_ids: Optional[List[int]] = Field(None, description="目标用户ID列表，如果为空则发送给当前用户")
    title: Optional[str] = Field(None, description="自定义标题")
    message: Optional[str] = Field(None, description="自定义消息")
    context: Optional[dict] = Field(None, description="模板渲染上下文")
    channels: Optional[List[str]] = Field(None, description="发送渠道")
    priority: Optional[NotificationPriority] = Field(None, description="优先级")
    scheduled_at: Optional[datetime] = Field(None, description="计划发送时间")