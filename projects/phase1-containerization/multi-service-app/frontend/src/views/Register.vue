<template>
  <div class="register-container">
    <div class="register-box">
      <div class="register-header">
        <div class="logo">
          <el-icon class="logo-icon">
            <Document />
          </el-icon>
          <h1 class="logo-text">Todo List Plus</h1>
        </div>
        <p class="subtitle">{{ $t('auth.register') }}</p>
      </div>

      <el-form
        ref="registerFormRef"
        :model="registerForm"
        :rules="registerRules"
        class="register-form"
        size="large"
        @submit.prevent="handleRegister"
      >
        <el-form-item prop="username">
          <el-input
            v-model="registerForm.username"
            :placeholder="$t('auth.username')"
            prefix-icon="User"
            clearable
            autocomplete="username"
          />
        </el-form-item>

        <el-form-item prop="email">
          <el-input
            v-model="registerForm.email"
            type="email"
            :placeholder="$t('auth.email')"
            prefix-icon="Message"
            clearable
            autocomplete="email"
          />
        </el-form-item>

        <el-form-item prop="password">
          <el-input
            v-model="registerForm.password"
            type="password"
            :placeholder="$t('auth.password')"
            prefix-icon="Lock"
            show-password
            clearable
            autocomplete="new-password"
          />
        </el-form-item>

        <el-form-item prop="confirmPassword">
          <el-input
            v-model="registerForm.confirmPassword"
            type="password"
            :placeholder="$t('auth.confirmPassword')"
            prefix-icon="Lock"
            show-password
            clearable
            autocomplete="new-password"
            @keyup.enter="handleRegister"
          />
        </el-form-item>

        <el-form-item>
          <el-button
            type="primary"
            class="register-button"
            :loading="authStore.loading"
            @click="handleRegister"
          >
            {{ $t('auth.register') }}
          </el-button>
        </el-form-item>

        <el-form-item>
          <div class="login-link">
            <span>{{ $t('auth.hasAccount') }}</span>
            <el-link type="primary" @click="goToLogin">
              {{ $t('auth.login') }}
            </el-link>
          </div>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import type { FormInstance, FormRules } from 'element-plus'
import { Document, User, Message, Lock } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'
import type { RegisterRequest } from '@/types'

const router = useRouter()
const { t } = useI18n()

// Stores
const authStore = useAuthStore()
const appStore = useAppStore()

// Refs
const registerFormRef = ref<FormInstance>()

// 响应式数据
const registerForm = reactive<RegisterRequest & { confirmPassword: string }>({
  username: '',
  email: '',
  password: '',
  confirmPassword: '',
})

// 表单验证规则
const registerRules = reactive<FormRules>({
  username: [
    { required: true, message: t('auth.usernameRequired'), trigger: 'blur' },
    { min: 3, max: 20, message: '用户名长度应为3-20个字符', trigger: 'blur' },
  ],
  email: [
    { required: true, message: t('auth.emailRequired'), trigger: 'blur' },
    { type: 'email', message: t('auth.emailInvalid'), trigger: 'blur' },
  ],
  password: [
    { required: true, message: t('auth.passwordRequired'), trigger: 'blur' },
    { min: 6, message: t('auth.passwordTooShort'), trigger: 'blur' },
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    {
      validator: (rule, value, callback) => {
        if (value !== registerForm.password) {
          callback(new Error(t('auth.passwordMismatch')))
        } else {
          callback()
        }
      },
      trigger: 'blur',
    },
  ],
})

// 方法
const handleRegister = async () => {
  if (!registerFormRef.value) return

  try {
    const valid = await registerFormRef.value.validate()
    if (!valid) return

    const { confirmPassword, ...registerData } = registerForm
    const success = await authStore.register(registerData)
    
    if (success) {
      router.push('/')
    }
  } catch (error) {
    console.error('Register error:', error)
  }
}

const goToLogin = () => {
  router.push('/login')
}

// 生命周期
appStore.setPageTitle(t('auth.register'))
</script>

<style lang="scss" scoped>
.register-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  position: relative;
  overflow: hidden;
  
  .register-box {
    width: 400px;
    max-width: 90vw;
    background: var(--bg-color);
    border-radius: 12px;
    box-shadow: var(--shadow-dark);
    padding: 40px;
    position: relative;
    z-index: 10;
    
    .register-header {
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
    
    .register-form {
      .register-button {
        width: 100%;
        height: 44px;
        font-size: 16px;
        font-weight: 500;
      }
      
      .login-link {
        text-align: center;
        font-size: 14px;
        color: var(--text-secondary);
        
        .el-link {
          margin-left: 8px;
        }
      }
    }
  }
}
</style>