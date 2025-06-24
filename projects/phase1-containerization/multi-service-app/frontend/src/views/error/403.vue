<template>
  <div class="error-page">
    <div class="error-content">
      <div class="error-code">403</div>
      <div class="error-title">{{ $t('error.403') }}</div>
      <div class="error-description">抱歉，您没有权限访问此页面</div>
      <el-button type="primary" @click="goBack">返回上一页</el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'

const router = useRouter()
const { t } = useI18n()

const goBack = () => {
  router.back()
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