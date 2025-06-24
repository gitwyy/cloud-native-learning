"""
API v1包初始化
导入所有v1版本的API路由模块
"""

from . import auth, users, tasks, notifications

__all__ = ["auth", "users", "tasks", "notifications"]