<template>
  <div class="task-manager">
    <div class="app-container">
      <div class="page-header">
        <div class="title">{{ $t('task.taskList') }}</div>
        <div class="subtitle">管理您的所有任务</div>
      </div>
      
      <el-card>
        <template #header>
          <div class="card-header">
            <span>任务列表</span>
            <el-button type="primary">
              <el-icon><Plus /></el-icon>
              创建任务
            </el-button>
          </div>
        </template>
        
        <el-empty description="任务管理功能开发中..." />
      </el-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { Plus } from '@element-plus/icons-vue'
import { useAppStore } from '@/stores/app'

const { t } = useI18n()
const appStore = useAppStore()

onMounted(() => {
  appStore.setPageTitle(t('task.taskList'))
})
</script>

<style lang="scss" scoped>
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>