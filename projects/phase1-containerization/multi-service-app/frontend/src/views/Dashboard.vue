<template>
  <div class="dashboard">
    <div class="app-container">
      <div class="page-header">
        <div class="title">{{ $t('dashboard.welcome') }}</div>
        <div class="subtitle">{{ $t('dashboard.overview') }}</div>
      </div>
      
      <div class="dashboard-content">
        <el-row :gutter="20">
          <el-col :xs="24" :sm="12" :md="6">
            <div class="stat-card">
              <h3>{{ $t('dashboard.totalTasks') }}</h3>
              <div class="stat-number">{{ taskStats.total }}</div>
            </div>
          </el-col>
          <el-col :xs="24" :sm="12" :md="6">
            <div class="stat-card">
              <h3>{{ $t('dashboard.pendingTasks') }}</h3>
              <div class="stat-number">{{ taskStats.pending }}</div>
            </div>
          </el-col>
          <el-col :xs="24" :sm="12" :md="6">
            <div class="stat-card">
              <h3>{{ $t('dashboard.completionRate') }}</h3>
              <div class="stat-number">{{ taskStats.completionRate }}%</div>
            </div>
          </el-col>
          <el-col :xs="24" :sm="12" :md="6">
            <div class="stat-card">
              <h3>{{ $t('dashboard.overdueTasksCount') }}</h3>
              <div class="stat-number">{{ taskStats.overdue }}</div>
            </div>
          </el-col>
        </el-row>
        
        <el-row :gutter="20" style="margin-top: 20px;">
          <el-col :span="24">
            <el-card>
              <template #header>
                <span>{{ $t('dashboard.quickActions') }}</span>
              </template>
              <el-space wrap>
                <el-button type="primary" @click="createTask">
                  <el-icon><Plus /></el-icon>
                  创建任务
                </el-button>
                <el-button @click="goToTasks">
                  <el-icon><Document /></el-icon>
                  查看所有任务
                </el-button>
                <el-button @click="goToNotifications">
                  <el-icon><Bell /></el-icon>
                  查看通知
                </el-button>
              </el-space>
            </el-card>
          </el-col>
        </el-row>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { Plus, Document, Bell } from '@element-plus/icons-vue'
import { useTasksStore } from '@/stores/tasks'
import { useAppStore } from '@/stores/app'

const router = useRouter()
const { t } = useI18n()
const tasksStore = useTasksStore()
const appStore = useAppStore()

const taskStats = computed(() => tasksStore.taskStats)

const createTask = () => {
  router.push('/tasks?action=create')
}

const goToTasks = () => {
  router.push('/tasks')
}

const goToNotifications = () => {
  router.push('/notifications')
}

onMounted(() => {
  appStore.setPageTitle(t('dashboard.welcome'))
  tasksStore.fetchTasks()
})
</script>

<style lang="scss" scoped>
.dashboard {
  .stat-card {
    background: var(--bg-color);
    padding: 20px;
    border-radius: 8px;
    box-shadow: var(--shadow-light);
    text-align: center;
    
    h3 {
      margin: 0 0 10px 0;
      font-size: 14px;
      color: var(--text-secondary);
    }
    
    .stat-number {
      font-size: 24px;
      font-weight: 600;
      color: var(--primary-color);
    }
  }
}
</style>