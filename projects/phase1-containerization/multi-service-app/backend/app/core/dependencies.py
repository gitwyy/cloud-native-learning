"""
依赖注入模块
提供FastAPI依赖注入函数
"""

from typing import AsyncGenerator, Optional
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.cache import cache_manager
from app.models.user import User
from app.services.auth_service import auth_service
from app.utils.logger import setup_logger

logger = setup_logger(__name__)

# HTTP Bearer token安全方案
security = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """获取当前认证用户"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="需要认证",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    try:
        # 检查令牌是否在黑名单中
        blacklisted = await cache_manager.get(f"blacklist_token:{credentials.credentials}")
        if blacklisted:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="令牌已失效",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # 获取当前用户
        user = await auth_service.get_current_user(credentials.credentials, db)
        return user
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"认证失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="认证失败",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """获取当前活跃用户"""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户账户已被禁用"
        )
    return current_user


async def get_current_verified_user(current_user: User = Depends(get_current_user)) -> User:
    """获取当前已验证用户"""
    if not current_user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户邮箱未验证"
        )
    return current_user


async def get_current_superuser(current_user: User = Depends(get_current_user)) -> User:
    """获取当前超级用户"""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="权限不足"
        )
    return current_user


def get_optional_current_user():
    """获取可选的当前用户（用于公开接口）"""
    async def _get_optional_current_user(
        credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
        db: AsyncSession = Depends(get_db)
    ) -> Optional[User]:
        if not credentials:
            return None
        
        try:
            # 检查令牌是否在黑名单中
            blacklisted = await cache_manager.get(f"blacklist_token:{credentials.credentials}")
            if blacklisted:
                return None
            
            # 获取当前用户
            user = await auth_service.get_current_user(credentials.credentials, db)
            return user
            
        except:
            return None
    
    return _get_optional_current_user


async def get_client_ip(request: Request) -> str:
    """获取客户端IP地址"""
    # 优先从代理头获取真实IP
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    
    # 从连接信息获取
    return request.client.host if request.client else "unknown"


async def get_user_agent(request: Request) -> str:
    """获取用户代理信息"""
    return request.headers.get("User-Agent", "unknown")


class RateLimit:
    """速率限制依赖"""
    
    def __init__(self, requests: int, window: int):
        self.requests = requests
        self.window = window
    
    async def __call__(self, request: Request, client_ip: str = Depends(get_client_ip)):
        """执行速率限制检查"""
        try:
            # 使用Redis实现滑动窗口速率限制
            key = f"rate_limit:{client_ip}:{request.url.path}"
            
            # 获取当前请求次数
            current_requests = await cache_manager.get(key)
            
            if current_requests is None:
                # 第一次请求
                await cache_manager.set(key, "1", expire=self.window)
                return True
            
            if int(current_requests) >= self.requests:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="请求过于频繁，请稍后再试"
                )
            
            # 增加请求计数
            await cache_manager.set(key, str(int(current_requests) + 1), expire=self.window)
            return True
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"速率限制检查失败: {e}")
            # 速率限制失败时允许请求通过
            return True


# 常用的速率限制实例
rate_limit_standard = RateLimit(requests=100, window=3600)  # 每小时100次
rate_limit_strict = RateLimit(requests=10, window=60)       # 每分钟10次
rate_limit_auth = RateLimit(requests=5, window=300)         # 每5分钟5次（用于认证接口）


async def validate_pagination(page: int = 1, page_size: int = 20) -> dict:
    """验证分页参数"""
    if page < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="页码必须大于0"
        )
    
    if page_size < 1 or page_size > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="每页数量必须在1-100之间"
        )
    
    return {"page": page, "page_size": page_size}


async def get_database_session() -> AsyncGenerator[AsyncSession, None]:
    """获取数据库会话（用于手动管理事务）"""
    async for session in get_db():
        yield session