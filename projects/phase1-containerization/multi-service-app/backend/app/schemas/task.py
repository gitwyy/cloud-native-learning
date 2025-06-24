"""
任务相关的Pydantic模型
用于API请求和响应的数据验证
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field
from enum import Enum


class TaskStatus(str, Enum):
    """任务状态枚举"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    ARCHIVED = "archived"


class TaskPriority(str, Enum):
    """任务优先级枚举"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


# 基础任务模型
class TaskBase(BaseModel):
    """任务基础模型"""
    title: str = Field(..., min_length=1, max_length=200, description="任务标题")
    description: Optional[str] = Field(None, max_length=1000, description="任务描述")
    priority: TaskPriority = Field(TaskPriority.MEDIUM, description="任务优先级")
    category: Optional[str] = Field(None, max_length=50, description="任务分类")
    tags: Optional[List[str]] = Field(None, description="任务标签")
    due_date: Optional[datetime] = Field(None, description="截止日期")
    estimated_hours: Optional[int] = Field(None, ge=0, description="预估工时")
    notes: Optional[str] = Field(None, description="任务备注")


# 创建任务请求模型
class TaskCreate(TaskBase):
    """创建任务请求模型"""
    pass


# 更新任务请求模型
class TaskUpdate(BaseModel):
    """更新任务请求模型"""
    title: Optional[str] = Field(None, min_length=1, max_length=200, description="任务标题")
    description: Optional[str] = Field(None, max_length=1000, description="任务描述")
    status: Optional[TaskStatus] = Field(None, description="任务状态")
    priority: Optional[TaskPriority] = Field(None, description="任务优先级")
    category: Optional[str] = Field(None, max_length=50, description="任务分类")
    tags: Optional[List[str]] = Field(None, description="任务标签")
    due_date: Optional[datetime] = Field(None, description="截止日期")
    progress: Optional[int] = Field(None, ge=0, le=100, description="完成进度")
    estimated_hours: Optional[int] = Field(None, ge=0, description="预估工时")
    actual_hours: Optional[int] = Field(None, ge=0, description="实际工时")
    notes: Optional[str] = Field(None, description="任务备注")
    is_starred: Optional[bool] = Field(None, description="是否标星")


# 任务响应模型
class Task(TaskBase):
    """任务响应模型"""
    id: int
    status: TaskStatus
    progress: int = Field(0, ge=0, le=100, description="完成进度")
    actual_hours: Optional[int] = Field(None, ge=0, description="实际工时")
    owner_id: int
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    reminder_at: Optional[datetime] = None
    reminder_sent: bool = False
    is_starred: bool = False
    is_archived: bool = False
    is_deleted: bool = False
    created_at: datetime
    updated_at: datetime
    
    # 计算属性
    is_overdue: bool = False
    is_due_soon: bool = False
    
    class Config:
        from_attributes = True


# 带用户信息的任务模型
class TaskWithOwner(Task):
    """带用户信息的任务模型"""
    owner: Optional[dict] = None


# 任务统计模型
class TaskStats(BaseModel):
    """任务统计模型"""
    total_tasks: int = 0
    pending_tasks: int = 0
    in_progress_tasks: int = 0
    completed_tasks: int = 0
    cancelled_tasks: int = 0
    archived_tasks: int = 0
    overdue_tasks: int = 0
    due_soon_tasks: int = 0
    starred_tasks: int = 0
    
    # 按优先级统计
    low_priority_tasks: int = 0
    medium_priority_tasks: int = 0
    high_priority_tasks: int = 0
    urgent_priority_tasks: int = 0


# 任务列表查询参数
class TaskListParams(BaseModel):
    """任务列表查询参数"""
    status: Optional[TaskStatus] = None
    priority: Optional[TaskPriority] = None
    category: Optional[str] = None
    is_starred: Optional[bool] = None
    is_archived: Optional[bool] = None
    is_overdue: Optional[bool] = None
    search: Optional[str] = None
    page: int = Field(1, ge=1, description="页码")
    page_size: int = Field(20, ge=1, le=100, description="每页数量")
    sort_by: Optional[str] = Field("created_at", description="排序字段")
    sort_order: Optional[str] = Field("desc", pattern="^(asc|desc)$", description="排序方向")


# 任务评论模型
class TaskCommentBase(BaseModel):
    """任务评论基础模型"""
    content: str = Field(..., min_length=1, description="评论内容")
    comment_type: str = Field("comment", description="评论类型")


class TaskCommentCreate(TaskCommentBase):
    """创建任务评论请求模型"""
    pass


class TaskComment(TaskCommentBase):
    """任务评论响应模型"""
    id: int
    task_id: int
    user_id: int
    is_deleted: bool = False
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


# 任务活动记录模型
class TaskActivity(BaseModel):
    """任务活动记录模型"""
    id: int
    task_id: int
    user_id: int
    activity_type: str
    description: str
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    metadata: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


# 批量操作模型
class TaskBatchUpdate(BaseModel):
    """批量更新任务模型"""
    task_ids: List[int] = Field(..., min_items=1, description="任务ID列表")
    status: Optional[TaskStatus] = None
    priority: Optional[TaskPriority] = None
    category: Optional[str] = None
    is_starred: Optional[bool] = None
    is_archived: Optional[bool] = None


class TaskBatchDelete(BaseModel):
    """批量删除任务模型"""
    task_ids: List[int] = Field(..., min_items=1, description="任务ID列表")
    permanent: bool = Field(False, description="是否永久删除")