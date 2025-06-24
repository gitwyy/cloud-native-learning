import { createRouter, createWebHistory } from 'vue-router'

// 简化的路由配置，仅用于调试
const routes = [
  {
    path: '/',
    component: () => import('@/views/Dashboard.vue'),
  },
  {
    path: '/login',
    component: () => import('@/views/Login.vue'),
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router