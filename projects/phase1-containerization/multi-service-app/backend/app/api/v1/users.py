"""
用户管理API路由
处理用户资料管理相关功能
"""

from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr

from app.core.dependencies import get_current_user
from app.models.user import User
from app.utils.logger import setup_logger

# 日志
logger = setup_logger(__name__)

# 创建路由器
router = APIRouter()


# Pydantic模型
class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None


class UserProfile(BaseModel):
    id: int
    username: str
    email: str
    full_name: Optional[str] = None
    is_active: bool
    created_at: datetime


class UserStats(BaseModel):
    total_tasks: int
    completed_tasks: int
    pending_tasks: int
    total_notifications: int
    unread_notifications: int


# 模拟用户统计数据
def get_user_stats(username: str) -> UserStats:
    """获取用户统计信息"""
    # 这里应该从数据库查询真实数据
    return UserStats(
        total_tasks=10,
        completed_tasks=5,
        pending_tasks=5,
        total_notifications=3,
        unread_notifications=1
    )


@router.get("/profile", response_model=UserProfile, tags=["用户管理"])
async def get_user_profile(current_user: User = Depends(get_current_user)):
    """获取用户资料"""
    try:
        logger.info(f"获取用户资料: {current_user.username}")
        
        return UserProfile(
            id=current_user.id,
            username=current_user.username,
            email=current_user.email or "",
            full_name=current_user.full_name,
            is_active=current_user.is_active,
            created_at=current_user.created_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取用户资料失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取用户资料失败"
        )


@router.put("/profile", response_model=UserProfile, tags=["用户管理"])
async def update_user_profile(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user)
):
    """更新用户资料"""
    try:
        # 这里应该更新数据库中的用户信息
        # 目前只是模拟更新
        
        from app.api.v1.auth import fake_users_db
        
        user = fake_users_db.get(current_user.username)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用户不存在"
            )
        
        # 更新用户信息
        if user_update.email:
            user["email"] = user_update.email
        if user_update.full_name:
            user["full_name"] = user_update.full_name
        
        logger.info(f"更新用户资料: {current_user.username}")
        
        return UserProfile(
            id=user["id"],
            username=user["username"],
            email=user["email"],
            full_name=user["full_name"],
            is_active=user["is_active"],
            created_at=user["created_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新用户资料失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="更新用户资料失败"
        )


@router.get("/stats", response_model=UserStats, tags=["用户管理"])
async def get_user_statistics(current_user: User = Depends(get_current_user)):
    """获取用户统计信息"""
    try:
        stats = get_user_stats(current_user.username)
        
        logger.info(f"获取用户统计信息: {current_user.username}")
        
        return stats
        
    except Exception as e:
        logger.error(f"获取用户统计信息失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取用户统计信息失败"
        )


@router.delete("/account", tags=["用户管理"])
async def delete_user_account(current_user: User = Depends(get_current_user)):
    """删除用户账户"""
    try:
        # 这里应该删除数据库中的用户及相关数据
        # 目前只是模拟删除
        
        from app.api.v1.auth import fake_users_db
        
        if current_user.username in fake_users_db:
            del fake_users_db[current_user.username]
            logger.info(f"删除用户账户: {current_user.username}")
            return {"message": "账户已成功删除"}
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用户不存在"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除用户账户失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="删除用户账户失败"
        )


@router.post("/change-password", tags=["用户管理"])
async def change_password(
    old_password: str,
    new_password: str,
    current_user: User = Depends(get_current_user)
):
    """修改密码"""
    try:
        from app.api.v1.auth import fake_users_db, verify_password, get_password_hash
        
        user = fake_users_db.get(current_user.username)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用户不存在"
            )
        
        # 验证旧密码
        if not verify_password(old_password, user["hashed_password"]):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="旧密码错误"
            )
        
        # 更新密码
        user["hashed_password"] = get_password_hash(new_password)
        
        logger.info(f"修改密码: {current_user.username}")
        
        return {"message": "密码修改成功"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"修改密码失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="修改密码失败"
        )


# 健康检查
@router.get("/health", tags=["健康检查"])
async def users_health():
    """用户服务健康检查"""
    return {
        "service": "users",
        "status": "healthy",
        "timestamp": datetime.utcnow()
    }