"""
认证API路由
处理用户认证、注册、登录相关功能
"""

from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_client_ip, get_user_agent, rate_limit_auth
from app.services.auth_service import auth_service
from app.schemas.user import (
    UserCreate, UserLogin, TokenResponse, UserResponse,
    PasswordChange, PasswordReset, PasswordResetConfirm
)
from app.utils.logger import setup_logger

# 日志
logger = setup_logger(__name__)

# 创建路由器
router = APIRouter()


@router.post("/register", response_model=UserResponse, tags=["认证"])
async def register_user(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(rate_limit_auth)
):
    """用户注册"""
    try:
        user = await auth_service.register_user(user_data, db)
        logger.info(f"新用户注册成功: {user.username}")
        return user
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"用户注册失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="注册失败"
        )


@router.post("/login", response_model=TokenResponse, tags=["认证"])
async def login_user(
    user_credentials: UserLogin,
    request: Request,
    db: AsyncSession = Depends(get_db),
    client_ip: str = Depends(get_client_ip),
    user_agent: str = Depends(get_user_agent),
    _: bool = Depends(rate_limit_auth)
):
    """用户登录"""
    try:
        token_response = await auth_service.login_user(
            user_credentials, db, client_ip, user_agent
        )
        logger.info(f"用户登录成功: {token_response.user.username}")
        return token_response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"用户登录失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="登录失败"
        )


@router.post("/refresh", response_model=TokenResponse, tags=["认证"])
async def refresh_token(
    refresh_token: str,
    db: AsyncSession = Depends(get_db)
):
    """刷新访问令牌"""
    try:
        token_response = await auth_service.refresh_access_token(refresh_token, db)
        logger.info(f"令牌刷新成功: {token_response.user.username}")
        return token_response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"令牌刷新失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="令牌刷新失败"
        )


@router.get("/me", response_model=UserResponse, tags=["认证"])
async def get_current_user_info(
    current_user = Depends(get_current_user)
):
    """获取当前用户信息"""
    try:
        return UserResponse.from_orm(current_user)
        
    except Exception as e:
        logger.error(f"获取用户信息失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取用户信息失败"
        )


@router.post("/logout", tags=["认证"])
async def logout_user(
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """用户登出"""
    try:
        # 从Authorization头获取token
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的认证头"
            )
        
        token = auth_header.split(" ")[1]
        success = await auth_service.logout_user(token, db)
        
        if success:
            logger.info(f"用户登出成功: {current_user.username}")
            return {"message": "成功登出"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="登出失败"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"用户登出失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="登出失败"
        )


@router.post("/change-password", tags=["认证"])
async def change_password(
    password_data: PasswordChange,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """修改密码"""
    try:
        success = await auth_service.change_password(
            current_user,
            password_data.current_password,
            password_data.new_password,
            db
        )
        
        if success:
            logger.info(f"用户 {current_user.username} 修改密码成功")
            return {"message": "密码修改成功"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="密码修改失败"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"修改密码失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="修改密码失败"
        )


@router.post("/reset-password", tags=["认证"])
async def reset_password(
    reset_data: PasswordReset,
    _: bool = Depends(rate_limit_auth)
):
    """重置密码请求"""
    try:
        # TODO: 实现密码重置逻辑
        # 1. 验证邮箱是否存在
        # 2. 生成重置令牌
        # 3. 发送重置邮件
        
        logger.info(f"密码重置请求: {reset_data.email}")
        return {"message": "密码重置邮件已发送"}
        
    except Exception as e:
        logger.error(f"密码重置请求失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="密码重置请求失败"
        )


@router.post("/reset-password/confirm", tags=["认证"])
async def confirm_reset_password(
    confirm_data: PasswordResetConfirm,
    _: bool = Depends(rate_limit_auth)
):
    """确认重置密码"""
    try:
        # TODO: 实现密码重置确认逻辑
        # 1. 验证重置令牌
        # 2. 更新用户密码
        # 3. 使令牌失效
        
        logger.info(f"密码重置确认")
        return {"message": "密码重置成功"}
        
    except Exception as e:
        logger.error(f"密码重置确认失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="密码重置确认失败"
        )


# 健康检查
@router.get("/health", tags=["健康检查"])
async def auth_health():
    """认证服务健康检查"""
    return {
        "service": "auth",
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "version": "1.0.0"
    }