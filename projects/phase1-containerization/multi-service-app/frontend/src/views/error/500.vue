<template>
  <div class="error-page">
    <div class="error-content">
      <div class="error-code">500</div>
      <div class="error-title">{{ $t('error.500') }}</div>
      <div class="error-description">服务器出现了一些问题，请稍后再试</div>
      <el-space>
        <el-button type="primary" @click="refresh">刷新页面</el-button>
        <el-button @click="goHome">回到首页</el-button>
      </el-space>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'

const router = useRouter()
const { t } = useI18n()

const refresh = () => {
  location.reload()
}

const goHome = () => {
  router.push('/')
}
</script>

<style lang="scss" scoped>
.error-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-color-page);
  
  .error-content {
    text-align: center;
    
    .error-code {
      font-size: 120px;
      font-weight: bold;
      color: var(--primary-color);
      line-height: 1;
      margin-bottom: 20px;
    }
    
    .error-title {
      font-size: 24px;
      color: var(--text-primary);
      margin-bottom: 16px;
    }
    
    .error-description {
      font-size: 16px;
      color: var(--text-secondary);
      margin-bottom: 30px;
    }
  }
}
</style>