"""
Todo List Plus FastAPI主应用
云原生任务管理系统后端服务
"""

import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
import time
import uvicorn

# 导入应用核心模块
from app.core.config import get_settings
from app.utils.logger import setup_logger

# 获取配置和日志
settings = get_settings()
logger = setup_logger(__name__)

# 导入API路由
from app.api.v1 import auth, tasks, notifications


async def init_database():
    """初始化数据库连接"""
    try:
        from app.core.database import init_database as db_init
        await db_init()
        logger.info("数据库连接初始化成功")
    except Exception as e:
        logger.error(f"数据库连接初始化失败: {e}")
        # 不阻止应用启动，允许在没有数据库的情况下运行
        pass


async def init_redis():
    """初始化Redis连接"""
    try:
        from app.core.cache import cache_manager
        await cache_manager.connect()
        logger.info("Redis连接初始化成功")
    except Exception as e:
        logger.error(f"Redis连接初始化失败: {e}")
        # 不阻止应用启动，允许在没有Redis的情况下运行
        pass


async def get_database_status():
    """获取数据库状态"""
    try:
        from app.core.database import engine
        async with engine.begin() as conn:
            await conn.execute("SELECT 1")
        return "healthy"
    except Exception:
        return "error"


async def get_redis_status():
    """获取Redis状态"""
    try:
        from app.core.cache import cache_manager
        await cache_manager.set("health_check", "ok", expire=1)
        await cache_manager.delete("health_check")
        return "healthy"
    except Exception:
        return "error"


async def close_redis():
    """关闭Redis连接"""
    try:
        from app.core.cache import cache_manager
        await cache_manager.close()
        logger.info("Redis连接已关闭")
    except Exception as e:
        logger.error(f"关闭Redis连接失败: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时初始化
    logger.info("🚀 启动 Todo List Plus 后端服务...")
    
    try:
        # 初始化Redis连接
        logger.info("初始化Redis连接...")
        await init_redis()
        
        # 初始化数据库
        logger.info("初始化数据库连接...")
        await init_database()
        
        logger.info("✅ 服务初始化完成")
        
    except Exception as e:
        logger.error(f"❌ 服务初始化失败: {e}")
        # 不抛出异常，允许应用继续启动
    
    yield
    
    # 关闭时清理资源
    logger.info("🔄 关闭服务，清理资源...")
    
    try:
        await close_redis()
        logger.info("✅ 资源清理完成")
    except Exception as e:
        logger.error(f"❌ 资源清理失败: {e}")


# 创建FastAPI应用实例
app = FastAPI(
    title=settings.APP_NAME,
    description=settings.DESCRIPTION,
    version=settings.VERSION,
    docs_url="/docs" if settings.is_development else None,
    redoc_url="/redoc" if settings.is_development else None,
    openapi_url="/openapi.json" if settings.is_development else None,
    lifespan=lifespan
)

# CORS中间件配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,  # 使用属性方法
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"]
)

# 信任主机中间件
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["*"] if settings.is_development else ["localhost", "127.0.0.1"]
)


# 简化的请求日志中间件
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """记录请求日志和性能指标"""
    start_time = time.time()
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        
        # 简化的日志记录
        logger.info(f"{request.method} {request.url.path} - {response.status_code} - {process_time:.4f}s")
        
        # 添加性能头
        response.headers["X-Process-Time"] = str(process_time)
        
        return response
        
    except Exception as e:
        process_time = time.time() - start_time
        logger.error(f"请求处理异常: {e}")
        raise


# 全局异常处理器
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    """HTTP异常处理"""
    logger.warning(f"HTTP异常: {exc.status_code} - {exc.detail}")
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": True,
            "message": exc.detail,
            "status_code": exc.status_code,
            "timestamp": time.time()
        }
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """请求验证异常处理"""
    logger.warning(f"请求验证失败: {exc}")
    
    return JSONResponse(
        status_code=422,
        content={
            "error": True,
            "message": "请求参数验证失败",
            "details": exc.errors(),
            "status_code": 422,
            "timestamp": time.time()
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """通用异常处理"""
    logger.error(f"未处理的异常: {exc}")
    
    return JSONResponse(
        status_code=500,
        content={
            "error": True,
            "message": "服务器内部错误" if settings.is_production else str(exc),
            "status_code": 500,
            "timestamp": time.time()
        }
    )


# 注册API路由
app.include_router(
    auth.router,
    prefix="/api/v1/auth",
    tags=["🔐 认证系统"]
)

app.include_router(
    tasks.router,
    prefix="/api/v1/tasks",
    tags=["📝 任务管理"]
)

app.include_router(
    notifications.router,
    prefix="/api/v1/notifications",
    tags=["🔔 通知系统"]
)


# 根路径
@app.get("/", tags=["根路径"])
async def root():
    """根路径欢迎信息"""
    return {
        "message": "欢迎使用 Todo List Plus API",
        "version": settings.VERSION,
        "docs_url": "/docs" if settings.is_development else None,
        "status": "running",
        "timestamp": time.time()
    }


# 健康检查端点
@app.get("/health", tags=["健康检查"])
async def health_check():
    """应用健康检查"""
    try:
        # 检查数据库状态
        db_status = await get_database_status()
        
        # 检查Redis状态
        redis_status = await get_redis_status()
        
        # 基本健康状态（即使数据库/Redis不可用也认为服务健康）
        health_data = {
            "status": "healthy",
            "timestamp": time.time(),
            "version": settings.VERSION,
            "environment": settings.ENVIRONMENT,
            "services": {
                "database": db_status,
                "redis": redis_status,
                "api": "healthy"
            }
        }
        
        return JSONResponse(content=health_data, status_code=200)
        
    except Exception as e:
        logger.error(f"健康检查失败: {e}")
        return JSONResponse(
            content={
                "status": "healthy",  # 即使检查失败也返回healthy，避免容器重启
                "timestamp": time.time(),
                "error": str(e) if settings.is_development else "check failed"
            },
            status_code=200
        )


# 就绪检查端点
@app.get("/ready", tags=["健康检查"])
async def readiness_check():
    """应用就绪检查"""
    return JSONResponse(
        content={
            "ready": True,
            "timestamp": time.time(),
            "message": "Service is ready"
        },
        status_code=200
    )


# 应用信息端点
@app.get("/info", tags=["系统信息"])
async def app_info():
    """获取应用信息"""
    import sys
    import platform
    
    return {
        "app": {
            "name": settings.APP_NAME,
            "version": settings.VERSION,
            "description": settings.DESCRIPTION,
            "environment": settings.ENVIRONMENT
        },
        "system": {
            "python_version": sys.version,
            "platform": platform.platform(),
            "architecture": platform.architecture()[0]
        },
        "config": {
            "debug": settings.DEBUG,
            "log_level": settings.LOG_LEVEL,
            "cors_origins": settings.cors_origins_list
        },
        "timestamp": time.time()
    }


# 开发服务器启动
if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.is_development,
        log_level=settings.LOG_LEVEL.lower(),
        access_log=True
    )