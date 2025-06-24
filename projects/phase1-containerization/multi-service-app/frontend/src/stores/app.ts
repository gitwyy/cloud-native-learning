import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import { ElMessage } from 'element-plus'
import type { AppState } from '@/types'

export const useAppStore = defineStore('app', () => {
  // 状态
  const theme = ref<'light' | 'dark' | 'auto'>('light')
  const language = ref<'zh-CN' | 'en-US'>('zh-CN')
  const sidebarCollapsed = ref(false)
  const loading = ref(false)
  const loadingText = ref('加载中...')
  const isMobile = ref(false)
  const deviceType = ref<'desktop' | 'tablet' | 'mobile'>('desktop')
  
  // 面包屑导航
  const breadcrumbs = ref<Array<{ title: string; path?: string }>>([])
  
  // 页面标题
  const pageTitle = ref('Todo List Plus')
  
  // 网络状态
  const isOnline = ref(true)
  
  // 全屏状态
  const isFullscreen = ref(false)

  // 计算属性
  const currentTheme = computed(() => {
    if (theme.value === 'auto') {
      // 检测系统主题
      if (typeof window !== 'undefined') {
        return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
      }
      return 'light'
    }
    return theme.value
  })

  const appConfig = computed((): AppState => ({
    theme: theme.value,
    language: language.value,
    sidebarCollapsed: sidebarCollapsed.value,
    loading: loading.value,
  }))

  // 从localStorage恢复状态
  const initAppState = (): void => {
    try {
      const savedTheme = localStorage.getItem('app_theme') as 'light' | 'dark' | 'auto'
      const savedLanguage = localStorage.getItem('app_language') as 'zh-CN' | 'en-US'
      const savedSidebarState = localStorage.getItem('app_sidebar_collapsed')
      
      if (savedTheme) {
        theme.value = savedTheme
      }
      
      if (savedLanguage) {
        language.value = savedLanguage
      }
      
      if (savedSidebarState !== null) {
        sidebarCollapsed.value = JSON.parse(savedSidebarState)
      }

      // 检测设备类型
      detectDeviceType()
      
      // 应用主题
      applyTheme()
      
      // 监听系统主题变化
      if (typeof window !== 'undefined') {
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', applyTheme)
      }
      
      // 监听网络状态
      if (typeof window !== 'undefined') {
        window.addEventListener('online', () => {
          isOnline.value = true
          ElMessage.success('网络连接已恢复')
        })
        
        window.addEventListener('offline', () => {
          isOnline.value = false
          ElMessage.warning('网络连接已断开')
        })
      }
      
    } catch (error) {
      console.error('Failed to restore app state:', error)
    }
  }

  // 设置主题
  const setTheme = (newTheme: 'light' | 'dark' | 'auto'): void => {
    theme.value = newTheme
    localStorage.setItem('app_theme', newTheme)
    applyTheme()
  }

  // 应用主题
  const applyTheme = (): void => {
    if (typeof document !== 'undefined') {
      const root = document.documentElement
      const actualTheme = currentTheme.value
      
      root.setAttribute('data-theme', actualTheme)
      
      // 更新Element Plus的主题
      if (actualTheme === 'dark') {
        root.classList.add('dark')
      } else {
        root.classList.remove('dark')
      }
    }
  }

  // 切换主题
  const toggleTheme = (): void => {
    const themes: Array<'light' | 'dark' | 'auto'> = ['light', 'dark', 'auto']
    const currentIndex = themes.indexOf(theme.value)
    const nextIndex = (currentIndex + 1) % themes.length
    setTheme(themes[nextIndex])
  }

  // 设置语言
  const setLanguage = (newLanguage: 'zh-CN' | 'en-US'): void => {
    language.value = newLanguage
    localStorage.setItem('app_language', newLanguage)
    
    // 更新document的lang属性
    if (typeof document !== 'undefined') {
      document.documentElement.lang = newLanguage
    }
  }

  // 切换侧边栏状态
  const toggleSidebar = (): void => {
    sidebarCollapsed.value = !sidebarCollapsed.value
    localStorage.setItem('app_sidebar_collapsed', JSON.stringify(sidebarCollapsed.value))
  }

  // 设置侧边栏状态
  const setSidebarCollapsed = (collapsed: boolean): void => {
    sidebarCollapsed.value = collapsed
    localStorage.setItem('app_sidebar_collapsed', JSON.stringify(collapsed))
  }

  // 显示全局加载
  const showLoading = (text?: string): void => {
    loading.value = true
    if (text) {
      loadingText.value = text
    }
  }

  // 隐藏全局加载
  const hideLoading = (): void => {
    loading.value = false
    loadingText.value = '加载中...'
  }

  // 设置页面标题
  const setPageTitle = (title: string): void => {
    pageTitle.value = title
    
    if (typeof document !== 'undefined') {
      document.title = `${title} - Todo List Plus`
    }
  }

  // 设置面包屑
  const setBreadcrumbs = (crumbs: Array<{ title: string; path?: string }>): void => {
    breadcrumbs.value = crumbs
  }

  // 检测设备类型
  const detectDeviceType = (): void => {
    if (typeof window !== 'undefined') {
      const width = window.innerWidth
      
      if (width < 768) {
        deviceType.value = 'mobile'
        isMobile.value = true
        // 移动端自动收起侧边栏
        setSidebarCollapsed(true)
      } else if (width < 992) {
        deviceType.value = 'tablet'
        isMobile.value = false
      } else {
        deviceType.value = 'desktop'
        isMobile.value = false
      }
    }
  }

  // 进入全屏
  const enterFullscreen = async (): Promise<boolean> => {
    if (typeof document !== 'undefined' && document.documentElement.requestFullscreen) {
      try {
        await document.documentElement.requestFullscreen()
        isFullscreen.value = true
        return true
      } catch (error) {
        console.error('Failed to enter fullscreen:', error)
        return false
      }
    }
    return false
  }

  // 退出全屏
  const exitFullscreen = async (): Promise<boolean> => {
    if (typeof document !== 'undefined' && document.exitFullscreen) {
      try {
        await document.exitFullscreen()
        isFullscreen.value = false
        return true
      } catch (error) {
        console.error('Failed to exit fullscreen:', error)
        return false
      }
    }
    return false
  }

  // 切换全屏
  const toggleFullscreen = async (): Promise<void> => {
    if (isFullscreen.value) {
      await exitFullscreen()
    } else {
      await enterFullscreen()
    }
  }

  // 重置应用状态
  const resetAppState = (): void => {
    theme.value = 'light'
    language.value = 'zh-CN'
    sidebarCollapsed.value = false
    loading.value = false
    breadcrumbs.value = []
    pageTitle.value = 'Todo List Plus'
    
    // 清除localStorage
    localStorage.removeItem('app_theme')
    localStorage.removeItem('app_language')
    localStorage.removeItem('app_sidebar_collapsed')
    
    // 重新应用主题
    applyTheme()
  }

  // 监听窗口大小变化
  if (typeof window !== 'undefined') {
    window.addEventListener('resize', detectDeviceType)
    
    // 监听全屏状态变化
    document.addEventListener('fullscreenchange', () => {
      isFullscreen.value = !!document.fullscreenElement
    })
  }

  // 监听主题变化
  watch(currentTheme, applyTheme, { immediate: true })

  return {
    // 状态
    theme,
    language,
    sidebarCollapsed,
    loading,
    loadingText,
    isMobile,
    deviceType,
    breadcrumbs,
    pageTitle,
    isOnline,
    isFullscreen,
    
    // 计算属性
    currentTheme,
    appConfig,
    
    // 方法
    initAppState,
    setTheme,
    toggleTheme,
    setLanguage,
    toggleSidebar,
    setSidebarCollapsed,
    showLoading,
    hideLoading,
    setPageTitle,
    setBreadcrumbs,
    detectDeviceType,
    enterFullscreen,
    exitFullscreen,
    toggleFullscreen,
    resetAppState,
  }
})