import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import { ElMessage } from 'element-plus'
import NProgress from 'nprogress'

// 路由配置
const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: {
      title: '登录',
      requiresAuth: false,
      hidden: true,
    },
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('@/views/Register.vue'),
    meta: {
      title: '注册',
      requiresAuth: false,
      hidden: true,
    },
  },
  {
    path: '/',
    name: 'Layout',
    component: () => import('@/components/Layout.vue'),
    redirect: '/dashboard',
    meta: {
      requiresAuth: true,
    },
    children: [
      {
        path: '/dashboard',
        name: 'Dashboard',
        component: () => import('@/views/Dashboard.vue'),
        meta: {
          title: '仪表板',
          icon: 'odometer',
          requiresAuth: true,
        },
      },
      {
        path: '/tasks',
        name: 'TaskManager',
        component: () => import('@/views/TaskManager.vue'),
        meta: {
          title: '任务管理',
          icon: 'document',
          requiresAuth: true,
        },
      },
      {
        path: '/tasks/:id',
        name: 'TaskDetail',
        component: () => import('@/views/TaskDetail.vue'),
        meta: {
          title: '任务详情',
          requiresAuth: true,
          hidden: true,
        },
      },
      {
        path: '/notifications',
        name: 'NotificationList',
        component: () => import('@/views/NotificationList.vue'),
        meta: {
          title: '通知中心',
          icon: 'bell',
          requiresAuth: true,
        },
      },
      {
        path: '/profile',
        name: 'Profile',
        component: () => import('@/views/Profile.vue'),
        meta: {
          title: '个人中心',
          icon: 'user',
          requiresAuth: true,
        },
      },
    ],
  },
  {
    path: '/403',
    name: 'Forbidden',
    component: () => import('@/views/error/403.vue'),
    meta: {
      title: '访问被拒绝',
      hidden: true,
    },
  },
  {
    path: '/404',
    name: 'NotFound',
    component: () => import('@/views/error/404.vue'),
    meta: {
      title: '页面不存在',
      hidden: true,
    },
  },
  {
    path: '/500',
    name: 'ServerError',
    component: () => import('@/views/error/500.vue'),
    meta: {
      title: '服务器错误',
      hidden: true,
    },
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/404',
  },
]

// 创建路由实例
const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    // 如果有保存的位置（例如通过浏览器后退按钮），则滚动到该位置
    if (savedPosition) {
      return savedPosition
    }
    // 否则滚动到页面顶部
    return { top: 0 }
  },
})

// 全局前置守卫
router.beforeEach(async (to, from, next) => {
  // 开始进度条
  NProgress.start()

  try {
    const authStore = useAuthStore()
    const appStore = useAppStore()

    // 设置页面标题
    if (to.meta.title) {
      appStore.setPageTitle(to.meta.title as string)
    }

    // 生成面包屑
    const breadcrumbs = generateBreadcrumbs(to)
    appStore.setBreadcrumbs(breadcrumbs)

    // 暂时禁用认证检查，用于调试
    // TODO: 后续启用认证功能
    /*
    // 检查是否需要认证
    if (to.meta.requiresAuth) {
      if (!authStore.isAuthenticated) {
        ElMessage.warning('请先登录')
        next({
          path: '/login',
          query: { redirect: to.fullPath },
        })
        return
      }

      // 验证token有效性
      const isValidToken = await authStore.validateToken()
      if (!isValidToken) {
        ElMessage.error('登录已过期，请重新登录')
        next({
          path: '/login',
          query: { redirect: to.fullPath },
        })
        return
      }
    }

    // 如果已登录用户访问登录/注册页面，重定向到首页
    if ((to.name === 'Login' || to.name === 'Register') && authStore.isAuthenticated) {
      next({ path: '/' })
      return
    }
    */

    next()
  } catch (error) {
    console.error('Router guard error:', error)
    next()
  }
})

// 全局后置守卫
router.afterEach((to, from) => {
  // 结束进度条
  NProgress.done()

  // 更新页面标题
  const appStore = useAppStore()
  if (to.meta.title) {
    appStore.setPageTitle(to.meta.title as string)
  }
})

// 路由错误处理
router.onError((error) => {
  console.error('Router error:', error)
  NProgress.done()
  ElMessage.error('页面加载失败')
})

// 生成面包屑导航
function generateBreadcrumbs(route: any): Array<{ title: string; path?: string }> {
  const breadcrumbs: Array<{ title: string; path?: string }> = []
  
  // 添加首页
  breadcrumbs.push({ title: '首页', path: '/dashboard' })
  
  // 根据当前路由生成面包屑
  if (route.name === 'Dashboard') {
    breadcrumbs[0] = { title: '仪表板' }
  } else if (route.name === 'TaskManager') {
    breadcrumbs.push({ title: '任务管理' })
  } else if (route.name === 'TaskDetail') {
    breadcrumbs.push({ title: '任务管理', path: '/tasks' })
    breadcrumbs.push({ title: '任务详情' })
  } else if (route.name === 'NotificationList') {
    breadcrumbs.push({ title: '通知中心' })
  } else if (route.name === 'Profile') {
    breadcrumbs.push({ title: '个人中心' })
  }
  
  return breadcrumbs
}

// 导出路由相关函数
export { routes }

// 获取菜单路由（用于生成侧边栏菜单）
export function getMenuRoutes() {
  return routes
    .find(route => route.name === 'Layout')
    ?.children?.filter(route => !route.meta?.hidden) || []
}

// 检查路由权限
export function hasRoutePermission(route: RouteRecordRaw, userRoles: string[] = []): boolean {
  if (!route.meta?.roles) {
    return true
  }
  
  const roles = route.meta.roles as string[]
  return roles.some((role: string) => userRoles.includes(role))
}

// 动态添加路由
export function addRoutes(newRoutes: RouteRecordRaw[]) {
  newRoutes.forEach(route => {
    router.addRoute(route)
  })
}

export default router