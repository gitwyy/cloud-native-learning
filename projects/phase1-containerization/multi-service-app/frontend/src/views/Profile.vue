<template>
  <div class="profile">
    <div class="app-container">
      <div class="page-header">
        <div class="title">{{ $t('profile.personalInfo') }}</div>
        <div class="subtitle">管理您的个人信息</div>
      </div>
      
      <el-card>
        <el-empty description="个人中心页面开发中..." />
      </el-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAppStore } from '@/stores/app'

const { t } = useI18n()
const appStore = useAppStore()

onMounted(() => {
  appStore.setPageTitle(t('profile.personalInfo'))
})
</script>