"""
Redis缓存管理
提供缓存和会话存储功能
"""

from typing import Optional, Any, Union
import json
import asyncio
from datetime import timedelta
import redis.asyncio as redis

from app.core.config import get_settings
from app.utils.logger import setup_logger

settings = get_settings()
logger = setup_logger(__name__)


class CacheManager:
    """Redis缓存管理器"""
    
    def __init__(self):
        self._redis: Optional[redis.Redis] = None
        self._connected = False
    
    async def connect(self):
        """连接Redis"""
        try:
            # 解析Redis URL（用于日志）
            # 安全地提取主机信息（避免记录密码）
            redis_url = settings.REDIS_URL
            redis_host = redis_url.split('@')[-1].split('/')[0]
            
            logger.info(f"正在连接Redis: {redis_host}...")
            
            # 创建Redis连接
            self._redis = redis.from_url(
                redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True,
                health_check_interval=30
            )
            
            # 测试连接
            await self._redis.ping()
            
            self._connected = True
            logger.info(f"✅ Redis连接成功: {redis_host}")
            
        except Exception as e:
            logger.error(f"❌ Redis连接失败: {e}")
            self._connected = False
            self._redis = None
            # 不抛出异常，允许应用在没有Redis的情况下运行
    
    async def disconnect(self):
        """断开Redis连接"""
        if self._redis:
            await self._redis.close()
            self._connected = False
            logger.info("Redis连接已关闭")
    
    async def get(self, key: str) -> Optional[str]:
        """获取缓存值"""
        if not self._connected or not self._redis:
            logger.warning("Redis未连接，无法获取缓存")
            return None
        
        try:
            return await self._redis.get(key)
        except Exception as e:
            logger.error(f"Redis GET失败: {e}")
            return None
    
    async def set(
        self, 
        key: str, 
        value: Union[str, int, float, dict, list], 
        expire: Optional[int] = None
    ) -> bool:
        """设置缓存值"""
        if not self._connected or not self._redis:
            logger.warning("Redis未连接，无法设置缓存")
            return False
        
        try:
            # 如果值是字典或列表，转换为JSON
            if isinstance(value, (dict, list)):
                value = json.dumps(value, ensure_ascii=False)
            
            # 设置过期时间
            if expire is None:
                expire = getattr(settings, 'REDIS_TTL', 3600)
            
            result = await self._redis.set(key, value, ex=expire)
            return bool(result)
            
        except Exception as e:
            logger.error(f"Redis SET失败: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        """删除缓存值"""
        if not self._connected or not self._redis:
            logger.warning("Redis未连接，无法删除缓存")
            return False
        
        try:
            result = await self._redis.delete(key)
            return bool(result)
        except Exception as e:
            logger.error(f"Redis DELETE失败: {e}")
            return False
    
    async def exists(self, key: str) -> bool:
        """检查键是否存在"""
        if not self._connected or not self._redis:
            return False
        
        try:
            result = await self._redis.exists(key)
            return bool(result)
        except Exception as e:
            logger.error(f"Redis EXISTS失败: {e}")
            return False
    
    async def expire(self, key: str, seconds: int) -> bool:
        """设置键的过期时间"""
        if not self._connected or not self._redis:
            return False
        
        try:
            result = await self._redis.expire(key, seconds)
            return bool(result)
        except Exception as e:
            logger.error(f"Redis EXPIRE失败: {e}")
            return False
    
    async def get_json(self, key: str) -> Optional[dict]:
        """获取JSON格式的缓存值"""
        value = await self.get(key)
        if value:
            try:
                return json.loads(value)
            except json.JSONDecodeError as e:
                logger.error(f"JSON解析失败: {e}")
        return None
    
    async def set_json(self, key: str, value: dict, expire: Optional[int] = None) -> bool:
        """设置JSON格式的缓存值"""
        return await self.set(key, value, expire)
    
    @property
    def is_connected(self) -> bool:
        """检查是否已连接"""
        return self._connected
    
    async def ping(self) -> bool:
        """Ping Redis服务器"""
        if not self._connected or not self._redis:
            return False
        
        try:
            result = await self._redis.ping()
            return result == "PONG"
        except Exception as e:
            logger.error(f"Redis PING失败: {e}")
            return False


# 全局缓存管理器实例
cache_manager = CacheManager()


# 便捷函数
async def get_cache(key: str) -> Optional[str]:
    """获取缓存值"""
    return await cache_manager.get(key)


async def set_cache(key: str, value: Any, expire: Optional[int] = None) -> bool:
    """设置缓存值"""
    return await cache_manager.set(key, value, expire)


async def delete_cache(key: str) -> bool:
    """删除缓存值"""
    return await cache_manager.delete(key)


async def get_json_cache(key: str) -> Optional[dict]:
    """获取JSON缓存值"""
    return await cache_manager.get_json(key)


async def set_json_cache(key: str, value: dict, expire: Optional[int] = None) -> bool:
    """设置JSON缓存值"""
    return await cache_manager.set_json(key, value, expire)


# 初始化函数
async def init_redis():
    """初始化Redis连接"""
    try:
        await cache_manager.connect()
        logger.info("Redis初始化完成")
    except Exception as e:
        logger.error(f"Redis初始化失败: {e}")
        # 不抛出异常，允许应用在没有Redis的情况下运行


async def close_redis():
    """关闭Redis连接"""
    await cache_manager.disconnect()


async def get_redis_status() -> str:
    """获取Redis状态"""
    try:
        if not cache_manager.is_connected:
            return "disconnected"
        
        if await cache_manager.ping():
            return "healthy"
        else:
            return "unhealthy"
            
    except Exception as e:
        logger.error(f"Redis状态检查失败: {e}")
        return "error"


# 会话管理
class SessionManager:
    """会话管理器"""
    
    def __init__(self, prefix: str = "session:"):
        self.prefix = prefix
    
    async def get_session(self, session_id: str) -> Optional[dict]:
        """获取会话数据"""
        key = f"{self.prefix}{session_id}"
        return await get_json_cache(key)
    
    async def set_session(self, session_id: str, data: dict, expire: int = 3600) -> bool:
        """设置会话数据"""
        key = f"{self.prefix}{session_id}"
        return await set_json_cache(key, data, expire)
    
    async def delete_session(self, session_id: str) -> bool:
        """删除会话"""
        key = f"{self.prefix}{session_id}"
        return await delete_cache(key)


# 全局会话管理器
session_manager = SessionManager()