"""
日志记录工具
提供结构化日志记录功能
"""

import logging
import sys
from datetime import datetime
from typing import Any, Dict, Optional
from pathlib import Path
import json

from app.core.config import get_settings

settings = get_settings()


class JSONFormatter(logging.Formatter):
    """JSON格式化器"""
    
    def format(self, record: logging.LogRecord) -> str:
        """格式化日志记录为JSON"""
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # 添加额外的上下文信息
        if hasattr(record, 'user_id'):
            log_data['user_id'] = record.user_id
        if hasattr(record, 'request_id'):
            log_data['request_id'] = record.request_id
        if hasattr(record, 'extra'):
            log_data.update(record.extra)
            
        return json.dumps(log_data, ensure_ascii=False)


def setup_logger(name: str) -> logging.Logger:
    """设置日志记录器"""
    
    logger = logging.getLogger(name)
    
    # 避免重复添加处理器
    if logger.handlers:
        return logger
    
    logger.setLevel(getattr(logging, settings.LOG_LEVEL.upper()))
    
    # 控制台处理器
    console_handler = logging.StreamHandler(sys.stdout)
    
    if settings.is_development:
        # 开发环境使用简单格式
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
    else:
        # 生产环境使用JSON格式
        formatter = JSONFormatter()
    
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # 文件处理器（如果指定了日志目录）
    if hasattr(settings, 'LOG_DIR') and settings.LOG_DIR:
        log_dir = Path(settings.LOG_DIR)
        log_dir.mkdir(parents=True, exist_ok=True)
        
        file_handler = logging.FileHandler(
            log_dir / f"{name.replace('.', '_')}.log"
        )
        file_handler.setFormatter(JSONFormatter())
        logger.addHandler(file_handler)
    
    return logger


class RequestLogger:
    """请求日志记录器"""
    
    def __init__(self):
        self.logger = setup_logger("request")
    
    async def log_request(self, request, response, process_time: float):
        """记录请求日志"""
        try:
            log_data = {
                "method": request.method,
                "url": str(request.url),
                "status_code": response.status_code,
                "process_time": round(process_time, 4),
                "client_ip": getattr(request.client, 'host', 'unknown'),
                "user_agent": request.headers.get("user-agent", ""),
                "content_length": response.headers.get("content-length", 0)
            }
            
            # 记录请求ID（如果存在）
            if hasattr(request.state, 'request_id'):
                log_data["request_id"] = request.state.request_id
            
            # 记录用户ID（如果已认证）
            if hasattr(request.state, 'user_id'):
                log_data["user_id"] = request.state.user_id
            
            self.logger.info("HTTP Request", extra=log_data)
            
        except Exception as e:
            self.logger.error(f"Failed to log request: {e}")


# 创建全局请求日志记录器实例
request_logger = RequestLogger()


# 兼容性函数
def get_logger(name: str) -> logging.Logger:
    """获取日志记录器（兼容性函数）"""
    return setup_logger(name)


# 便捷的日志记录函数
def log_info(message: str, **kwargs):
    """记录信息日志"""
    logger = setup_logger("app")
    logger.info(message, extra=kwargs)


def log_error(message: str, **kwargs):
    """记录错误日志"""
    logger = setup_logger("app")
    logger.error(message, extra=kwargs)


def log_warning(message: str, **kwargs):
    """记录警告日志"""
    logger = setup_logger("app")
    logger.warning(message, extra=kwargs)


def log_debug(message: str, **kwargs):
    """记录调试日志"""
    logger = setup_logger("app")
    logger.debug(message, extra=kwargs)