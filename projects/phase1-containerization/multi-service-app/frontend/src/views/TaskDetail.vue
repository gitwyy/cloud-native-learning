<template>
  <div class="task-detail">
    <el-card>
      <template #header>
        <div class="task-detail-header">
          <h2>任务详情</h2>
          <el-button @click="$router.back()">返回</el-button>
        </div>
      </template>
      
      <div class="task-content">
        <h3>任务: {{ taskId }}</h3>
        <p>这是任务详情页面</p>
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const taskId = computed(() => route.params.id)
</script>

<style lang="scss" scoped>
.task-detail {
  padding: 20px;
}

.task-detail-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.task-content {
  padding: 20px;
}
</style>