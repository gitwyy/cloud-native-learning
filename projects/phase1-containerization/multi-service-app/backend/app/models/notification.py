"""
通知数据模型
"""

from sqlalchemy import String, Boolean, DateTime, Integer, Text, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from datetime import datetime
from typing import Optional, TYPE_CHECKING
import enum

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User


class NotificationType(str, enum.Enum):
    """通知类型枚举"""
    TASK_CREATED = "task_created"        # 任务创建
    TASK_UPDATED = "task_updated"        # 任务更新
    TASK_COMPLETED = "task_completed"    # 任务完成
    TASK_OVERDUE = "task_overdue"        # 任务过期
    TASK_DUE_SOON = "task_due_soon"      # 任务即将到期
    TASK_ASSIGNED = "task_assigned"      # 任务分配
    TASK_COMMENTED = "task_commented"    # 任务评论
    SYSTEM_MAINTENANCE = "system_maintenance"  # 系统维护
    SYSTEM_UPDATE = "system_update"      # 系统更新
    SECURITY_ALERT = "security_alert"    # 安全警告
    WELCOME = "welcome"                  # 欢迎消息
    REMINDER = "reminder"                # 提醒消息


class NotificationPriority(str, enum.Enum):
    """通知优先级枚举"""
    LOW = "low"         # 低优先级
    MEDIUM = "medium"   # 中优先级
    HIGH = "high"       # 高优先级
    URGENT = "urgent"   # 紧急


class NotificationStatus(str, enum.Enum):
    """通知状态枚举"""
    PENDING = "pending"      # 待发送
    SENT = "sent"           # 已发送
    DELIVERED = "delivered"  # 已送达
    READ = "read"           # 已读
    FAILED = "failed"       # 发送失败
    CANCELLED = "cancelled"  # 已取消


class Notification(Base):
    """通知模型"""
    
    __tablename__ = "notifications"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="通知ID"
    )
    
    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )
    
    # 关联信息
    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="用户ID"
    )
    
    # 通知基本信息
    title: Mapped[str] = mapped_column(
        String(200), 
        nullable=False,
        comment="通知标题"
    )
    message: Mapped[str] = mapped_column(
        Text, 
        nullable=False,
        comment="通知内容"
    )
    
    # 通知分类
    notification_type: Mapped[NotificationType] = mapped_column(
        Enum(NotificationType),
        nullable=False,
        index=True,
        comment="通知类型"
    )
    priority: Mapped[NotificationPriority] = mapped_column(
        Enum(NotificationPriority),
        default=NotificationPriority.MEDIUM,
        nullable=False,
        index=True,
        comment="通知优先级"
    )
    status: Mapped[NotificationStatus] = mapped_column(
        Enum(NotificationStatus),
        default=NotificationStatus.PENDING,
        nullable=False,
        index=True,
        comment="通知状态"
    )
    
    # 关联资源
    resource_type: Mapped[str] = mapped_column(
        String(50), 
        nullable=True,
        comment="关联资源类型"
    )
    resource_id: Mapped[int] = mapped_column(
        Integer, 
        nullable=True,
        comment="关联资源ID"
    )
    
    # 渠道配置
    channels: Mapped[str] = mapped_column(
        String(200), 
        nullable=True,
        comment="发送渠道(逗号分隔): email,push,websocket"
    )
    
    # 时间相关
    scheduled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="计划发送时间"
    )
    sent_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="实际发送时间"
    )
    read_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="阅读时间"
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="过期时间"
    )
    
    # 状态标记
    is_read: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        index=True,
        comment="是否已读"
    )
    is_archived: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="是否已归档"
    )
    is_deleted: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="是否已删除"
    )
    
    # 扩展信息
    meta_data: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="扩展元数据(JSON)"
    )
    action_url: Mapped[str] = mapped_column(
        String(500), 
        nullable=True,
        comment="操作链接"
    )
    action_text: Mapped[str] = mapped_column(
        String(100), 
        nullable=True,
        comment="操作按钮文本"
    )
    
    # 发送记录
    email_sent: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="邮件是否已发送"
    )
    push_sent: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="推送是否已发送"
    )
    websocket_sent: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="WebSocket是否已发送"
    )
    
    # 重试信息
    retry_count: Mapped[int] = mapped_column(
        Integer, 
        default=0, 
        nullable=False,
        comment="重试次数"
    )
    max_retries: Mapped[int] = mapped_column(
        Integer, 
        default=3, 
        nullable=False,
        comment="最大重试次数"
    )
    last_error: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="最后错误信息"
    )
    
    # 关系映射
    user: Mapped["User"] = relationship(
        "User",
        back_populates="notifications",
        lazy="select"
    )
    
    def __repr__(self) -> str:
        return f"<Notification(id={self.id}, title='{self.title}', type='{self.notification_type}')>"
    
    @property
    def is_expired(self) -> bool:
        """检查通知是否过期"""
        if not self.expires_at:
            return False
        return datetime.utcnow() > self.expires_at
    
    @property
    def channel_list(self) -> list:
        """获取发送渠道列表"""
        if not self.channels:
            return ["websocket"]  # 默认使用WebSocket
        return [channel.strip() for channel in self.channels.split(",") if channel.strip()]
    
    @channel_list.setter
    def channel_list(self, channels: list):
        """设置发送渠道列表"""
        self.channels = ",".join(channels) if channels else None
    
    @property
    def can_retry(self) -> bool:
        """检查是否可以重试"""
        return (
            self.status == NotificationStatus.FAILED 
            and self.retry_count < self.max_retries
        )
    
    def mark_as_sent(self, channel: str = None):
        """标记为已发送"""
        self.status = NotificationStatus.SENT
        self.sent_at = datetime.utcnow()
        
        # 标记特定渠道已发送
        if channel == "email":
            self.email_sent = True
        elif channel == "push":
            self.push_sent = True
        elif channel == "websocket":
            self.websocket_sent = True
    
    def mark_as_read(self):
        """标记为已读"""
        if not self.is_read:
            self.is_read = True
            self.read_at = datetime.utcnow()
            self.status = NotificationStatus.READ
    
    def mark_as_failed(self, error_message: str = None):
        """标记为失败"""
        self.status = NotificationStatus.FAILED
        self.retry_count += 1
        if error_message:
            self.last_error = error_message
    
    def archive(self):
        """归档通知"""
        self.is_archived = True
    
    def soft_delete(self):
        """软删除通知"""
        self.is_deleted = True
    
    def to_dict(self, include_user: bool = False) -> dict:
        """转换为字典"""
        data = {
            "id": self.id,
            "title": self.title,
            "message": self.message,
            "notification_type": self.notification_type.value,
            "priority": self.priority.value,
            "status": self.status.value,
            "resource_type": self.resource_type,
            "resource_id": self.resource_id,
            "channels": self.channel_list,
            "scheduled_at": self.scheduled_at.isoformat() if self.scheduled_at else None,
            "sent_at": self.sent_at.isoformat() if self.sent_at else None,
            "read_at": self.read_at.isoformat() if self.read_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "is_read": self.is_read,
            "is_archived": self.is_archived,
            "action_url": self.action_url,
            "action_text": self.action_text,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "is_expired": self.is_expired,
        }
        
        if include_user and self.user:
            data["user"] = {
                "id": self.user.id,
                "username": self.user.username,
                "full_name": self.user.full_name,
                "avatar_url": self.user.avatar_url,
            }
        else:
            data["user_id"] = self.user_id
        
        return data


class NotificationTemplate(Base):
    """通知模板模型"""
    
    __tablename__ = "notification_templates"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="模板ID"
    )
    
    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )
    
    # 模板基本信息
    name: Mapped[str] = mapped_column(
        String(100), 
        unique=True, 
        nullable=False,
        comment="模板名称"
    )
    notification_type: Mapped[NotificationType] = mapped_column(
        Enum(NotificationType),
        nullable=False,
        index=True,
        comment="通知类型"
    )
    
    # 模板内容
    title_template: Mapped[str] = mapped_column(
        String(200), 
        nullable=False,
        comment="标题模板"
    )
    message_template: Mapped[str] = mapped_column(
        Text, 
        nullable=False,
        comment="消息模板"
    )
    
    # 邮件模板（可选）
    email_subject_template: Mapped[str] = mapped_column(
        String(200), 
        nullable=True,
        comment="邮件主题模板"
    )
    email_body_template: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="邮件正文模板"
    )
    
    # 配置
    default_channels: Mapped[str] = mapped_column(
        String(200), 
        nullable=True,
        comment="默认发送渠道"
    )
    default_priority: Mapped[NotificationPriority] = mapped_column(
        Enum(NotificationPriority),
        default=NotificationPriority.MEDIUM,
        nullable=False,
        comment="默认优先级"
    )
    
    # 状态
    is_active: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否启用"
    )
    
    def __repr__(self) -> str:
        return f"<NotificationTemplate(id={self.id}, name='{self.name}', type='{self.notification_type}')>"
    
    def render(self, context: dict) -> dict:
        """渲染模板"""
        try:
            from string import Template
            
            title_tmpl = Template(self.title_template)
            message_tmpl = Template(self.message_template)
            
            rendered = {
                "title": title_tmpl.safe_substitute(context),
                "message": message_tmpl.safe_substitute(context),
            }
            
            if self.email_subject_template:
                email_subject_tmpl = Template(self.email_subject_template)
                rendered["email_subject"] = email_subject_tmpl.safe_substitute(context)
            
            if self.email_body_template:
                email_body_tmpl = Template(self.email_body_template)
                rendered["email_body"] = email_body_tmpl.safe_substitute(context)
            
            return rendered
            
        except Exception as e:
            return {
                "title": f"通知渲染错误: {str(e)}",
                "message": "模板渲染失败，请联系管理员",
            }
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            "id": self.id,
            "name": self.name,
            "notification_type": self.notification_type.value,
            "title_template": self.title_template,
            "message_template": self.message_template,
            "email_subject_template": self.email_subject_template,
            "email_body_template": self.email_body_template,
            "default_channels": self.default_channels,
            "default_priority": self.default_priority.value,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


class NotificationSetting(Base):
    """用户通知设置模型"""
    
    __tablename__ = "notification_settings"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="设置ID"
    )
    
    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )
    
    # 关联信息
    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="用户ID"
    )
    notification_type: Mapped[NotificationType] = mapped_column(
        Enum(NotificationType),
        nullable=False,
        comment="通知类型"
    )
    
    # 渠道设置
    email_enabled: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否启用邮件通知"
    )
    push_enabled: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否启用推送通知"
    )
    websocket_enabled: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否启用WebSocket通知"
    )
    
    # 时间设置
    quiet_hours_start: Mapped[str] = mapped_column(
        String(5), 
        nullable=True,
        comment="免打扰开始时间(HH:MM)"
    )
    quiet_hours_end: Mapped[str] = mapped_column(
        String(5), 
        nullable=True,
        comment="免打扰结束时间(HH:MM)"
    )
    
    def __repr__(self) -> str:
        return f"<NotificationSetting(user_id={self.user_id}, type='{self.notification_type}')>"
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            "user_id": self.user_id,
            "notification_type": self.notification_type.value,
            "email_enabled": self.email_enabled,
            "push_enabled": self.push_enabled,
            "websocket_enabled": self.websocket_enabled,
            "quiet_hours_start": self.quiet_hours_start,
            "quiet_hours_end": self.quiet_hours_end,
        }