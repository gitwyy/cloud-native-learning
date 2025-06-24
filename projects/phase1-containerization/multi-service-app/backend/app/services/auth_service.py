"""
认证服务
处理用户认证、注册、登录相关业务逻辑
"""

import jwt
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_

from app.core.config import get_settings
from app.core.cache import cache_manager
from app.models.user import User, UserSession, UserLoginLog
from app.schemas.user import UserCreate, UserLogin, UserResponse, TokenResponse
from app.utils.logger import setup_logger

settings = get_settings()
logger = setup_logger(__name__)

# 密码加密上下文
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthService:
    """认证服务类"""
    
    def __init__(self):
        self.settings = settings
        
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """验证密码"""
        return pwd_context.verify(plain_password, hashed_password)
    
    def get_password_hash(self, password: str) -> str:
        """获取密码哈希"""
        return pwd_context.hash(password)
    
    def create_access_token(self, data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """创建访问令牌"""
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=self.settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        
        to_encode.update({"exp": expire, "type": "access"})
        encoded_jwt = jwt.encode(to_encode, self.settings.SECRET_KEY, algorithm=self.settings.ALGORITHM)
        return encoded_jwt
    
    def create_refresh_token(self, data: Dict[str, Any]) -> str:
        """创建刷新令牌"""
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(days=self.settings.REFRESH_TOKEN_EXPIRE_DAYS)
        to_encode.update({"exp": expire, "type": "refresh"})
        encoded_jwt = jwt.encode(to_encode, self.settings.SECRET_KEY, algorithm=self.settings.ALGORITHM)
        return encoded_jwt
    
    def verify_token(self, token: str, token_type: str = "access") -> Dict[str, Any]:
        """验证令牌"""
        try:
            payload = jwt.decode(token, self.settings.SECRET_KEY, algorithms=[self.settings.ALGORITHM])
            
            # 检查令牌类型
            if payload.get("type") != token_type:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="无效的令牌类型"
                )
            
            # 检查是否过期
            exp = payload.get("exp")
            if exp and datetime.fromtimestamp(exp) < datetime.utcnow():
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="令牌已过期"
                )
            
            return payload
            
        except jwt.PyJWTError as e:
            logger.error(f"令牌验证失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的令牌"
            )
    
    async def register_user(self, user_data: UserCreate, db: AsyncSession) -> UserResponse:
        """用户注册"""
        try:
            # 检查用户名是否已存在
            existing_user = await db.execute(
                select(User).where(
                    or_(User.username == user_data.username, User.email == user_data.email)
                )
            )
            if existing_user.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="用户名或邮箱已存在"
                )
            
            # 创建新用户
            hashed_password = self.get_password_hash(user_data.password)
            new_user = User(
                username=user_data.username,
                email=user_data.email,
                full_name=user_data.full_name,
                bio=user_data.bio,
                hashed_password=hashed_password,
                timezone=user_data.timezone,
                language=user_data.language,
                theme=user_data.theme,
                is_active=True,
                is_verified=False
            )
            
            db.add(new_user)
            await db.commit()
            await db.refresh(new_user)
            
            logger.info(f"新用户注册成功: {user_data.username}")
            
            return UserResponse.from_orm(new_user)
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"用户注册失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="注册失败"
            )
    
    async def authenticate_user(self, login_data: UserLogin, db: AsyncSession) -> User:
        """用户认证"""
        try:
            # 查找用户（支持用户名或邮箱登录）
            user_query = await db.execute(
                select(User).where(
                    or_(
                        User.username == login_data.username,
                        User.email == login_data.username
                    )
                )
            )
            user = user_query.scalar_one_or_none()
            
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="用户名或密码错误"
                )
            
            # 检查用户是否被锁定
            if user.is_locked:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"账户已被锁定，请在 {user.locked_until} 后重试"
                )
            
            # 检查用户是否激活
            if not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="账户已被禁用"
                )
            
            # 验证密码
            if not self.verify_password(login_data.password, user.hashed_password):
                # 增加失败登录次数
                user.failed_login_attempts += 1
                
                # 检查是否需要锁定账户
                if user.failed_login_attempts >= self.settings.MAX_LOGIN_ATTEMPTS:
                    user.locked_until = datetime.utcnow() + timedelta(
                        minutes=self.settings.LOCKOUT_DURATION_MINUTES
                    )
                    logger.warning(f"用户 {user.username} 因多次登录失败被锁定")
                
                await db.commit()
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="用户名或密码错误"
                )
            
            # 登录成功，重置失败次数
            user.failed_login_attempts = 0
            user.locked_until = None
            user.last_login = datetime.utcnow()
            await db.commit()
            
            return user
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"用户认证失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="认证失败"
            )
    
    async def login_user(self, login_data: UserLogin, db: AsyncSession, 
                        ip_address: str = None, user_agent: str = None) -> TokenResponse:
        """用户登录"""
        try:
            # 认证用户
            user = await self.authenticate_user(login_data, db)
            
            # 创建令牌
            token_data = {"sub": str(user.id), "username": user.username}
            access_token = self.create_access_token(token_data)
            refresh_token = self.create_refresh_token(token_data)
            
            # 记录登录日志
            login_log = UserLoginLog(
                user_id=user.id,
                username=user.username,
                email=user.email,
                login_successful=True,
                ip_address=ip_address,
                user_agent=user_agent
            )
            db.add(login_log)
            
            # 创建用户会话
            session = UserSession(
                session_id=f"session_{user.id}_{datetime.utcnow().timestamp()}",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                expires_at=datetime.utcnow() + timedelta(days=self.settings.REFRESH_TOKEN_EXPIRE_DAYS)
            )
            db.add(session)
            
            await db.commit()
            
            # 缓存用户信息
            await cache_manager.set_json(
                f"user:{user.id}",
                user.to_dict(),
                expire=3600
            )
            
            logger.info(f"用户登录成功: {user.username}")
            
            return TokenResponse(
                access_token=access_token,
                refresh_token=refresh_token,
                token_type="bearer",
                expires_in=self.settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                user=UserResponse.from_orm(user)
            )
            
        except HTTPException:
            # 记录失败的登录尝试
            try:
                login_log = UserLoginLog(
                    username=login_data.username,
                    login_successful=False,
                    failure_reason="Invalid credentials",
                    ip_address=ip_address,
                    user_agent=user_agent
                )
                db.add(login_log)
                await db.commit()
            except:
                pass
            raise
        except Exception as e:
            logger.error(f"用户登录失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="登录失败"
            )
    
    async def refresh_access_token(self, refresh_token: str, db: AsyncSession) -> TokenResponse:
        """刷新访问令牌"""
        try:
            # 验证刷新令牌
            payload = self.verify_token(refresh_token, "refresh")
            user_id = int(payload.get("sub"))
            
            # 获取用户信息
            user_query = await db.execute(select(User).where(User.id == user_id))
            user = user_query.scalar_one_or_none()
            
            if not user or not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="用户不存在或已被禁用"
                )
            
            # 创建新的访问令牌
            token_data = {"sub": str(user.id), "username": user.username}
            access_token = self.create_access_token(token_data)
            
            logger.info(f"刷新令牌成功: {user.username}")
            
            return TokenResponse(
                access_token=access_token,
                refresh_token=refresh_token,  # 返回原刷新令牌
                token_type="bearer",
                expires_in=self.settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                user=UserResponse.from_orm(user)
            )
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"刷新令牌失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="刷新令牌失败"
            )
    
    async def get_current_user(self, token: str, db: AsyncSession) -> User:
        """根据令牌获取当前用户"""
        try:
            # 验证令牌
            payload = self.verify_token(token)
            user_id = int(payload.get("sub"))
            
            # 先从缓存获取用户信息
            cached_user = await cache_manager.get_json(f"user:{user_id}")
            if cached_user:
                # 从数据库获取最新用户信息以确保准确性
                user_query = await db.execute(select(User).where(User.id == user_id))
                user = user_query.scalar_one_or_none()
                if user and user.is_active:
                    return user
            
            # 从数据库获取用户信息
            user_query = await db.execute(select(User).where(User.id == user_id))
            user = user_query.scalar_one_or_none()
            
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="用户不存在"
                )
            
            if not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="用户已被禁用"
                )
            
            # 更新缓存
            await cache_manager.set_json(
                f"user:{user.id}",
                user.to_dict(),
                expire=3600
            )
            
            return user
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"获取当前用户失败: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="获取用户信息失败"
            )
    
    async def logout_user(self, token: str, db: AsyncSession) -> bool:
        """用户登出"""
        try:
            # 获取当前用户
            user = await self.get_current_user(token, db)
            
            # 将令牌加入黑名单（使用Redis缓存）
            payload = self.verify_token(token)
            exp = payload.get("exp")
            if exp:
                # 计算令牌剩余有效时间
                remaining_time = datetime.fromtimestamp(exp) - datetime.utcnow()
                if remaining_time.total_seconds() > 0:
                    await cache_manager.set(
                        f"blacklist_token:{token}",
                        "true",
                        expire=int(remaining_time.total_seconds())
                    )
            
            # 清除用户缓存
            await cache_manager.delete(f"user:{user.id}")
            
            # 禁用相关会话
            await db.execute(
                select(UserSession).where(
                    and_(UserSession.user_id == user.id, UserSession.is_active == True)
                )
            )
            sessions = await db.execute(
                select(UserSession).where(
                    and_(UserSession.user_id == user.id, UserSession.is_active == True)
                )
            )
            for session in sessions.scalars():
                session.is_active = False
            
            await db.commit()
            
            logger.info(f"用户登出成功: {user.username}")
            return True
            
        except Exception as e:
            logger.error(f"用户登出失败: {e}")
            return False
    
    async def change_password(self, user: User, current_password: str, 
                            new_password: str, db: AsyncSession) -> bool:
        """修改密码"""
        try:
            # 验证当前密码
            if not self.verify_password(current_password, user.hashed_password):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="当前密码错误"
                )
            
            # 更新密码
            user.hashed_password = self.get_password_hash(new_password)
            user.password_changed_at = datetime.utcnow()
            
            await db.commit()
            
            # 清除用户缓存
            await cache_manager.delete(f"user:{user.id}")
            
            logger.info(f"用户 {user.username} 修改密码成功")
            return True
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"修改密码失败: {e}")
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="修改密码失败"
            )


# 全局认证服务实例
auth_service = AuthService()