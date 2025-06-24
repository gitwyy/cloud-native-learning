import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { Notification, NotificationFilters, NotificationType, PaginatedResponse, PaginationParams } from '@/types'
import { request } from '@/services/api'

export const useNotificationsStore = defineStore('notifications', () => {
  // 状态
  const notifications = ref<Notification[]>([])
  const loading = ref(false)
  const pagination = ref({
    page: 1,
    size: 20,
    total: 0,
    pages: 0
  })
  const filters = ref<NotificationFilters>({
    isRead: undefined,
    type: [],
  })

  // 计算属性
  const unreadCount = computed(() => 
    notifications.value.filter(n => !n.isRead).length
  )

  const filteredNotifications = computed(() => {
    let result = [...notifications.value]

    // 已读状态筛选
    if (filters.value.isRead !== undefined) {
      result = result.filter(n => n.isRead === filters.value.isRead)
    }

    // 类型筛选
    if (filters.value.type && filters.value.type.length > 0) {
      result = result.filter(n => filters.value.type!.includes(n.type))
    }

    // 日期范围筛选
    if (filters.value.dateRange) {
      const { start, end } = filters.value.dateRange
      result = result.filter(n => {
        const notificationDate = new Date(n.createdAt)
        return notificationDate >= new Date(start) && notificationDate <= new Date(end)
      })
    }

    // 按创建时间倒序排列
    result.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())

    return result
  })

  const hasUnreadNotifications = computed(() => unreadCount.value > 0)

  // 获取通知列表
  const fetchNotifications = async (params?: PaginationParams): Promise<void> => {
    try {
      loading.value = true
      
      const queryParams = {
        page: params?.page || pagination.value.page,
        size: params?.size || pagination.value.size,
        ...filters.value
      }

      const response = await request.get<PaginatedResponse<Notification>>('/api/v1/notifications', {
        params: queryParams
      })

      notifications.value = response.items
      pagination.value = {
        page: response.page,
        size: response.size,
        total: response.total,
        pages: response.pages
      }
    } catch (error) {
      console.error('Failed to fetch notifications:', error)
      ElMessage.error('获取通知列表失败')
    } finally {
      loading.value = false
    }
  }

  // 标记单个通知为已读
  const markAsRead = async (notificationId: number): Promise<boolean> => {
    try {
      await request.patch(`/api/v1/notifications/${notificationId}/read`)
      
      // 更新本地状态
      const notification = notifications.value.find(n => n.id === notificationId)
      if (notification) {
        notification.isRead = true
      }
      
      return true
    } catch (error) {
      console.error('Failed to mark notification as read:', error)
      ElMessage.error('标记通知失败')
      return false
    }
  }

  // 标记所有通知为已读
  const markAllAsRead = async (): Promise<boolean> => {
    try {
      await request.post('/api/v1/notifications/mark-all-read')
      
      // 更新本地状态
      notifications.value.forEach(n => {
        n.isRead = true
      })
      
      ElMessage.success('所有通知已标记为已读')
      return true
    } catch (error) {
      console.error('Failed to mark all notifications as read:', error)
      ElMessage.error('批量标记失败')
      return false
    }
  }

  // 删除单个通知
  const deleteNotification = async (notificationId: number): Promise<boolean> => {
    try {
      await request.delete(`/api/v1/notifications/${notificationId}`)
      
      // 从本地状态移除
      const index = notifications.value.findIndex(n => n.id === notificationId)
      if (index !== -1) {
        notifications.value.splice(index, 1)
      }
      
      return true
    } catch (error) {
      console.error('Failed to delete notification:', error)
      ElMessage.error('删除通知失败')
      return false
    }
  }

  // 清空所有通知
  const clearAllNotifications = async (): Promise<boolean> => {
    try {
      await request.delete('/api/v1/notifications/clear')
      
      // 清空本地状态
      notifications.value = []
      pagination.value.total = 0
      
      ElMessage.success('所有通知已清空')
      return true
    } catch (error) {
      console.error('Failed to clear all notifications:', error)
      ElMessage.error('清空通知失败')
      return false
    }
  }

  // 获取未读通知数量
  const fetchUnreadCount = async (): Promise<number> => {
    try {
      const response = await request.get<{ count: number }>('/api/v1/notifications/unread-count')
      return response.count
    } catch (error) {
      console.error('Failed to fetch unread count:', error)
      return 0
    }
  }

  // 添加新通知（用于WebSocket实时推送）
  const addNotification = (notification: Notification): void => {
    notifications.value.unshift(notification)
    
    // 显示通知消息
    const notificationTypeMessages = {
      [NotificationType.TASK_ASSIGNED]: '您有新的任务分配',
      [NotificationType.TASK_DUE]: '任务即将到期',
      [NotificationType.TASK_OVERDUE]: '任务已逾期',
      [NotificationType.TASK_COMPLETED]: '任务已完成',
      [NotificationType.TASK_COMMENTED]: '任务有新评论',
      [NotificationType.SYSTEM_UPDATE]: '系统更新通知',
    }

    ElMessage.info({
      message: notificationTypeMessages[notification.type] || notification.title,
      duration: 3000,
    })
  }

  // 设置筛选条件
  const setFilters = (newFilters: Partial<NotificationFilters>): void => {
    filters.value = { ...filters.value, ...newFilters }
  }

  // 重置筛选条件
  const resetFilters = (): void => {
    filters.value = {
      isRead: undefined,
      type: [],
    }
  }

  // 获取最近的通知（用于显示在界面上）
  const getRecentNotifications = (limit: number = 5): Notification[] => {
    return notifications.value
      .slice()
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, limit)
  }

  // 按类型获取通知
  const getNotificationsByType = (type: NotificationType): Notification[] => {
    return notifications.value.filter(n => n.type === type)
  }

  // 处理通知点击（标记为已读并可能跳转）
  const handleNotificationClick = async (notification: Notification): Promise<void> => {
    if (!notification.isRead) {
      await markAsRead(notification.id)
    }

    // 如果通知关联任务，可以跳转到任务详情
    if (notification.relatedTaskId) {
      // 这里可以使用路由跳转到任务详情页
      console.log(`Navigate to task ${notification.relatedTaskId}`)
    }
  }

  return {
    // 状态
    notifications,
    loading,
    pagination,
    filters,
    
    // 计算属性
    unreadCount,
    filteredNotifications,
    hasUnreadNotifications,
    
    // 方法
    fetchNotifications,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    clearAllNotifications,
    fetchUnreadCount,
    addNotification,
    setFilters,
    resetFilters,
    getRecentNotifications,
    getNotificationsByType,
    handleNotificationClick,
  }
})