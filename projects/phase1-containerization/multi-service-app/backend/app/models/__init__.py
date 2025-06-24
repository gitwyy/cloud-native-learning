"""
数据模型包
导入所有数据模型，确保SQLAlchemy能够正确识别和创建表
"""

from app.models.user import (
    User,
    UserSession,
    UserLoginLog,
)

from app.models.task import (
    Task,
    TaskComment,
    TaskActivity,
    TaskStatus,
    TaskPriority,
)

from app.models.notification import (
    Notification,
    NotificationTemplate,
    NotificationSetting,
    NotificationType,
    NotificationPriority,
    NotificationStatus,
)

# 导出所有模型类
__all__ = [
    # 用户相关模型
    "User",
    "UserSession", 
    "UserLoginLog",
    
    # 任务相关模型
    "Task",
    "TaskComment",
    "TaskActivity",
    "TaskStatus",
    "TaskPriority",
    
    # 通知相关模型
    "Notification",
    "NotificationTemplate", 
    "NotificationSetting",
    "NotificationType",
    "NotificationPriority",
    "NotificationStatus",
]