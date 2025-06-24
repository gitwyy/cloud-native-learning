<template>
  <el-container class="app-layout">
    <!-- 侧边栏 -->
    <el-aside 
      :width="sidebarWidth" 
      class="app-sidebar"
      :class="{ 'is-collapsed': appStore.sidebarCollapsed }"
    >
      <div class="sidebar-header">
        <div class="logo">
          <el-icon v-if="!appStore.sidebarCollapsed" class="logo-icon">
            <Document />
          </el-icon>
          <span v-if="!appStore.sidebarCollapsed" class="logo-text">
            Todo List Plus
          </span>
        </div>
      </div>
      
      <el-scrollbar class="sidebar-menu">
        <el-menu
          :default-active="$route.path"
          :collapse="appStore.sidebarCollapsed"
          :unique-opened="true"
          router
          class="sidebar-menu-el"
        >
          <template v-for="route in menuRoutes" :key="route.path">
            <el-menu-item 
              v-if="!route.children || route.children.length === 0"
              :index="route.path"
              @click="handleMenuClick(route)"
            >
              <el-icon>
                <component :is="route.meta?.icon || 'Document'" />
              </el-icon>
              <template #title>{{ route.meta?.title }}</template>
            </el-menu-item>
            
            <el-sub-menu 
              v-else
              :index="route.path"
            >
              <template #title>
                <el-icon>
                  <component :is="route.meta?.icon || 'Document'" />
                </el-icon>
                <span>{{ route.meta?.title }}</span>
              </template>
              <el-menu-item
                v-for="child in route.children"
                :key="child.path"
                :index="child.path"
                @click="handleMenuClick(child)"
              >
                <el-icon>
                  <component :is="child.meta?.icon || 'Document'" />
                </el-icon>
                <template #title>{{ child.meta?.title }}</template>
              </el-menu-item>
            </el-sub-menu>
          </template>
        </el-menu>
      </el-scrollbar>
    </el-aside>

    <el-container class="main-container">
      <!-- 顶部导航栏 -->
      <el-header class="app-header">
        <div class="header-left">
          <!-- 侧边栏切换按钮 -->
          <el-button 
            type="text" 
            @click="appStore.toggleSidebar"
            class="sidebar-toggle"
          >
            <el-icon>
              <Fold v-if="!appStore.sidebarCollapsed" />
              <Expand v-else />
            </el-icon>
          </el-button>
          
          <!-- 面包屑导航 -->
          <el-breadcrumb class="breadcrumb" separator="/">
            <el-breadcrumb-item 
              v-for="breadcrumb in appStore.breadcrumbs" 
              :key="breadcrumb.title"
              :to="breadcrumb.path"
            >
              {{ breadcrumb.title }}
            </el-breadcrumb-item>
          </el-breadcrumb>
        </div>

        <div class="header-right">
          <!-- 通知中心 -->
          <el-badge 
            :value="notificationsStore.unreadCount" 
            :hidden="!notificationsStore.hasUnreadNotifications"
            class="header-action"
          >
            <el-button type="text" @click="showNotifications">
              <el-icon>
                <Bell />
              </el-icon>
            </el-button>
          </el-badge>

          <!-- 全屏切换 -->
          <el-button 
            type="text" 
            @click="appStore.toggleFullscreen"
            class="header-action"
          >
            <el-icon>
              <FullScreen />
            </el-icon>
          </el-button>

          <!-- 主题切换 -->
          <el-button 
            type="text" 
            @click="appStore.toggleTheme"
            class="header-action"
          >
            <el-icon>
              <Sunny v-if="appStore.currentTheme === 'light'" />
              <Moon v-else-if="appStore.currentTheme === 'dark'" />
              <Monitor v-else />
            </el-icon>
          </el-button>

          <!-- 语言切换 -->
          <el-dropdown @command="handleLanguageChange" class="header-action">
            <el-button type="text">
              <el-icon>
                <Grid />
              </el-icon>
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="zh-CN">简体中文</el-dropdown-item>
                <el-dropdown-item command="en-US">English</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>

          <!-- 用户菜单 -->
          <el-dropdown @command="handleUserMenuCommand" class="user-dropdown">
            <div class="user-info">
              <el-avatar 
                :src="authStore.userAvatar" 
                :alt="authStore.userName"
                size="small"
              >
                <el-icon><User /></el-icon>
              </el-avatar>
              <span v-if="!appStore.isMobile" class="username">
                {{ authStore.userName }}
              </span>
              <el-icon class="dropdown-icon">
                <ArrowDown />
              </el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile">
                  <el-icon><User /></el-icon>
                  {{ $t('common.profile') }}
                </el-dropdown-item>
                <el-dropdown-item command="settings">
                  <el-icon><Setting /></el-icon>
                  {{ $t('common.settings') }}
                </el-dropdown-item>
                <el-dropdown-item divided command="logout">
                  <el-icon><SwitchButton /></el-icon>
                  {{ $t('common.logout') }}
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <!-- 主内容区域 -->
      <el-main class="app-main">
        <router-view v-slot="{ Component }">
          <transition name="fade-transform" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>

    <!-- 通知抽屉 -->
    <el-drawer
      v-model="notificationDrawerVisible"
      title="通知中心"
      :size="400"
      direction="rtl"
    >
      <NotificationCenter />
    </el-drawer>
  </el-container>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { 
  Document, Fold, Expand, Bell, FullScreen, Sunny, Moon, Monitor,
  Grid, User, ArrowDown, Setting, SwitchButton
} from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import { useNotificationsStore } from '@/stores/notifications'
import { getMenuRoutes } from '@/router'
import NotificationCenter from './NotificationCenter.vue'

const router = useRouter()
const { t } = useI18n()

// Stores
const authStore = useAuthStore()
const appStore = useAppStore()
const notificationsStore = useNotificationsStore()

// 响应式数据
const notificationDrawerVisible = ref(false)

// 计算属性
const sidebarWidth = computed(() => 
  appStore.sidebarCollapsed ? '64px' : '240px'
)

const menuRoutes = computed(() => 
  getMenuRoutes().filter(route => !route.meta?.hidden)
)

// 方法
const handleMenuClick = (route: any) => {
  if (route.path) {
    router.push(route.path)
  }
}

const showNotifications = () => {
  notificationDrawerVisible.value = true
}

const handleLanguageChange = (language: string) => {
  appStore.setLanguage(language as 'zh-CN' | 'en-US')
}

const handleUserMenuCommand = async (command: string) => {
  switch (command) {
    case 'profile':
      router.push('/profile')
      break
    case 'settings':
      // 可以打开设置弹窗或跳转到设置页
      break
    case 'logout':
      await authStore.logout()
      break
  }
}

// 初始化
appStore.initAppState()
</script>

<style lang="scss" scoped>
.app-layout {
  height: 100vh;
  
  .app-sidebar {
    background: var(--bg-color);
    border-right: 1px solid var(--border-light);
    transition: width $transition-duration $transition-function;
    
    &.is-collapsed {
      .sidebar-header .logo-text {
        opacity: 0;
      }
    }
    
    .sidebar-header {
      height: $header-height;
      display: flex;
      align-items: center;
      justify-content: center;
      border-bottom: 1px solid var(--border-light);
      
      .logo {
        display: flex;
        align-items: center;
        gap: 8px;
        
        .logo-icon {
          font-size: 24px;
          color: var(--primary-color);
        }
        
        .logo-text {
          font-size: 18px;
          font-weight: 600;
          color: var(--text-primary);
          transition: opacity $transition-duration $transition-function;
        }
      }
    }
    
    .sidebar-menu {
      height: calc(100vh - #{$header-height});
      
      .sidebar-menu-el {
        border: none;
        
        .el-menu-item,
        .el-sub-menu {
          &:hover {
            background-color: var(--border-lighter);
          }
          
          &.is-active {
            background-color: var(--primary-color);
            color: white;
            
            .el-icon {
              color: white;
            }
          }
        }
      }
    }
  }
  
  .main-container {
    .app-header {
      background: var(--bg-color);
      border-bottom: 1px solid var(--border-light);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 20px;
      
      .header-left {
        display: flex;
        align-items: center;
        gap: 16px;
        
        .sidebar-toggle {
          font-size: 18px;
        }
        
        .breadcrumb {
          font-size: 14px;
        }
      }
      
      .header-right {
        display: flex;
        align-items: center;
        gap: 8px;
        
        .header-action {
          padding: 8px;
          font-size: 18px;
        }
        
        .user-dropdown {
          .user-info {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            cursor: pointer;
            border-radius: 4px;
            transition: background-color $transition-duration $transition-function;
            
            &:hover {
              background-color: var(--border-lighter);
            }
            
            .username {
              font-size: 14px;
              color: var(--text-primary);
            }
            
            .dropdown-icon {
              font-size: 12px;
              color: var(--text-secondary);
            }
          }
        }
      }
    }
    
    .app-main {
      background: var(--bg-color-page);
      overflow: auto;
    }
  }
}

// 页面过渡动画
.fade-transform-enter-active,
.fade-transform-leave-active {
  transition: all $transition-duration $transition-function;
}

.fade-transform-enter-from {
  opacity: 0;
  transform: translateX(-10px);
}

.fade-transform-leave-to {
  opacity: 0;
  transform: translateX(10px);
}

// 响应式样式
@media (max-width: #{$mobile}) {
  .app-layout {
    .app-sidebar {
      position: fixed;
      z-index: $z-sidebar;
      height: 100vh;
    }
    
    .main-container {
      margin-left: 0;
      
      .app-header {
        .header-left .breadcrumb {
          display: none;
        }
        
        .header-right .username {
          display: none;
        }
      }
    }
  }
}
</style>