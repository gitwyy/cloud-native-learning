// 用户相关类型
export interface User {
  id: number
  username: string
  email: string
  firstName?: string
  lastName?: string
  avatar?: string
  phone?: string
  bio?: string
  isActive: boolean
  createdAt: string
  updatedAt: string
}

export interface LoginRequest {
  username: string
  password: string
}

export interface RegisterRequest {
  username: string
  email: string
  password: string
  firstName?: string
  lastName?: string
}

export interface AuthResponse {
  access_token: string
  token_type: string
  user: User
}

// 任务相关类型
export enum TaskStatus {
  PENDING = 'pending',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled'
}

export enum TaskPriority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  URGENT = 'urgent'
}

export interface Task {
  id: number
  title: string
  description?: string
  status: TaskStatus
  priority: TaskPriority
  dueDate?: string
  createdAt: string
  updatedAt: string
  userId: number
  assigneeId?: number
  category?: string
  tags?: string[]
  progress?: number
  isArchived: boolean
}

export interface CreateTaskRequest {
  title: string
  description?: string
  priority: TaskPriority
  dueDate?: string
  assigneeId?: number
  category?: string
  tags?: string[]
}

export interface UpdateTaskRequest extends Partial<CreateTaskRequest> {
  status?: TaskStatus
  progress?: number
  isArchived?: boolean
}

export interface TaskFilters {
  status?: TaskStatus[]
  priority?: TaskPriority[]
  assigneeId?: number
  category?: string
  tags?: string[]
  dateRange?: {
    start: string
    end: string
  }
  search?: string
}

export interface TaskStats {
  total: number
  pending: number
  inProgress: number
  completed: number
  overdue: number
  completionRate: number
}

// 通知相关类型
export enum NotificationType {
  TASK_ASSIGNED = 'task_assigned',
  TASK_DUE = 'task_due',
  TASK_OVERDUE = 'task_overdue',
  TASK_COMPLETED = 'task_completed',
  TASK_COMMENTED = 'task_commented',
  SYSTEM_UPDATE = 'system_update'
}

export interface Notification {
  id: number
  type: NotificationType
  title: string
  message: string
  isRead: boolean
  createdAt: string
  userId: number
  relatedTaskId?: number
  data?: Record<string, any>
}

export interface NotificationFilters {
  isRead?: boolean
  type?: NotificationType[]
  dateRange?: {
    start: string
    end: string
  }
}

// API 响应类型
export interface ApiResponse<T = any> {
  data: T
  message: string
  success: boolean
}

export interface PaginatedResponse<T> {
  items: T[]
  total: number
  page: number
  size: number
  pages: number
}

export interface ApiError {
  message: string
  detail?: string
  errors?: Record<string, string[]>
}

// 应用状态类型
export interface AppState {
  theme: 'light' | 'dark' | 'auto'
  language: 'zh-CN' | 'en-US'
  sidebarCollapsed: boolean
  loading: boolean
}

// 表单验证类型
export interface ValidationRule {
  required?: boolean
  min?: number
  max?: number
  pattern?: RegExp
  validator?: (value: any) => boolean | string
  message?: string
}

export interface FormRules {
  [key: string]: ValidationRule[]
}

// 路由元信息类型
export interface RouteMeta {
  title?: string
  icon?: string
  requiresAuth?: boolean
  roles?: string[]
  keepAlive?: boolean
  hidden?: boolean
}

// 菜单项类型
export interface MenuItem {
  id: string
  title: string
  icon?: string
  path?: string
  children?: MenuItem[]
  meta?: RouteMeta
}

// 图表数据类型
export interface ChartData {
  labels: string[]
  datasets: {
    label: string
    data: number[]
    backgroundColor?: string[]
    borderColor?: string[]
    borderWidth?: number
  }[]
}

// WebSocket 消息类型
export interface WebSocketMessage {
  type: string
  data: any
  timestamp: string
}

// 分页参数类型
export interface PaginationParams {
  page?: number
  size?: number
  sortBy?: string
  sortOrder?: 'asc' | 'desc'
}

// 文件上传类型
export interface UploadFile {
  id: string
  name: string
  size: number
  type: string
  url?: string
  status: 'pending' | 'uploading' | 'success' | 'error'
  progress?: number
}