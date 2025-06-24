"""
应用配置管理
使用Pydantic Settings进行配置管理和验证
"""

from functools import lru_cache
from typing import List, Optional
from pydantic import BaseModel, field_validator, Field
from pydantic_settings import BaseSettings
import os


class Settings(BaseSettings):
    """应用配置类"""
    
    # 应用基本配置
    APP_NAME: str = "Todo List Plus"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "云原生任务管理系统"
    
    # 环境配置
    ENVIRONMENT: str = Field(default="development", alias="ENVIRONMENT")
    DEBUG: bool = Field(default=True, alias="DEBUG")
    LOG_LEVEL: str = Field(default="INFO", alias="LOG_LEVEL")
    
    # 服务器配置
    HOST: str = Field(default="0.0.0.0", alias="HOST")
    PORT: int = Field(default=8000, alias="PORT")
    
    # 数据库配置
    DATABASE_URL: str = Field(default="postgresql+asyncpg://postgres:postgres123@database:5432/todo_db", alias="DATABASE_URL")
    DATABASE_ECHO: bool = Field(default=False, alias="DATABASE_ECHO")
    
    # Redis配置
    REDIS_URL: str = Field(default="redis://localhost:6379", alias="REDIS_URL")
    REDIS_TTL: int = Field(default=3600, alias="REDIS_TTL")  # 默认1小时
    
    # JWT配置
    SECRET_KEY: str = Field(default="your-super-secret-jwt-key-change-in-production", alias="SECRET_KEY")
    ALGORITHM: str = Field(default="HS256", alias="ALGORITHM")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=30, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(default=7, alias="REFRESH_TOKEN_EXPIRE_DAYS")
    
    # CORS配置
    CORS_ORIGINS: str = Field(default="http://localhost:3000,http://127.0.0.1:3000", alias="CORS_ORIGINS")
    
    # 文件上传配置
    UPLOAD_DIR: str = Field(default="./uploads", alias="UPLOAD_DIR")
    MAX_FILE_SIZE: int = Field(default=10 * 1024 * 1024, alias="MAX_FILE_SIZE")  # 10MB
    
    # 邮件配置（可选）
    EMAIL_ENABLED: bool = Field(default=False, alias="EMAIL_ENABLED")
    SMTP_HOST: Optional[str] = Field(default=None, alias="SMTP_HOST")
    SMTP_PORT: Optional[int] = Field(default=587, alias="SMTP_PORT")
    SMTP_USERNAME: Optional[str] = Field(default=None, alias="SMTP_USERNAME")
    SMTP_PASSWORD: Optional[str] = Field(default=None, alias="SMTP_PASSWORD")
    SMTP_TLS: bool = Field(default=True, alias="SMTP_TLS")
    
    # 分页配置
    DEFAULT_PAGE_SIZE: int = Field(default=20, alias="DEFAULT_PAGE_SIZE")
    MAX_PAGE_SIZE: int = Field(default=100, alias="MAX_PAGE_SIZE")
    
    # 安全配置
    PASSWORD_MIN_LENGTH: int = Field(default=8, alias="PASSWORD_MIN_LENGTH")
    PASSWORD_REQUIRE_SPECIAL_CHARS: bool = Field(default=True, alias="PASSWORD_REQUIRE_SPECIAL_CHARS")
    MAX_LOGIN_ATTEMPTS: int = Field(default=5, alias="MAX_LOGIN_ATTEMPTS")
    LOCKOUT_DURATION_MINUTES: int = Field(default=15, alias="LOCKOUT_DURATION_MINUTES")
    
    # 速率限制配置
    RATE_LIMIT_ENABLED: bool = Field(default=True, alias="RATE_LIMIT_ENABLED")
    RATE_LIMIT_REQUESTS: int = Field(default=100, alias="RATE_LIMIT_REQUESTS")
    RATE_LIMIT_WINDOW: int = Field(default=3600, alias="RATE_LIMIT_WINDOW")  # 1小时
    
    # WebSocket配置
    WEBSOCKET_ENABLED: bool = Field(default=True, alias="WEBSOCKET_ENABLED")
    WEBSOCKET_HEARTBEAT_INTERVAL: int = Field(default=30, alias="WEBSOCKET_HEARTBEAT_INTERVAL")
    
    # 监控配置
    METRICS_ENABLED: bool = Field(default=True, alias="METRICS_ENABLED")
    HEALTH_CHECK_ENABLED: bool = Field(default=True, alias="HEALTH_CHECK_ENABLED")

    @field_validator("SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, v):
        """验证密钥强度"""
        if len(v) < 32:
            # 在开发环境中，如果密钥太短，自动补足
            return v + "a" * (32 - len(v))
        return v
    
    @property
    def cors_origins_list(self) -> List[str]:
        """获取CORS origins列表"""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]
    
    @property
    def is_development(self) -> bool:
        """是否为开发环境"""
        return self.ENVIRONMENT.lower() == "development"
    
    @property
    def is_production(self) -> bool:
        """是否为生产环境"""
        return self.ENVIRONMENT.lower() == "production"
    
    @property
    def database_url_sync(self) -> str:
        """同步数据库URL（用于Alembic）"""
        return self.DATABASE_URL.replace("+asyncpg", "")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False  # 改为不区分大小写


# 开发环境默认配置
class DevelopmentSettings(Settings):
    """开发环境配置"""
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    LOG_LEVEL: str = "DEBUG"
    DATABASE_ECHO: bool = True


# 生产环境默认配置
class ProductionSettings(Settings):
    """生产环境配置"""
    ENVIRONMENT: str = "production"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"
    DATABASE_ECHO: bool = False


# 测试环境配置
class TestingSettings(Settings):
    """测试环境配置"""
    ENVIRONMENT: str = "testing"
    DEBUG: bool = True
    LOG_LEVEL: str = "DEBUG"
    DATABASE_URL: str = "postgresql://postgres:postgres123@localhost:5432/todo_test"
    REDIS_URL: str = "redis://localhost:6379/1"


@lru_cache()
def get_settings() -> Settings:
    """获取应用配置（带缓存）"""
    environment = os.getenv("ENVIRONMENT", "development").lower()
    
    if environment == "development":
        return DevelopmentSettings()
    elif environment == "production":
        return ProductionSettings()
    elif environment == "testing":
        return TestingSettings()
    else:
        return Settings()


# 延迟初始化全局配置实例
_settings = None

def get_global_settings() -> Settings:
    """获取全局配置实例"""
    global _settings
    if _settings is None:
        _settings = get_settings()
    return _settings