# 🚀 多服务任务管理应用 - Todo List Plus

> 第一阶段第2周项目：基于Docker Compose的多容器编排实践

## 🎯 项目概述

**项目名称**: Todo List Plus - 云原生任务管理系统  
**技术栈**: Vue.js + Python FastAPI + PostgreSQL + Redis + Nginx  
**学习目标**: Docker Compose多容器编排、服务间通信、数据持久化

## 🏗️ 系统架构图

```mermaid
graph TB
    subgraph "外部访问层"
        Internet[Internet] --> LB[Nginx 负载均衡器]
    end
    
    subgraph "前端层"
        LB --> Frontend[Vue.js 前端应用]
    end
    
    subgraph "API网关层"
        LB --> API[FastAPI 后端服务]
    end
    
    subgraph "业务服务层"
        API --> AuthSvc[认证服务]
        API --> TaskSvc[任务服务]
        API --> NotificationSvc[通知服务]
    end
    
    subgraph "数据存储层"
        AuthSvc --> DB[(PostgreSQL 数据库)]
        TaskSvc --> DB
        TaskSvc --> Cache[(Redis 缓存)]
        NotificationSvc --> Queue[(Redis 消息队列)]
    end
    
    
    style Internet fill:#e1f5fe
    style LB fill:#f3e5f5
    style Frontend fill:#e8f5e8
    style API fill:#fff3e0
    style DB fill:#fce4ec
    style Cache fill:#f1f8e9
    style Queue fill:#f1f8e9
```

## 📁 项目目录结构

```
projects/phase1-containerization/multi-service-app/
├── README.md                           # 项目说明文档
├── .env.example                        # 环境变量模板
├── .env.development                    # 开发环境配置
├── .env.production                     # 生产环境配置
├── docker-compose.yml                  # 主要编排文件
├── docker-compose.override.yml         # 开发环境覆盖配置
├── docker-compose.prod.yml             # 生产环境配置
├── .dockerignore                       # Docker忽略文件
├── Makefile                           # 便捷操作命令
│
├── frontend/                           # Vue.js 前端应用
│   ├── Dockerfile                      # 前端容器配置
│   ├── nginx.conf                      # 前端Nginx配置
│   ├── package.json
│   ├── vite.config.js
│   ├── src/
│   │   ├── main.js
│   │   ├── App.vue
│   │   ├── components/
│   │   │   ├── TaskList.vue
│   │   │   ├── TaskForm.vue
│   │   │   ├── UserAuth.vue
│   │   │   └── Notifications.vue
│   │   ├── views/
│   │   │   ├── Dashboard.vue
│   │   │   ├── Login.vue
│   │   │   └── Profile.vue
│   │   ├── store/
│   │   │   ├── index.js
│   │   │   ├── modules/
│   │   │   │   ├── auth.js
│   │   │   │   ├── tasks.js
│   │   │   │   └── notifications.js
│   │   └── services/
│   │       └── api.js
│   └── public/
│       └── index.html
│
├── backend/                            # Python FastAPI 后端
│   ├── Dockerfile                      # 后端容器配置
│   ├── requirements.txt                # Python依赖
│   ├── alembic.ini                     # 数据库迁移配置
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                     # FastAPI应用入口
│   │   ├── config.py                   # 配置管理
│   │   ├── database.py                 # 数据库连接
│   │   ├── models/                     # 数据模型
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── task.py
│   │   │   └── notification.py
│   │   ├── schemas/                    # Pydantic模式
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── task.py
│   │   │   └── response.py
│   │   ├── api/                        # API路由
│   │   │   ├── __init__.py
│   │   │   ├── v1/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── auth.py
│   │   │   │   ├── tasks.py
│   │   │   │   ├── users.py
│   │   │   │   └── notifications.py
│   │   ├── core/                       # 核心功能
│   │   │   ├── __init__.py
│   │   │   ├── security.py
│   │   │   ├── cache.py
│   │   │   └── tasks.py
│   │   ├── services/                   # 业务逻辑
│   │   │   ├── __init__.py
│   │   │   ├── auth_service.py
│   │   │   ├── task_service.py
│   │   │   └── notification_service.py
│   │   └── utils/
│   │       ├── __init__.py
│   │       ├── logger.py
│   │       └── helpers.py
│   ├── alembic/                        # 数据库迁移
│   │   ├── versions/
│   │   └── env.py
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py
│       ├── test_auth.py
│       ├── test_tasks.py
│       └── test_api.py
│
├── nginx/                              # Nginx配置
│   ├── Dockerfile                      # 自定义Nginx镜像
│   ├── nginx.conf                      # 主配置文件
│   ├── conf.d/
│   │   ├── default.conf                # 默认站点配置
│   │   └── upstream.conf               # 上游服务配置
│   └── ssl/                            # SSL证书目录
│       ├── cert.pem
│       └── key.pem
│
├── database/                           # 数据库相关
│   ├── init-scripts/                   # 初始化脚本
│   │   ├── 001-create-database.sql
│   │   └── 002-create-extensions.sql
│   ├── migrations/                     # 迁移文件
│   └── seeds/                          # 种子数据
│       └── sample_data.sql
│
├── redis/                              # Redis配置
│   ├── redis.conf                      # Redis配置文件
│   └── redis-cluster.conf              # 集群配置（可选）
│
│
├── logs/                               # 日志目录
│   ├── nginx/
│   ├── backend/
│   └── database/
│
├── data/                               # 数据持久化目录
│   ├── postgres/
│   ├── redis/
│   └── uploads/
│
├── backups/                            # 备份目录
│   ├── database/
│   └── redis/
│
└── docs/                               # 项目文档
    ├── api.md                          # API文档
    ├── deployment.md                   # 部署指南
    ├── architecture.md                 # 架构说明
    └── troubleshooting.md              # 故障排除
```

## 🐳 Docker容器架构

```mermaid
graph LR
    subgraph "Docker Host"
        subgraph "todo-network"
            Frontend[Frontend Container<br/>Vue.js + Nginx<br/>Port: 3000]
            Backend[Backend Container<br/>FastAPI + Gunicorn<br/>Port: 8000]
            Database[Database Container<br/>PostgreSQL 15<br/>Port: 5432]
            Cache[Cache Container<br/>Redis 7<br/>Port: 6379]
            Proxy[Proxy Container<br/>Nginx<br/>Port: 80/443]
        end
        
        subgraph "Volumes"
            V1[postgres_data]
            V2[redis_data]
            V3[static_files]
            V4[logs]
        end
    end
    
    Database -.-> V1
    Cache -.-> V2
    Frontend -.-> V3
    Proxy -.-> V4
    
    Proxy --> Frontend
    Proxy --> Backend
    Backend --> Database
    Backend --> Cache
```

## ⚙️ 核心服务配置

### 1. **前端服务 (Vue.js)**
- **框架**: Vue 3 + Vite
- **UI库**: Element Plus
- **状态管理**: Pinia
- **路由**: Vue Router
- **HTTP客户端**: Axios
- **容器**: Nginx Alpine
- **端口**: 3000

### 2. **后端服务 (FastAPI)**
- **框架**: FastAPI + Uvicorn/Gunicorn
- **ORM**: SQLAlchemy 2.0
- **认证**: JWT + OAuth2
- **文档**: 自动生成 OpenAPI
- **容器**: Python 3.11 Alpine
- **端口**: 8000

### 3. **数据库服务 (PostgreSQL)**
- **版本**: PostgreSQL 15
- **连接池**: pgbouncer
- **备份**: 定时备份策略
- **监控**: pg_stat_statements
- **端口**: 5432

### 4. **缓存服务 (Redis)**
- **版本**: Redis 7
- **用途**: 缓存 + 会话 + 消息队列
- **持久化**: AOF + RDB
- **配置**: 密码保护
- **端口**: 6379

### 5. **代理服务 (Nginx)**
- **功能**: 反向代理 + 负载均衡
- **SSL**: Let's Encrypt
- **压缩**: Gzip
- **静态文件**: 直接服务
- **端口**: 80/443

## 🔗 服务间通信架构

### 网络通信流程：
```mermaid
sequenceDiagram
    participant U as 用户浏览器
    participant N as Nginx代理
    participant F as Vue.js前端
    participant A as FastAPI后端
    participant R as Redis缓存
    participant D as PostgreSQL

    U->>N: HTTP请求
    N->>F: 路由到前端 (静态资源)
    F->>N: API请求
    N->>A: 转发到后端API
    A->>R: 检查缓存
    alt 缓存命中
        R-->>A: 返回缓存数据
    else 缓存未命中
        A->>D: 查询数据库
        D-->>A: 返回数据
        A->>R: 写入缓存
    end
    A-->>N: 返回API响应
    N-->>F: 转发响应
    F-->>U: 渲染页面
```

## 🔧 Docker Compose配置策略

### **主配置文件** (`docker-compose.yml`)
```yaml
version: '3.8'

services:
  # Vue.js 前端服务
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      target: production
    container_name: todo-frontend
    restart: unless-stopped
    volumes:
      - static_files:/app/dist
    networks:
      - todo-network
    depends_on:
      - backend

  # FastAPI 后端服务
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: todo-backend
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD}@database:5432/${DB_NAME}
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=${SECRET_KEY}
    env_file:
      - .env
    volumes:
      - ./logs/backend:/app/logs
      - ./data/uploads:/app/uploads
    networks:
      - todo-network
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # PostgreSQL 数据库服务
  database:
    image: postgres:15-alpine
    container_name: todo-database
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init-scripts:/docker-entrypoint-initdb.d:ro
    networks:
      - todo-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis 缓存服务
  redis:
    image: redis:7-alpine
    container_name: todo-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf:ro
    networks:
      - todo-network
    healthcheck:
      test: ["CMD", "redis-cli", "auth", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  # Nginx 反向代理
  nginx:
    build:
      context: ./nginx
      dockerfile: Dockerfile
    container_name: todo-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./logs/nginx:/var/log/nginx
      - static_files:/var/www/static:ro
    networks:
      - todo-network
    depends_on:
      - frontend
      - backend

networks:
  todo-network:
    driver: bridge
    name: todo-network

volumes:
  postgres_data:
  redis_data:
  static_files:
```

## 💾 数据持久化方案

### **数据卷策略**：
1. **数据库数据**: Named Volume (`postgres_data`)
2. **Redis数据**: Named Volume (`redis_data`) 
3. **文件上传**: Bind Mount (`./data/uploads`)
4. **日志文件**: Bind Mount (`./logs`)
5. **静态文件**: Named Volume (`static_files`)

### **备份策略**：
```bash
# 数据库备份
docker exec todo-database pg_dump -U postgres todo_db > backups/db_$(date +%Y%m%d_%H%M%S).sql

# Redis备份
docker exec todo-redis redis-cli --rdb /data/dump.rdb
```

## 🌍 环境配置差异

### **开发环境** (`.env.development`)
```env
# 项目配置
PROJECT_NAME=todo-dev
NODE_ENV=development
DEBUG=true

# 数据库配置
DB_NAME=todo_dev
DB_USER=postgres
DB_PASSWORD=dev123
DB_HOST=localhost
DB_PORT=5432

# Redis配置
REDIS_PASSWORD=redis_dev
REDIS_HOST=localhost

# API配置
API_URL=http://localhost:8000
FRONTEND_URL=http://localhost:3000

# 热重载
HOT_RELOAD=true
```

### **生产环境** (`.env.production`)
```env
# 项目配置
PROJECT_NAME=todo-prod
NODE_ENV=production
DEBUG=false

# 数据库配置
DB_NAME=todo_production
DB_USER=todo_user
DB_PASSWORD=super_secure_password_123
DB_HOST=database
DB_PORT=5432

# Redis配置
REDIS_PASSWORD=redis_secure_pass_456
REDIS_HOST=redis

# SSL配置
SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
SSL_KEY_PATH=/etc/nginx/ssl/key.pem

# 安全配置
SECRET_KEY=production_jwt_secret_key_very_long
CORS_ORIGINS=https://yourdomain.com
```

## 📊 核心功能设计

### **1. 用户认证系统**
- JWT Token认证
- 用户注册/登录
- 密码加密存储
- 会话管理

### **2. 任务管理功能**
- 任务CRUD操作
- 任务状态管理
- 任务分类和标签
- 任务搜索和过滤

### **3. 实时通知系统**
- WebSocket连接
- 任务状态变更通知
- 系统消息推送
- 邮件通知（可选）

### **4. 缓存策略**
- 用户会话缓存
- 热点数据缓存
- API响应缓存
- 静态资源缓存

## 🚀 部署和开发工作流

### **快速启动命令**：
```bash
# 开发环境启动
make dev-up

# 生产环境启动  
make prod-up

# 查看服务状态
make status

# 查看日志
make logs

# 数据库迁移
make migrate

# 运行测试
make test
```

### **Makefile 示例**：
```makefile
.PHONY: dev-up prod-up down status logs clean

# 开发环境
dev-up:
	docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d

# 生产环境
prod-up:
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 停止所有服务
down:
	docker-compose down

# 查看服务状态
status:
	docker-compose ps

# 查看日志
logs:
	docker-compose logs -f

# 清理资源
clean:
	docker-compose down -v
	docker system prune -f
```

## 🔍 学习检查点

完成本项目后，您应该掌握：

- [ ] Docker Compose多服务编排
- [ ] 自定义网络配置和服务间通信
- [ ] 数据卷持久化和备份策略
- [ ] 环境变量和配置管理
- [ ] 健康检查
- [ ] 前后端分离架构设计
- [ ] API设计和文档生成
- [ ] 容器化最佳实践

## 📚 扩展学习

### **进阶功能**：
1. **监控和日志**: Prometheus + Grafana + ELK
2. **消息队列**: Redis Pub/Sub 或 RabbitMQ
3. **API网关**: Kong 或 Traefik
4. **服务发现**: Consul 或 etcd
5. **负载测试**: K6 或 JMeter

### **云原生进阶**：
1. **Kubernetes部署**: 为第二阶段做准备
2. **Helm Chart**: 应用打包和版本管理
3. **CI/CD集成**: GitLab CI 或 GitHub Actions
4. **安全扫描**: Container security scanning

---

## 🎉 开始实现

这个架构设计充分体现了Docker Compose多容器编排的核心概念：

✅ **服务间通信**: 通过自定义网络实现安全通信  
✅ **数据持久化**: 多种数据卷策略确保数据安全  
✅ **环境配置**: 开发和生产环境分离  
✅ **健康检查**: 完善的健康监控机制  
✅ **扩展性**: 易于添加新服务和功能  
✅ **最佳实践**: 遵循Docker和云原生最佳实践  

**准备好开始编码了吗？** 让我们切换到实现模式，逐步构建这个多服务应用！ 🚀