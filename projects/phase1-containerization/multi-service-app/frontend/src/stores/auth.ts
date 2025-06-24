import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
import Cookies from 'js-cookie'
import type { User, LoginRequest, RegisterRequest, AuthResponse } from '@/types'
import { request } from '@/services/api'

export const useAuthStore = defineStore('auth', () => {
  // 状态
  const user = ref<User | null>(null)
  const token = ref<string | null>(null)
  const loading = ref(false)

  // 计算属性
  const isAuthenticated = computed(() => !!token.value && !!user.value)
  const userName = computed(() => user.value?.username || '')
  const userEmail = computed(() => user.value?.email || '')
  const userAvatar = computed(() => user.value?.avatar || '')

  // 从localStorage和cookies恢复状态
  const initAuth = () => {
    try {
      const savedToken = Cookies.get('auth_token')
      const savedUser = localStorage.getItem('auth_user')
      
      if (savedToken && savedUser) {
        token.value = savedToken
        user.value = JSON.parse(savedUser)
      }
    } catch (error) {
      console.error('Failed to restore auth state:', error)
      clearAuth()
    }
  }

  // 保存认证状态
  const saveAuth = (authData: AuthResponse) => {
    token.value = authData.access_token
    user.value = authData.user
    
    // 保存到cookies和localStorage
    Cookies.set('auth_token', authData.access_token, { expires: 7 }) // 7天过期
    localStorage.setItem('auth_user', JSON.stringify(authData.user))
  }

  // 清除认证状态
  const clearAuth = () => {
    token.value = null
    user.value = null
    Cookies.remove('auth_token')
    localStorage.removeItem('auth_user')
  }

  // 登录
  const login = async (credentials: LoginRequest): Promise<boolean> => {
    try {
      loading.value = true
      const response = await request.post<AuthResponse>('/api/v1/auth/login', credentials)
      
      saveAuth(response)
      ElMessage.success('登录成功')
      return true
    } catch (error) {
      console.error('Login failed:', error)
      return false
    } finally {
      loading.value = false
    }
  }

  // 注册
  const register = async (userData: RegisterRequest): Promise<boolean> => {
    try {
      loading.value = true
      const response = await request.post<AuthResponse>('/api/v1/auth/register', userData)
      
      saveAuth(response)
      ElMessage.success('注册成功')
      return true
    } catch (error) {
      console.error('Registration failed:', error)
      return false
    } finally {
      loading.value = false
    }
  }

  // 登出
  const logout = async (): Promise<void> => {
    try {
      await request.post('/api/v1/auth/logout')
    } catch (error) {
      console.error('Logout request failed:', error)
    } finally {
      clearAuth()
      ElMessage.success('已退出登录')
      
      // 跳转到登录页
      if (typeof window !== 'undefined') {
        window.location.href = '/login'
      }
    }
  }

  // 刷新用户信息
  const refreshUser = async (): Promise<boolean> => {
    if (!token.value) return false
    
    try {
      const userData = await request.get<User>('/api/v1/auth/me')
      user.value = userData
      localStorage.setItem('auth_user', JSON.stringify(userData))
      return true
    } catch (error) {
      console.error('Failed to refresh user info:', error)
      clearAuth()
      return false
    }
  }

  // 更新用户资料
  const updateProfile = async (profileData: Partial<User>): Promise<boolean> => {
    try {
      loading.value = true
      const updatedUser = await request.patch<User>('/api/v1/users/profile', profileData)
      
      user.value = updatedUser
      localStorage.setItem('auth_user', JSON.stringify(updatedUser))
      ElMessage.success('资料更新成功')
      return true
    } catch (error) {
      console.error('Failed to update profile:', error)
      return false
    } finally {
      loading.value = false
    }
  }

  // 修改密码
  const changePassword = async (currentPassword: string, newPassword: string): Promise<boolean> => {
    try {
      loading.value = true
      await request.post('/api/v1/auth/change-password', {
        current_password: currentPassword,
        new_password: newPassword,
      })
      
      ElMessage.success('密码修改成功')
      return true
    } catch (error) {
      console.error('Failed to change password:', error)
      return false
    } finally {
      loading.value = false
    }
  }

  // 检查token有效性
  const validateToken = async (): Promise<boolean> => {
    if (!token.value) return false
    
    try {
      await request.get('/api/v1/auth/validate')
      return true
    } catch (error) {
      clearAuth()
      return false
    }
  }

  return {
    // 状态
    user,
    token,
    loading,
    
    // 计算属性
    isAuthenticated,
    userName,
    userEmail,
    userAvatar,
    
    // 方法
    initAuth,
    login,
    register,
    logout,
    refreshUser,
    updateProfile,
    changePassword,
    validateToken,
    clearAuth,
  }
})

// 实现全局函数
;(globalThis as any).getAuthToken = () => {
  const authStore = useAuthStore()
  return authStore.token
}

;(globalThis as any).clearAuth = () => {
  const authStore = useAuthStore()
  authStore.clearAuth()
}