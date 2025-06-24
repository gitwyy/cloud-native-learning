"""
任务数据模型
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


class TaskStatus(str, enum.Enum):
    """任务状态枚举"""
    PENDING = "pending"      # 待处理
    IN_PROGRESS = "in_progress"  # 进行中
    COMPLETED = "completed"  # 已完成
    CANCELLED = "cancelled"  # 已取消
    ARCHIVED = "archived"    # 已归档


class TaskPriority(str, enum.Enum):
    """任务优先级枚举"""
    LOW = "low"         # 低优先级
    MEDIUM = "medium"   # 中优先级
    HIGH = "high"       # 高优先级
    URGENT = "urgent"   # 紧急


class Task(Base):
    """任务模型"""
    
    __tablename__ = "tasks"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="任务ID"
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
    title: Mapped[str] = mapped_column(
        String(200), 
        nullable=False, 
        index=True,
        comment="任务标题"
    )
    description: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="任务描述"
    )
    
    # 状态和优先级
    status: Mapped[TaskStatus] = mapped_column(
        Enum(TaskStatus), 
        default=TaskStatus.PENDING, 
        nullable=False, 
        index=True,
        comment="任务状态"
    )
    priority: Mapped[TaskPriority] = mapped_column(
        Enum(TaskPriority), 
        default=TaskPriority.MEDIUM, 
        nullable=False, 
        index=True,
        comment="任务优先级"
    )
    
    # 关联信息
    owner_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="任务所有者ID"
    )
    
    # 分类和标签
    category: Mapped[str] = mapped_column(
        String(50), 
        nullable=True, 
        index=True,
        comment="任务分类"
    )
    tags: Mapped[str] = mapped_column(
        String(500), 
        nullable=True,
        comment="任务标签(逗号分隔)"
    )
    
    # 时间相关
    due_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True, 
        index=True,
        comment="截止日期"
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="开始时间"
    )
    completed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="完成时间"
    )
    
    # 进度和估算
    progress: Mapped[int] = mapped_column(
        Integer, 
        default=0, 
        nullable=False,
        comment="完成进度(0-100)"
    )
    estimated_hours: Mapped[int] = mapped_column(
        Integer, 
        nullable=True,
        comment="预估工时(小时)"
    )
    actual_hours: Mapped[int] = mapped_column(
        Integer, 
        nullable=True,
        comment="实际工时(小时)"
    )
    
    # 扩展信息
    notes: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="任务备注"
    )
    attachments: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="附件信息(JSON)"
    )
    external_id: Mapped[str] = mapped_column(
        String(100), 
        nullable=True, 
        index=True,
        comment="外部系统ID"
    )
    
    # 状态标记
    is_starred: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="是否标星"
    )
    is_archived: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False, 
        index=True,
        comment="是否已归档"
    )
    is_deleted: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False, 
        index=True,
        comment="是否已删除"
    )
    
    # 提醒设置
    reminder_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=True,
        comment="提醒时间"
    )
    reminder_sent: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="提醒是否已发送"
    )
    
    # 关系映射
    owner: Mapped["User"] = relationship(
        "User",
        back_populates="tasks",
        lazy="select"
    )
    
    def __repr__(self) -> str:
        return f"<Task(id={self.id}, title='{self.title}', status='{self.status}')>"
    
    @property
    def is_overdue(self) -> bool:
        """检查任务是否过期"""
        if not self.due_date:
            return False
        return (
            self.status not in [TaskStatus.COMPLETED, TaskStatus.CANCELLED, TaskStatus.ARCHIVED] 
            and datetime.utcnow() > self.due_date
        )
    
    @property
    def is_due_soon(self, hours: int = 24) -> bool:
        """检查任务是否即将到期"""
        if not self.due_date:
            return False
        from datetime import timedelta
        threshold = datetime.utcnow() + timedelta(hours=hours)
        return (
            self.status not in [TaskStatus.COMPLETED, TaskStatus.CANCELLED, TaskStatus.ARCHIVED]
            and self.due_date <= threshold
        )
    
    @property
    def tag_list(self) -> list:
        """获取标签列表"""
        if not self.tags:
            return []
        return [tag.strip() for tag in self.tags.split(",") if tag.strip()]
    
    @tag_list.setter
    def tag_list(self, tags: list):
        """设置标签列表"""
        self.tags = ",".join(tags) if tags else None
    
    @property
    def duration_days(self) -> Optional[int]:
        """获取任务持续天数"""
        if not self.started_at or not self.completed_at:
            return None
        return (self.completed_at - self.started_at).days
    
    def mark_as_started(self):
        """标记任务为开始状态"""
        if self.status == TaskStatus.PENDING:
            self.status = TaskStatus.IN_PROGRESS
            self.started_at = datetime.utcnow()
    
    def mark_as_completed(self):
        """标记任务为完成状态"""
        self.status = TaskStatus.COMPLETED
        self.completed_at = datetime.utcnow()
        self.progress = 100
    
    def mark_as_cancelled(self):
        """标记任务为取消状态"""
        self.status = TaskStatus.CANCELLED
    
    def archive(self):
        """归档任务"""
        self.is_archived = True
        self.status = TaskStatus.ARCHIVED
    
    def soft_delete(self):
        """软删除任务"""
        self.is_deleted = True
    
    def to_dict(self, include_owner: bool = False) -> dict:
        """转换为字典"""
        data = {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "status": self.status.value,
            "priority": self.priority.value,
            "category": self.category,
            "tags": self.tag_list,
            "due_date": self.due_date.isoformat() if self.due_date else None,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "progress": self.progress,
            "estimated_hours": self.estimated_hours,
            "actual_hours": self.actual_hours,
            "notes": self.notes,
            "is_starred": self.is_starred,
            "is_archived": self.is_archived,
            "reminder_at": self.reminder_at.isoformat() if self.reminder_at else None,
            "reminder_sent": self.reminder_sent,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "is_overdue": self.is_overdue,
            "is_due_soon": self.is_due_soon,
        }
        
        if include_owner and self.owner:
            data["owner"] = {
                "id": self.owner.id,
                "username": self.owner.username,
                "full_name": self.owner.full_name,
                "avatar_url": self.owner.avatar_url,
            }
        else:
            data["owner_id"] = self.owner_id
        
        return data


class TaskComment(Base):
    """任务评论模型"""
    
    __tablename__ = "task_comments"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="评论ID"
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
    task_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("tasks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="任务ID"
    )
    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="评论者ID"
    )
    
    # 评论内容
    content: Mapped[str] = mapped_column(
        Text, 
        nullable=False,
        comment="评论内容"
    )
    
    # 评论类型
    comment_type: Mapped[str] = mapped_column(
        String(20), 
        default="comment", 
        nullable=False,
        comment="评论类型"
    )
    
    # 状态
    is_deleted: Mapped[bool] = mapped_column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="是否已删除"
    )
    
    def __repr__(self) -> str:
        return f"<TaskComment(id={self.id}, task_id={self.task_id}, user_id={self.user_id})>"
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            "id": self.id,
            "task_id": self.task_id,
            "user_id": self.user_id,
            "content": self.content,
            "comment_type": self.comment_type,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


class TaskActivity(Base):
    """任务活动记录模型"""
    
    __tablename__ = "task_activities"
    
    # 主键
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="活动ID"
    )
    
    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )
    
    # 关联信息
    task_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("tasks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="任务ID"
    )
    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="操作者ID"
    )
    
    # 活动信息
    activity_type: Mapped[str] = mapped_column(
        String(50), 
        nullable=False, 
        index=True,
        comment="活动类型"
    )
    description: Mapped[str] = mapped_column(
        String(500), 
        nullable=False,
        comment="活动描述"
    )
    old_value: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="旧值"
    )
    new_value: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="新值"
    )
    
    # 元数据
    meta_data: Mapped[str] = mapped_column(
        Text, 
        nullable=True,
        comment="额外元数据(JSON)"
    )
    
    def __repr__(self) -> str:
        return f"<TaskActivity(id={self.id}, task_id={self.task_id}, type='{self.activity_type}')>"
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            "id": self.id,
            "task_id": self.task_id,
            "user_id": self.user_id,
            "activity_type": self.activity_type,
            "description": self.description,
            "old_value": self.old_value,
            "new_value": self.new_value,
            "metadata": self.meta_data,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }