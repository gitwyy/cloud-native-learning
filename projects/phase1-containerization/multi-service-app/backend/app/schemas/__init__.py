"""
Pydantic模型包
导入所有API数据模型
"""

from app.schemas.user import (
    UserBase,
    UserCreate,
    UserUpdate,
    UserResponse,
    UserLogin,
    TokenResponse,
    PasswordChange,
    UserProfile,
    UserSettings,
    UserList,
    UserSearch,
    UserStats,
    EmailVerification,
    PasswordReset,
    PasswordResetConfirm,
    UserActivity,
    UserSession,
)

from app.schemas.task import (
    TaskBase,
    TaskCreate,
    TaskUpdate,
    Task,
    TaskWithOwner,
    TaskStats,
    TaskListParams,
    TaskCommentBase,
    TaskCommentCreate,
    TaskComment,
    TaskActivity,
    TaskBatchUpdate,
    TaskBatchDelete,
    TaskStatus,
    TaskPriority,
)

from app.schemas.notification import (
    NotificationBase,
    NotificationCreate,
    NotificationUpdate,
    Notification,
    NotificationWithUser,
    NotificationStats,
    NotificationListParams,
    NotificationTemplateBase,
    NotificationTemplateCreate,
    NotificationTemplateUpdate,
    NotificationTemplate,
    NotificationSettingBase,
    NotificationSettingUpdate,
    NotificationSetting,
    NotificationBatchUpdate,
    NotificationBatchDelete,
    NotificationSendRequest,
    NotificationType,
    NotificationPriority,
    NotificationStatus,
)

# 导出所有模型
__all__ = [
    # 用户相关
    "UserBase",
    "UserCreate",
    "UserUpdate",
    "UserResponse",
    "UserLogin",
    "TokenResponse",
    "PasswordChange",
    "UserProfile",
    "UserSettings",
    "UserList",
    "UserSearch",
    "UserStats",
    "EmailVerification",
    "PasswordReset",
    "PasswordResetConfirm",
    "UserActivity",
    "UserSession",
    
    # 任务相关
    "TaskBase",
    "TaskCreate",
    "TaskUpdate",
    "Task",
    "TaskWithOwner",
    "TaskStats",
    "TaskListParams",
    "TaskCommentBase",
    "TaskCommentCreate",
    "TaskComment",
    "TaskActivity",
    "TaskBatchUpdate",
    "TaskBatchDelete",
    "TaskStatus",
    "TaskPriority",
    
    # 通知相关
    "NotificationBase",
    "NotificationCreate",
    "NotificationUpdate",
    "Notification",
    "NotificationWithUser",
    "NotificationStats",
    "NotificationListParams",
    "NotificationTemplateBase",
    "NotificationTemplateCreate",
    "NotificationTemplateUpdate",
    "NotificationTemplate",
    "NotificationSettingBase",
    "NotificationSettingUpdate",
    "NotificationSetting",
    "NotificationBatchUpdate",
    "NotificationBatchDelete",
    "NotificationSendRequest",
    "NotificationType",
    "NotificationPriority",
    "NotificationStatus",
]