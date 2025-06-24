# Todo List Plus Frontend

基于Vue.js 3的现代化任务管理系统前端应用

## 🚀 技术栈

- **Vue.js 3** - 渐进式JavaScript框架
- **TypeScript** - 类型安全的JavaScript超集
- **Vite** - 快速的前端构建工具
- **Element Plus** - Vue 3 UI组件库
- **Vue Router** - 官方路由管理器
- **Pinia** - Vue 3状态管理库
- **Vue I18n** - 国际化插件
- **Axios** - HTTP客户端
- **SCSS** - CSS预处理器

## 📁 项目结构

```
src/
├── components/           # 可复用组件
│   ├── Layout.vue       # 主布局组件
│   └── NotificationCenter.vue  # 通知中心
├── views/               # 页面组件
│   ├── Login.vue        # 登录页
│   ├── Register.vue     # 注册页
│   ├── Dashboard.vue    # 仪表板
│   ├── TaskManager.vue  # 任务管理
│   ├── TaskDetail.vue   # 任务详情
│   ├── NotificationList.vue # 通知列表
│   ├── Profile.vue      # 个人中心
│   └── error/           # 错误页面
│       ├── 403.vue
│       ├── 404.vue
│       └── 500.vue
├── stores/              # 状态管理
│   ├── auth.ts          # 认证状态
│   ├── tasks.ts         # 任务状态
│   ├── notifications.ts # 通知状态
│   └── app.ts           # 应用全局状态
├── router/              # 路由配置
│   └── index.ts
├── services/            # API服务
│   └── api.ts
├── types/               # TypeScript类型定义
│   └── index.ts
├── assets/              # 静态资源
│   └── styles/          # 样式文件
│       ├── main.scss
│       └── variables.scss
├── locales/             # 国际化语言包
│   ├── zh-CN.json
│   └── en-US.json
├── App.vue              # 根组件
└── main.ts              # 应用入口
```

## 🔧 开发环境

### 安装依赖

```bash
npm install
```

### 启动开发服务器

```bash
npm run dev
```

应用将在 http://localhost:3000 启动

### 构建生产版本

```bash
npm run build
```

### 预览生产构建

```bash
npm run preview
```

## ✨ 主要功能

### 🔐 用户认证
- 用户注册和登录
- JWT Token管理
- 认证状态持久化
- 路由守卫

### 📋 任务管理
- 创建、编辑、删除任务
- 任务状态管理（待办、进行中、已完成）
- 任务优先级设置
- 任务统计和图表

### 🔔 通知系统
- 实时通知推送
- 通知状态管理
- 通知历史记录

### 🎨 用户体验
- 响应式设计
- 深色/浅色主题切换
- 多语言支持（中文/英文）
- 加载状态和错误处理

## 🌐 API集成

应用配置了API代理，所有以 `/api` 开头的请求将被代理到后端服务（默认端口8000）。

### 认证API
- `POST /api/auth/login` - 用户登录
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/logout` - 用户登出
- `GET /api/auth/me` - 获取当前用户信息

### 任务API
- `GET /api/tasks` - 获取任务列表
- `POST /api/tasks` - 创建任务
- `PUT /api/tasks/:id` - 更新任务
- `DELETE /api/tasks/:id` - 删除任务

### 通知API
- `GET /api/notifications` - 获取通知列表
- `PUT /api/notifications/:id/read` - 标记通知为已读

## 🔗 路由结构

```
/                    # 仪表板
/login              # 登录页
/register           # 注册页
/tasks              # 任务管理
/tasks/:id          # 任务详情
/notifications      # 通知列表
/profile            # 个人中心
/403                # 权限不足
/404                # 页面未找到
/500                # 服务器错误
```

## 🏗️ 状态管理

使用Pinia进行状态管理，主要包含以下Store：

- **authStore** - 用户认证状态
- **tasksStore** - 任务数据管理
- **notificationsStore** - 通知状态
- **appStore** - 应用全局状态（主题、语言等）

## 🎨 样式系统

- 使用SCSS预处理器
- CSS变量支持主题切换
- Element Plus主题定制
- 响应式断点管理

## 📱 响应式设计

支持多种设备尺寸：
- 移动设备 (<768px)
- 平板设备 (768px-1024px)
- 桌面设备 (>1024px)

## 🌍 国际化

支持中英文切换：
- 简体中文 (zh-CN)
- 英文 (en-US)

## 🚢 部署

### Docker部署

```bash
# 构建镜像
docker build -t todo-frontend .

# 运行容器
docker run -p 3000:80 todo-frontend
```

### 环境变量

- `VITE_API_BASE_URL` - API基础URL
- `VITE_APP_TITLE` - 应用标题

## 🔍 开发工具

- **ESLint** - 代码质量检查
- **Prettier** - 代码格式化
- **TypeScript** - 类型检查
- **Vite** - 开发服务器和构建工具

## 📄 许可证

MIT License