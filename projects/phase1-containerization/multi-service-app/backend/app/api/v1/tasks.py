"""
任务管理API路由
处理任务的CRUD操作和状态管理
"""

from datetime import datetime
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, rate_limit_standard, validate_pagination
from app.services.task_service import task_service
from app.schemas.task import (
    TaskCreate, TaskUpdate, Task, TaskStats, TaskListParams,
    TaskBatchUpdate, TaskBatchDelete, TaskStatus, TaskPriority
)
from app.utils.logger import setup_logger

# 日志
logger = setup_logger(__name__)

# 创建路由器
router = APIRouter()


@router.get("/", response_model=Dict[str, Any], tags=["任务管理"])
async def get_tasks(
    status: Optional[TaskStatus] = Query(None, description="按状态筛选任务"),
    priority: Optional[TaskPriority] = Query(None, description="按优先级筛选任务"),
    category: Optional[str] = Query(None, description="按分类筛选任务"),
    is_starred: Optional[bool] = Query(None, description="是否标星"),
    is_archived: Optional[bool] = Query(None, description="是否归档"),
    is_overdue: Optional[bool] = Query(None, description="是否过期"),
    search: Optional[str] = Query(None, description="搜索关键词"),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    sort_by: Optional[str] = Query("created_at", description="排序字段"),
    sort_order: Optional[str] = Query("desc", pattern="^(asc|desc)$", description="排序方向"),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(rate_limit_standard)
):
    """获取任务列表"""
    try:
        # 构建查询参数
        params = TaskListParams(
            status=status,
            priority=priority,
            category=category,
            is_starred=is_starred,
            is_archived=is_archived,
            is_overdue=is_overdue,
            search=search,
            page=page,
            page_size=page_size,
            sort_by=sort_by,
            sort_order=sort_order
        )
        
        result = await task_service.get_user_tasks(current_user, params, db)
        
        # 转换任务为字典格式
        tasks_data = [task.to_dict(include_owner=False) for task in result["tasks"]]
        result["tasks"] = tasks_data
        
        logger.info(f"获取任务列表: {current_user.username}, 数量: {result['total']}")
        
        return result
        
    except Exception as e:
        logger.error(f"获取任务列表失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取任务列表失败"
        )


@router.post("/", response_model=Dict[str, Any], tags=["任务管理"])
async def create_task(
    task_data: TaskCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(rate_limit_standard)
):
    """创建新任务"""
    try:
        task = await task_service.create_task(task_data, current_user, db)
        
        logger.info(f"创建任务成功: {current_user.username}, 任务ID: {task.id}")
        
        return task.to_dict(include_owner=False)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"创建任务失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="创建任务失败"
        )


@router.get("/{task_id}", response_model=Dict[str, Any], tags=["任务管理"])
async def get_task(
    task_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取任务详情"""
    try:
        task = await task_service.get_task_by_id(task_id, current_user, db)
        
        logger.info(f"获取任务详情: {current_user.username}, 任务ID: {task_id}")
        
        return task.to_dict(include_owner=True)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务详情失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取任务详情失败"
        )


@router.put("/{task_id}", response_model=Dict[str, Any], tags=["任务管理"])
async def update_task(
    task_id: int,
    task_update: TaskUpdate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """更新任务"""
    try:
        task = await task_service.update_task(task_id, task_update, current_user, db)
        
        logger.info(f"更新任务成功: {current_user.username}, 任务ID: {task_id}")
        
        return task.to_dict(include_owner=False)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新任务失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="更新任务失败"
        )


@router.delete("/{task_id}", tags=["任务管理"])
async def delete_task(
    task_id: int,
    permanent: bool = Query(False, description="是否永久删除"),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """删除任务"""
    try:
        success = await task_service.delete_task(task_id, current_user, db, permanent)
        
        if success:
            action = "永久删除" if permanent else "删除"
            logger.info(f"{action}任务成功: {current_user.username}, 任务ID: {task_id}")
            return {"message": f"任务已{action}"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="删除任务失败"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"删除任务失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="删除任务失败"
        )


@router.get("/stats/summary", response_model=TaskStats, tags=["任务管理"])
async def get_task_stats(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取任务统计信息"""
    try:
        stats = await task_service.get_task_stats(current_user, db)
        
        logger.info(f"获取任务统计: {current_user.username}")
        
        return stats
        
    except Exception as e:
        logger.error(f"获取任务统计失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取任务统计失败"
        )


@router.post("/batch/update", response_model=Dict[str, Any], tags=["任务管理"])
async def batch_update_tasks(
    batch_data: TaskBatchUpdate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """批量更新任务"""
    try:
        result = await task_service.batch_update_tasks(batch_data, current_user, db)
        
        logger.info(f"批量更新任务: {current_user.username}, 更新数量: {result['updated_count']}")
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量更新任务失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="批量更新任务失败"
        )


@router.post("/batch/delete", response_model=Dict[str, Any], tags=["任务管理"])
async def batch_delete_tasks(
    batch_data: TaskBatchDelete,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """批量删除任务"""
    try:
        result = await task_service.batch_delete_tasks(batch_data, current_user, db)
        
        logger.info(f"批量删除任务: {current_user.username}, 删除数量: {result['deleted_count']}")
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量删除任务失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="批量删除任务失败"
        )


# 健康检查
@router.get("/health", tags=["健康检查"])
async def tasks_health():
    """任务服务健康检查"""
    return {
        "service": "tasks",
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "version": "1.0.0"
    }