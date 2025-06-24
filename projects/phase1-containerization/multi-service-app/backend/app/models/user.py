"""
用户数据模型
"""

from sqlalchemy import String, Boolean, DateTime, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from datetime import datetime
from typing import List, TYPE_CHECKING

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.task import Task
    from app.models.notification import Notification


class User(Base):
    """用户模型"""
    
    __tablename__ = "users"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="用户ID"
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
    
    # 基本信息
    username: Mapped[str] = mapped_column(
        String(50), 
        unique=True, 
        index=True, 
        nullable=False,
        comment="用户名"
    )
    email: Mapped[str] = mapped_column(
        String(100), 
        unique=True, 
        index=True, 
        nullable=False,
        comment="邮箱地址"
    )
    hashed_password: Mapped[str] = mapped_column(
        String(128), 
        nullable=False,
        comment="密码哈希"
    )
    
    # 个人信息
    full_name: Mapped[str] = mapped_column(
        String(100), 
        nullable=True,
        comment="真实姓名"
    )
    avatar_url: Mapped[str] = mapped_column(
        String(255), 
        nullable=True,
        comment="头像URL"
    )
    bio: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="个人简介"
    )
    
    # 状态字段
    is_active: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否激活"
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="是否已验证邮箱"
    )
    is_superuser: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="是否为超级用户"
    )
    
    # 时间字段
    last_login: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="最后登录时间"
    )
    email_verified_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="邮箱验证时间"
    )
    
    # 安全字段
    failed_login_attempts: Mapped[int] = mapped_column(
        Integer, 
        default=0, 
        nullable=False,
        comment="失败登录次数"
    )
    locked_until: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="锁定到期时间"
    )
    password_changed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(),
        comment="密码修改时间"
    )
    
    # 偏好设置
    timezone: Mapped[str] = mapped_column(
        String(50), 
        default="Asia/Shanghai", 
        nullable=False,
        comment="时区"
    )
    language: Mapped[str] = mapped_column(
        String(10), 
        default="zh-CN", 
        nullable=False,
        comment="语言"
    )
    theme: Mapped[str] = mapped_column(
        String(20), 
        default="light", 
        nullable=False,
        comment="主题"
    )
    
    # 通知设置
    email_notifications: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否启用邮件通知"
    )
    push_notifications: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否启用推送通知"
    )
    
    # 关系映射
    tasks: Mapped[List["Task"]] = relationship(
        "Task",
        back_populates="owner",
        cascade="all, delete-orphan",
        lazy="dynamic"
    )
    
    notifications: Mapped[List["Notification"]] = relationship(
        "Notification",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="dynamic"
    )
    
    def __repr__(self) -> str:
        return f"<User(id={self.id}, username='{self.username}', email='{self.email}')>"
    
    @property
    def is_locked(self) -> bool:
        """检查用户是否被锁定"""
        if not self.locked_until:
            return False
        return datetime.utcnow() < self.locked_until
    
    @property
    def display_name(self) -> str:
        """获取显示名称"""
        return self.full_name or self.username
    
    def to_dict(self, include_sensitive: bool = False) -> dict:
        """转换为字典"""
        data = {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "full_name": self.full_name,
            "avatar_url": self.avatar_url,
            "bio": self.bio,
            "is_active": self.is_active,
            "is_verified": self.is_verified,
            "last_login": self.last_login.isoformat() if self.last_login else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "timezone": self.timezone,
            "language": self.language,
            "theme": self.theme,
            "email_notifications": self.email_notifications,
            "push_notifications": self.push_notifications,
        }
        
        if include_sensitive:
            data.update({
                "is_superuser": self.is_superuser,
                "failed_login_attempts": self.failed_login_attempts,
                "locked_until": self.locked_until.isoformat() if self.locked_until else None,
                "password_changed_at": self.password_changed_at.isoformat() if self.password_changed_at else None,
                "email_verified_at": self.email_verified_at.isoformat() if self.email_verified_at else None,
            })
        
        return data


class UserSession(Base):
    """用户会话模型"""
    
    __tablename__ = "user_sessions"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="会话ID"
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
    
    # 会话信息
    session_id: Mapped[str] = mapped_column(
        String(128), 
        unique=True, 
        index=True, 
        nullable=False,
        comment="会话ID"
    )
    user_id: Mapped[int] = mapped_column(
        Integer, 
        nullable=False, 
        index=True,
        comment="用户ID"
    )
    
    # 设备信息
    device_type: Mapped[str] = mapped_column(
        String(50), 
        nullable=True,
        comment="设备类型"
    )
    device_name: Mapped[str] = mapped_column(
        String(100), 
        nullable=True,
        comment="设备名称"
    )
    browser: Mapped[str] = mapped_column(
        String(100), 
        nullable=True,
        comment="浏览器"
    )
    ip_address: Mapped[str] = mapped_column(
        String(45), 
        nullable=True,
        comment="IP地址"
    )
    user_agent: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="用户代理"
    )
    
    # 时间字段
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=False,
        comment="过期时间"
    )
    last_activity: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(),
        onupdate=func.now(),
        comment="最后活动时间"
    )
    
    # 状态字段
    is_active: Mapped[bool] = mapped_column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="是否活跃"
    )
    
    def __repr__(self) -> str:
        return f"<UserSession(id={self.id}, user_id={self.user_id}, session_id='{self.session_id}')>"
    
    @property
    def is_expired(self) -> bool:
        """检查会话是否过期"""
        return datetime.utcnow() > self.expires_at
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            "id": self.id,
            "session_id": self.session_id,
            "user_id": self.user_id,
            "device_type": self.device_type,
            "device_name": self.device_name,
            "browser": self.browser,
            "ip_address": self.ip_address,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "last_activity": self.last_activity.isoformat() if self.last_activity else None,
            "is_active": self.is_active,
        }


class UserLoginLog(Base):
    """用户登录日志模型"""
    
    __tablename__ = "user_login_logs"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="日志ID"
    )
    
    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )
    
    # 用户信息
    user_id: Mapped[int] = mapped_column(
        Integer, 
        nullable=True, 
        index=True,
        comment="用户ID"
    )
    username: Mapped[str] = mapped_column(
        String(50), 
        nullable=True,
        comment="用户名"
    )
    email: Mapped[str] = mapped_column(
        String(100), 
        nullable=True,
        comment="邮箱"
    )
    
    # 登录状态
    login_successful: Mapped[bool] = mapped_column(
        Boolean, 
        nullable=False,
        comment="登录是否成功"
    )
    failure_reason: Mapped[str] = mapped_column(
        String(100), 
        nullable=True,
        comment="失败原因"
    )
    
    # 客户端信息
    ip_address: Mapped[str] = mapped_column(
        String(45), 
        nullable=True,
        comment="IP地址"
    )
    user_agent: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="用户代理"
    )
    device_info: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="设备信息"
    )
    
    # 地理位置信息
    country: Mapped[str] = mapped_column(
        String(50), 
        nullable=True,
        comment="国家"
    )
    city: Mapped[str] = mapped_column(
        String(50), 
        nullable=True,
        comment="城市"
    )
    
    def __repr__(self) -> str:
        return f"<UserLoginLog(id={self.id}, user_id={self.user_id}, successful={self.login_successful})>"
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "username": self.username,
            "email": self.email,
            "login_successful": self.login_successful,
            "failure_reason": self.failure_reason,
            "ip_address": self.ip_address,
            "user_agent": self.user_agent,
            "device_info": self.device_info,
            "country": self.country,
            "city": self.city,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }