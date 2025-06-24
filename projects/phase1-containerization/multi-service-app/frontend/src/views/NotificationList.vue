<template>
  <div class="notification-list">
    <el-card>
      <template #header>
        <div class="notification-header">
          <h2>通知中心</h2>
          <el-button @click="markAllAsRead">全部标记为已读</el-button>
        </div>
      </template>
      
      <div class="notification-content">
        <el-empty description="暂无通知" />
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
const markAllAsRead = () => {
  console.log('标记所有通知为已读')
}
</script>

<style lang="scss" scoped>
.notification-list {
  padding: 20px;
}

.notification-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.notification-content {
  padding: 20px;
}
</style>