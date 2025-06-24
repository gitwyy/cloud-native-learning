import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'
import { createI18n } from 'vue-i18n'

import App from './App.vue'
import router from './router/simple'

// 暂时注释掉Sass样式文件，避免构建错误
// import './assets/styles/variables.scss'
// import './assets/styles/main.scss'

// 国际化配置
import zhCN from './locales/zh-CN.json'
import enUS from './locales/en-US.json'

// 创建应用实例
const app = createApp(App)

// 创建Pinia状态管理
const pinia = createPinia()
app.use(pinia)

// 创建国际化
const i18n = createI18n({
  legacy: false,
  locale: 'zh-CN',
  fallbackLocale: 'en-US',
  messages: {
    'zh-CN': zhCN,
    'en-US': enUS,
  },
})
app.use(i18n)

// 使用Element Plus
app.use(ElementPlus)

// 注册所有图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component)
}

// 使用路由
app.use(router)

// 全局错误处理
app.config.errorHandler = (err, vm, info) => {
  console.error('Global error:', err, info)
}

// 挂载应用
app.mount('#app')