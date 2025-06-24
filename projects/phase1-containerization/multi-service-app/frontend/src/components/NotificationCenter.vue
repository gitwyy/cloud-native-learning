<template>
  <div class="notification-center">
    <!-- 操作栏 -->
    <div class="notification-actions">
      <el-button 
        type="primary" 
        size="small"
        :disabled="!notificationsStore.hasUnreadNotifications"
        @click="markAllAsRead"
      >
        {{ $t('notification.markAllAsRead') }}
      </el-button>
      <el-button 
        type="danger" 
        size="small"
        @click="clearAll"
      >
        {{ $t('notification.clear') }}
      </el-button>
    </div>

    <!-- 筛选器 -->
    <div class="notification-filters">
      <el-select
        v-model="selectedType"
        placeholder="筛选类型"
        clearable
        size="small"
        @change="handleFilterChange"
      >
        <el-option label="全部" value="" />
        <el-option label="任务分配" :value="NotificationType.TASK_ASSIGNED" />
        <el-option label="任务到期" :value="NotificationType.TASK_DUE" />
        <el-option label="任务逾期" :value="NotificationType.TASK_OVERDUE" />
        <el-option label="任务完成" :value="NotificationType.TASK_COMPLETED" />
        <el-option label="任务评论" :value="NotificationType.TASK_COMMENTED" />
        <el-option label="系统更新" :value="NotificationType.SYSTEM_UPDATE" />
      </el-select>

      <el-select
        v-model="selectedReadStatus"
        placeholder="筛选状态"
        clearable
        size="small"
        @change="handleFilterChange"
      >
        <el-option label="全部" value="" />
        <el-option label="未读" :value="false" />
        <el-option label="已读" :value="true" />
      </el-select>
    </div>

    <!-- 通知列表 -->
    <div class="notification-list" v-loading="notificationsStore.loading">
      <el-empty 
        v-if="filteredNotifications.length === 0"
        :description="$t('notification.noNotifications')"
        :image-size="80"
      />
      
      <div v-else>
        <div
          v-for="notification in filteredNotifications"
          :key="notification.id"
          class="notification-item"
          :class="{ 'is-unread': !notification.isRead }"
          @click="handleNotificationClick(notification)"
        >
          <div class="notification-icon">
            <el-icon :color="getNotificationColor(notification.type)">
              <component :is="getNotificationIcon(notification.type)" />
            </el-icon>
          </div>
          
          <div class="notification-content">
            <div class="notification-title">
              {{ notification.title }}
            </div>
            <div class="notification-message">
              {{ notification.message }}
            </div>
            <div class="notification-time">
              {{ formatTime(notification.createdAt) }}
            </div>
          </div>
          
          <div class="notification-actions">
            <el-button
              v-if="!notification.isRead"
              type="text"
              size="small"
              @click.stop="markAsRead(notification.id)"
            >
              <el-icon><Check /></el-icon>
            </el-button>
            
            <el-button
              type="text"
              size="small"
              @click.stop="deleteNotification(notification.id)"
            >
              <el-icon><Delete /></el-icon>
            </el-button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="notificationsStore.pagination.pages > 1" class="notification-pagination">
      <el-pagination
        v-model:current-page="currentPage"
        :page-size="notificationsStore.pagination.size"
        :total="notificationsStore.pagination.total"
        layout="prev, pager, next"
        small
        @current-change="handlePageChange"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import 'dayjs/locale/zh-cn'
import {
  Check, Delete, Document, Clock, Warning,
  CircleCheck, ChatRound, Bell
} from '@element-plus/icons-vue'
import { ElMessageBox } from 'element-plus'
import { useNotificationsStore } from '@/stores/notifications'
import { NotificationType, type Notification } from '@/types'

// 配置dayjs
dayjs.extend(relativeTime)
dayjs.locale('zh-cn')

const router = useRouter()
const { t } = useI18n()
const notificationsStore = useNotificationsStore()

// 响应式数据
const selectedType = ref('')
const selectedReadStatus = ref('')
const currentPage = ref(1)

// 计算属性
const filteredNotifications = computed(() => {
  return notificationsStore.filteredNotifications
})

// 方法
const handleFilterChange = () => {
  const filters: any = {}
  
  if (selectedType.value) {
    filters.type = [selectedType.value]
  }
  
  if (selectedReadStatus.value !== '') {
    filters.isRead = selectedReadStatus.value
  }
  
  notificationsStore.setFilters(filters)
  notificationsStore.fetchNotifications()
}

const handlePageChange = (page: number) => {
  currentPage.value = page
  notificationsStore.fetchNotifications({ page })
}

const markAsRead = async (notificationId: number) => {
  await notificationsStore.markAsRead(notificationId)
}

const markAllAsRead = async () => {
  await notificationsStore.markAllAsRead()
}

const deleteNotification = async (notificationId: number) => {
  try {
    await ElMessageBox.confirm(
      '确定要删除此通知吗？',
      '删除确认',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )
    
    await notificationsStore.deleteNotification(notificationId)
  } catch {
    // 用户取消删除
  }
}

const clearAll = async () => {
  try {
    await ElMessageBox.confirm(
      '确定要清空所有通知吗？此操作不可撤销。',
      '清空确认',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )
    
    await notificationsStore.clearAllNotifications()
  } catch {
    // 用户取消清空
  }
}

const handleNotificationClick = async (notification: Notification) => {
  await notificationsStore.handleNotificationClick(notification)
  
  // 如果有关联任务，跳转到任务详情
  if (notification.relatedTaskId) {
    router.push(`/tasks/${notification.relatedTaskId}`)
  }
}

const getNotificationIcon = (type: NotificationType) => {
  const iconMap = {
    [NotificationType.TASK_ASSIGNED]: Document,
    [NotificationType.TASK_DUE]: Clock,
    [NotificationType.TASK_OVERDUE]: Warning,
    [NotificationType.TASK_COMPLETED]: CircleCheck,
    [NotificationType.TASK_COMMENTED]: ChatRound,
    [NotificationType.SYSTEM_UPDATE]: Bell,
  }
  
  return iconMap[type] || Bell
}

const getNotificationColor = (type: NotificationType) => {
  const colorMap = {
    [NotificationType.TASK_ASSIGNED]: '#409eff',
    [NotificationType.TASK_DUE]: '#e6a23c',
    [NotificationType.TASK_OVERDUE]: '#f56c6c',
    [NotificationType.TASK_COMPLETED]: '#67c23a',
    [NotificationType.TASK_COMMENTED]: '#909399',
    [NotificationType.SYSTEM_UPDATE]: '#409eff',
  }
  
  return colorMap[type] || '#909399'
}

const formatTime = (time: string) => {
  return dayjs(time).fromNow()
}

// 生命周期
onMounted(() => {
  notificationsStore.fetchNotifications()
})

// 监听筛选条件变化
watch([selectedType, selectedReadStatus], handleFilterChange)
</script>

<style lang="scss" scoped>
.notification-center {
  height: 100%;
  display: flex;
  flex-direction: column;
  
  .notification-actions {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--border-light);
  }
  
  .notification-filters {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
    
    .el-select {
      flex: 1;
    }
  }
  
  .notification-list {
    flex: 1;
    overflow-y: auto;
    
    .notification-item {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      padding: 16px;
      border-bottom: 1px solid var(--border-light);
      cursor: pointer;
      transition: background-color $transition-duration $transition-function;
      
      &:hover {
        background-color: var(--border-lighter);
      }
      
      &.is-unread {
        background-color: var(--primary-color);
        background-color: rgba(64, 158, 255, 0.05);
        border-left: 3px solid var(--primary-color);
        
        .notification-title {
          font-weight: 600;
        }
      }
      
      .notification-icon {
        margin-top: 2px;
      }
      
      .notification-content {
        flex: 1;
        min-width: 0;
        
        .notification-title {
          font-size: 14px;
          color: var(--text-primary);
          margin-bottom: 4px;
          word-break: break-word;
        }
        
        .notification-message {
          font-size: 12px;
          color: var(--text-secondary);
          margin-bottom: 8px;
          word-break: break-word;
          display: -webkit-box;
          -webkit-line-clamp: 2;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }
        
        .notification-time {
          font-size: 11px;
          color: var(--text-placeholder);
        }
      }
      
      .notification-actions {
        display: flex;
        gap: 4px;
        opacity: 0;
        transition: opacity $transition-duration $transition-function;
        
        .el-button {
          padding: 4px;
        }
      }
      
      &:hover .notification-actions {
        opacity: 1;
      }
    }
  }
  
  .notification-pagination {
    margin-top: 16px;
    text-align: center;
    border-top: 1px solid var(--border-light);
    padding-top: 16px;
  }
}
</style>