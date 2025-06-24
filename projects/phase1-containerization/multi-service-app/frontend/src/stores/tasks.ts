import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
import {
  Task,
  CreateTaskRequest,
  UpdateTaskRequest,
  TaskFilters,
  TaskStats,
  PaginatedResponse,
  PaginationParams,
  TaskStatus,
  TaskPriority
} from '@/types'
import { request } from '@/services/api'

export const useTasksStore = defineStore('tasks', () => {
  // 状态
  const tasks = ref<Task[]>([])
  const currentTask = ref<Task | null>(null)
  const loading = ref(false)
  const pagination = ref({
    page: 1,
    size: 20,
    total: 0,
    pages: 0
  })
  const filters = ref<TaskFilters>({
    status: [],
    priority: [],
    search: '',
  })
  const sortBy = ref('createdAt')
  const sortOrder = ref<'asc' | 'desc'>('desc')

  // 计算属性
  const filteredTasks = computed(() => {
    let result = [...tasks.value]

    // 状态筛选
    if (filters.value.status && filters.value.status.length > 0) {
      result = result.filter(task => filters.value.status!.includes(task.status))
    }

    // 优先级筛选
    if (filters.value.priority && filters.value.priority.length > 0) {
      result = result.filter(task => filters.value.priority!.includes(task.priority))
    }

    // 搜索筛选
    if (filters.value.search) {
      const searchTerm = filters.value.search.toLowerCase()
      result = result.filter(task => 
        task.title.toLowerCase().includes(searchTerm) ||
        (task.description && task.description.toLowerCase().includes(searchTerm))
      )
    }

    // 分类筛选
    if (filters.value.category) {
      result = result.filter(task => task.category === filters.value.category)
    }

    // 负责人筛选
    if (filters.value.assigneeId) {
      result = result.filter(task => task.assigneeId === filters.value.assigneeId)
    }

    // 日期范围筛选
    if (filters.value.dateRange) {
      const { start, end } = filters.value.dateRange
      result = result.filter(task => {
        const taskDate = new Date(task.createdAt)
        return taskDate >= new Date(start) && taskDate <= new Date(end)
      })
    }

    // 排序
    result.sort((a, b) => {
      const aValue = a[sortBy.value as keyof Task]
      const bValue = b[sortBy.value as keyof Task]
      
      if (aValue == null && bValue == null) return 0
      if (aValue == null) return 1
      if (bValue == null) return -1
      
      if (sortOrder.value === 'asc') {
        return aValue < bValue ? -1 : aValue > bValue ? 1 : 0
      } else {
        return aValue > bValue ? -1 : aValue < bValue ? 1 : 0
      }
    })

    return result
  })

  const taskStats = computed((): TaskStats => {
    const total = tasks.value.length
    const pending = tasks.value.filter(t => t.status === TaskStatus.PENDING).length
    const inProgress = tasks.value.filter(t => t.status === TaskStatus.IN_PROGRESS).length
    const completed = tasks.value.filter(t => t.status === TaskStatus.COMPLETED).length
    
    // 计算逾期任务
    const now = new Date()
    const overdue = tasks.value.filter(t => 
      t.dueDate && 
      new Date(t.dueDate) < now && 
      t.status !== TaskStatus.COMPLETED
    ).length

    const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0

    return {
      total,
      pending,
      inProgress,
      completed,
      overdue,
      completionRate
    }
  })

  // 获取任务列表
  const fetchTasks = async (params?: PaginationParams): Promise<void> => {
    try {
      loading.value = true
      
      const queryParams = {
        page: params?.page || pagination.value.page,
        size: params?.size || pagination.value.size,
        sort_by: params?.sortBy || sortBy.value,
        sort_order: params?.sortOrder || sortOrder.value,
        ...filters.value
      }

      const response = await request.get<PaginatedResponse<Task>>('/api/v1/tasks', {
        params: queryParams
      })

      tasks.value = response.items
      pagination.value = {
        page: response.page,
        size: response.size,
        total: response.total,
        pages: response.pages
      }
    } catch (error) {
      console.error('Failed to fetch tasks:', error)
      ElMessage.error('获取任务列表失败')
    } finally {
      loading.value = false
    }
  }

  // 获取单个任务
  const fetchTask = async (taskId: number): Promise<Task | null> => {
    try {
      loading.value = true
      const task = await request.get<Task>(`/api/v1/tasks/${taskId}`)
      currentTask.value = task
      return task
    } catch (error) {
      console.error('Failed to fetch task:', error)
      ElMessage.error('获取任务详情失败')
      return null
    } finally {
      loading.value = false
    }
  }

  // 创建任务
  const createTask = async (taskData: CreateTaskRequest): Promise<Task | null> => {
    try {
      loading.value = true
      const newTask = await request.post<Task>('/api/v1/tasks', taskData)
      
      tasks.value.unshift(newTask)
      ElMessage.success('任务创建成功')
      return newTask
    } catch (error) {
      console.error('Failed to create task:', error)
      return null
    } finally {
      loading.value = false
    }
  }

  // 更新任务
  const updateTask = async (taskId: number, updates: UpdateTaskRequest): Promise<Task | null> => {
    try {
      loading.value = true
      const updatedTask = await request.patch<Task>(`/api/v1/tasks/${taskId}`, updates)
      
      // 更新本地状态
      const index = tasks.value.findIndex(t => t.id === taskId)
      if (index !== -1) {
        tasks.value[index] = updatedTask
      }
      
      if (currentTask.value?.id === taskId) {
        currentTask.value = updatedTask
      }
      
      ElMessage.success('任务更新成功')
      return updatedTask
    } catch (error) {
      console.error('Failed to update task:', error)
      return null
    } finally {
      loading.value = false
    }
  }

  // 删除任务
  const deleteTask = async (taskId: number): Promise<boolean> => {
    try {
      loading.value = true
      await request.delete(`/api/v1/tasks/${taskId}`)
      
      // 从本地状态移除
      const index = tasks.value.findIndex(t => t.id === taskId)
      if (index !== -1) {
        tasks.value.splice(index, 1)
      }
      
      if (currentTask.value?.id === taskId) {
        currentTask.value = null
      }
      
      ElMessage.success('任务删除成功')
      return true
    } catch (error) {
      console.error('Failed to delete task:', error)
      return false
    } finally {
      loading.value = false
    }
  }

  // 完成任务
  const completeTask = async (taskId: number): Promise<boolean> => {
    return await updateTask(taskId, { 
      status: TaskStatus.COMPLETED,
      progress: 100
    }) !== null
  }

  // 归档任务
  const archiveTask = async (taskId: number): Promise<boolean> => {
    return await updateTask(taskId, { isArchived: true }) !== null
  }

  // 恢复任务
  const restoreTask = async (taskId: number): Promise<boolean> => {
    return await updateTask(taskId, { isArchived: false }) !== null
  }

  // 复制任务
  const duplicateTask = async (taskId: number): Promise<Task | null> => {
    const originalTask = tasks.value.find(t => t.id === taskId)
    if (!originalTask) return null

    const duplicateData: CreateTaskRequest = {
      title: `${originalTask.title} (副本)`,
      description: originalTask.description,
      priority: originalTask.priority,
      dueDate: originalTask.dueDate,
      assigneeId: originalTask.assigneeId,
      category: originalTask.category,
      tags: originalTask.tags ? [...originalTask.tags] : undefined
    }

    return await createTask(duplicateData)
  }

  // 设置筛选条件
  const setFilters = (newFilters: Partial<TaskFilters>): void => {
    filters.value = { ...filters.value, ...newFilters }
  }

  // 设置排序
  const setSorting = (field: string, order: 'asc' | 'desc'): void => {
    sortBy.value = field
    sortOrder.value = order
  }

  // 重置筛选条件
  const resetFilters = (): void => {
    filters.value = {
      status: [],
      priority: [],
      search: '',
    }
  }

  // 清空当前任务
  const clearCurrentTask = (): void => {
    currentTask.value = null
  }

  return {
    // 状态
    tasks,
    currentTask,
    loading,
    pagination,
    filters,
    sortBy,
    sortOrder,
    
    // 计算属性
    filteredTasks,
    taskStats,
    
    // 方法
    fetchTasks,
    fetchTask,
    createTask,
    updateTask,
    deleteTask,
    completeTask,
    archiveTask,
    restoreTask,
    duplicateTask,
    setFilters,
    setSorting,
    resetFilters,
    clearCurrentTask,
  }
})