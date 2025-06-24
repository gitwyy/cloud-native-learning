<template>
  <div class="login-container">
    <div class="login-box">
      <div class="login-header">
        <div class="logo">
          <el-icon class="logo-icon">
            <Document />
          </el-icon>
          <h1 class="logo-text">Todo List Plus</h1>
        </div>
        <p class="subtitle">{{ $t('auth.login') }}</p>
      </div>

      <el-form
        ref="loginFormRef"
        :model="loginForm"
        :rules="loginRules"
        class="login-form"
        size="large"
        @submit.prevent="handleLogin"
      >
        <el-form-item prop="username">
          <el-input
            v-model="loginForm.username"
            :placeholder="$t('auth.username')"
            prefix-icon="User"
            clearable
            autocomplete="username"
          />
        </el-form-item>

        <el-form-item prop="password">
          <el-input
            v-model="loginForm.password"
            type="password"
            :placeholder="$t('auth.password')"
            prefix-icon="Lock"
            show-password
            clearable
            autocomplete="current-password"
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-form-item>
          <div class="login-options">
            <el-checkbox v-model="rememberMe">
              {{ $t('auth.rememberMe') }}
            </el-checkbox>
            <el-link type="primary" @click="showForgotPassword">
              {{ $t('auth.forgotPassword') }}
            </el-link>
          </div>
        </el-form-item>

        <el-form-item>
          <el-button
            type="primary"
            class="login-button"
            :loading="authStore.loading"
            @click="handleLogin"
          >
            {{ $t('auth.login') }}
          </el-button>
        </el-form-item>

        <el-form-item>
          <div class="register-link">
            <span>{{ $t('auth.noAccount') }}</span>
            <el-link type="primary" @click="goToRegister">
              {{ $t('auth.register') }}
            </el-link>
          </div>
        </el-form-item>
      </el-form>

      <!-- 语言切换 -->
      <div class="language-switch">
        <el-dropdown @command="handleLanguageChange">
          <el-button type="text" size="small">
            <el-icon><Grid /></el-icon>
            {{ currentLanguageLabel }}
          </el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="zh-CN">简体中文</el-dropdown-item>
              <el-dropdown-item command="en-US">English</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </div>

      <!-- 主题切换 -->
      <div class="theme-switch">
        <el-button type="text" size="small" @click="appStore.toggleTheme">
          <el-icon>
            <Sunny v-if="appStore.currentTheme === 'light'" />
            <Moon v-else-if="appStore.currentTheme === 'dark'" />
            <Monitor v-else />
          </el-icon>
        </el-button>
      </div>
    </div>

    <!-- 背景装饰 -->
    <div class="background-decoration">
      <div class="decoration-circle circle-1"></div>
      <div class="decoration-circle circle-2"></div>
      <div class="decoration-circle circle-3"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import type { FormInstance, FormRules } from 'element-plus'
import { ElMessage } from 'element-plus'
import { Document, User, Lock, Grid, Sunny, Moon, Monitor } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import type { LoginRequest } from '@/types'

const router = useRouter()
const route = useRoute()
const { t } = useI18n()

// Stores
const authStore = useAuthStore()
const appStore = useAppStore()

// Refs
const loginFormRef = ref<FormInstance>()

// 响应式数据
const loginForm = reactive<LoginRequest>({
  username: '',
  password: '',
})

const rememberMe = ref(false)

// 计算属性
const currentLanguageLabel = computed(() => {
  return appStore.language === 'zh-CN' ? '简体中文' : 'English'
})

// 表单验证规则
const loginRules = reactive<FormRules>({
  username: [
    { required: true, message: t('auth.usernameRequired'), trigger: 'blur' },
    { min: 3, max: 20, message: '用户名长度应为3-20个字符', trigger: 'blur' },
  ],
  password: [
    { required: true, message: t('auth.passwordRequired'), trigger: 'blur' },
    { min: 6, message: t('auth.passwordTooShort'), trigger: 'blur' },
  ],
})

// 方法
const handleLogin = async () => {
  if (!loginFormRef.value) return

  try {
    const valid = await loginFormRef.value.validate()
    if (!valid) return

    const success = await authStore.login(loginForm)
    
    if (success) {
      // 保存记住我状态
      if (rememberMe.value) {
        localStorage.setItem('remember_username', loginForm.username)
      } else {
        localStorage.removeItem('remember_username')
      }

      // 跳转到目标页面或首页
      const redirect = route.query.redirect as string
      router.push(redirect || '/')
    }
  } catch (error) {
    console.error('Login error:', error)
  }
}

const goToRegister = () => {
  router.push('/register')
}

const showForgotPassword = () => {
  ElMessage.info('忘记密码功能敬请期待')
}

const handleLanguageChange = (language: string) => {
  appStore.setLanguage(language as 'zh-CN' | 'en-US')
}

// 生命周期
onMounted(() => {
  // 初始化应用状态
  appStore.initAppState()
  
  // 如果已登录，重定向到首页
  if (authStore.isAuthenticated) {
    router.push('/')
    return
  }

  // 恢复记住的用户名
  const rememberedUsername = localStorage.getItem('remember_username')
  if (rememberedUsername) {
    loginForm.username = rememberedUsername
    rememberMe.value = true
  }

  // 设置页面标题
  appStore.setPageTitle(t('auth.login'))
})
</script>

<style lang="scss" scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  position: relative;
  overflow: hidden;
  
  .login-box {
    width: 400px;
    max-width: 90vw;
    background: var(--bg-color);
    border-radius: 12px;
    box-shadow: var(--shadow-dark);
    padding: 40px;
    position: relative;
    z-index: 10;
    
    .login-header {
      text-align: center;
      margin-bottom: 32px;
      
      .logo {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 12px;
        margin-bottom: 16px;
        
        .logo-icon {
          font-size: 32px;
          color: var(--primary-color);
        }
        
        .logo-text {
          font-size: 24px;
          font-weight: 600;
          color: var(--text-primary);
          margin: 0;
        }
      }
      
      .subtitle {
        font-size: 16px;
        color: var(--text-secondary);
        margin: 0;
      }
    }
    
    .login-form {
      .login-options {
        display: flex;
        justify-content: space-between;
        align-items: center;
        width: 100%;
      }
      
      .login-button {
        width: 100%;
        height: 44px;
        font-size: 16px;
        font-weight: 500;
      }
      
      .register-link {
        text-align: center;
        font-size: 14px;
        color: var(--text-secondary);
        
        .el-link {
          margin-left: 8px;
        }
      }
    }
    
    .language-switch {
      position: absolute;
      top: 20px;
      left: 20px;
    }
    
    .theme-switch {
      position: absolute;
      top: 20px;
      right: 20px;
    }
  }
  
  .background-decoration {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    
    .decoration-circle {
      position: absolute;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.1);
      animation: float 6s ease-in-out infinite;
      
      &.circle-1 {
        width: 120px;
        height: 120px;
        top: 10%;
        left: 10%;
        animation-delay: 0s;
      }
      
      &.circle-2 {
        width: 200px;
        height: 200px;
        top: 60%;
        right: 10%;
        animation-delay: 2s;
      }
      
      &.circle-3 {
        width: 80px;
        height: 80px;
        bottom: 20%;
        left: 20%;
        animation-delay: 4s;
      }
    }
  }
}

@keyframes float {
  0%, 100% {
    transform: translateY(0px);
  }
  50% {
    transform: translateY(-20px);
  }
}

// 响应式样式
@media (max-width: #{$mobile}) {
  .login-container {
    padding: 20px;
    
    .login-box {
      width: 100%;
      padding: 30px 20px;
      
      .login-header {
        margin-bottom: 24px;
        
        .logo {
          margin-bottom: 12px;
          
          .logo-icon {
            font-size: 28px;
          }
          
          .logo-text {
            font-size: 20px;
          }
        }
      }
    }
  }
}

// 深色主题适配
[data-theme='dark'] {
  .login-container {
    background: linear-gradient(135deg, #2d3748 0%, #1a202c 100%);
  }
}
</style>