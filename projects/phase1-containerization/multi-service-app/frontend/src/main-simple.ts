import { createApp } from 'vue'

const app = createApp({
  template: `
    <div style="padding: 20px; text-align: center;">
      <h1>🚀 Todo List Plus</h1>
      <p>Vue.js应用正在运行中...</p>
      <p>当前时间: {{ new Date().toLocaleString() }}</p>
    </div>
  `
})

app.mount('#app')