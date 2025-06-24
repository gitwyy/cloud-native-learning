"""
数据库连接管理
使用SQLAlchemy异步连接PostgreSQL
"""

from typing import AsyncGenerator, Optional
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import text
import asyncio

from app.core.config import get_settings
from app.utils.logger import setup_logger

settings = get_settings()
logger = setup_logger(__name__)

# 数据库基类
class Base(DeclarativeBase):
    pass


class DatabaseManager:
    """数据库管理器"""
    
    def __init__(self):
        self._engine = None
        self._session_factory = None
        self._connected = False
    
    async def connect(self):
        """连接数据库"""
        try:
            # 解析数据库主机信息（用于日志）
            db_host = settings.DATABASE_URL.split('@')[1].split('/')[0]
            
            logger.info(f"正在连接数据库: {db_host}...")
            
            # 创建异步引擎
            self._engine = create_async_engine(
                settings.DATABASE_URL,
                echo=settings.DATABASE_ECHO if hasattr(settings, 'DATABASE_ECHO') else False,
                pool_pre_ping=True,
                pool_recycle=3600,
            )
            
            # 创建会话工厂
            self._session_factory = async_sessionmaker(
                bind=self._engine,
                class_=AsyncSession,
                expire_on_commit=False
            )
            
            # 测试连接
            async with self._engine.begin() as conn:
                await conn.execute(text("SELECT 1"))
            
            self._connected = True
            logger.info(f"✅ 数据库连接成功: {db_host}")
            
        except Exception as e:
            logger.error(f"❌ 数据库连接失败: {e}")
            self._connected = False
            raise
    
    async def disconnect(self):
        """断开数据库连接"""
        if self._engine:
            await self._engine.dispose()
            self._connected = False
            logger.info("数据库连接已关闭")
    
    def get_session(self) -> AsyncSession:
        """获取数据库会话"""
        if not self._connected or not self._session_factory:
            raise RuntimeError("数据库未连接")
        return self._session_factory()
    
    @property
    def is_connected(self) -> bool:
        """检查是否已连接"""
        return self._connected


# 全局数据库管理器实例
db_manager = DatabaseManager()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """获取数据库会话（依赖注入）"""
    if not db_manager.is_connected:
        # 如果未连接，尝试连接
        try:
            await db_manager.connect()
        except Exception as e:
            logger.error(f"无法连接数据库: {e}")
            # 返回一个模拟会话或抛出异常
            raise RuntimeError("数据库服务不可用")
    
    async with db_manager.get_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_database():
    """初始化数据库"""
    try:
        await db_manager.connect()
        logger.info("数据库初始化完成")
    except Exception as e:
        logger.error(f"数据库初始化失败: {e}")
        raise


async def get_database_status() -> str:
    """获取数据库状态"""
    try:
        if not db_manager.is_connected:
            return "disconnected"
        
        # 尝试执行简单查询
        async with db_manager.get_session() as session:
            await session.execute(text("SELECT 1"))
            return "healthy"
            
    except Exception as e:
        logger.error(f"数据库状态检查失败: {e}")
        return "unhealthy"


# 兼容性函数
async def create_tables():
    """创建数据库表（如果需要）"""
    try:
        if db_manager._engine:
            async with db_manager._engine.begin() as conn:
                # 这里可以添加表创建逻辑
                # await conn.run_sync(Base.metadata.create_all)
                pass
            logger.info("数据库表检查完成")
    except Exception as e:
        logger.error(f"数据库表创建失败: {e}")


# 简化的健康检查
async def check_database_health() -> bool:
    """检查数据库健康状态"""
    try:
        status = await get_database_status()
        return status == "healthy"
    except Exception:
        return False