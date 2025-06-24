# 电商应用基础版

## 项目概述

这是一个基于微服务架构的电商应用基础版，采用容器化部署方式。项目包含用户注册、商品展示、下单支付等核心功能，为后续的云原生改造奠定基础。

## 项目目标

### 核心功能
- **用户注册登录**：用户可以注册账号、登录系统、管理个人信息
- **商品展示**：展示商品列表、商品详情、商品搜索和分类
- **下单支付**：用户可以添加商品到购物车、创建订单、完成支付流程

### 技术目标
- 采用微服务架构设计，服务间解耦
- 使用容器化技术进行部署和管理
- 实现服务间异步通信和数据一致性
- 建立可扩展的系统架构

## 系统架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   用户服务      │    │   商品服务      │    │   订单服务      │    │   通知服务      │
│  (User Service) │    │(Product Service)│    │ (Order Service) │    │(Notification    │
│     :5001       │    │     :5002       │    │     :5003       │    │   Service)      │
│                 │    │                 │    │                 │    │     :5004       │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         └───────────────────────┼───────────────────────┼───────────────────────┘
                                 │                       │
         ┌───────────────────────┼───────────────────────┼───────────────────────┐
         │                       │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │     Redis       │    │   RabbitMQ      │    │     Nginx       │
│   (Database)    │    │   (Cache)       │    │ (Message Queue) │    │ (Load Balancer) │
│     :5432       │    │     :6379       │    │     :5672       │    │     :80/:443    │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 服务说明

### 微服务组件

| 服务名称 | 端口 | 功能描述 | 技术栈 |
|---------|------|----------|--------|
| **用户服务** | 5001 | 用户注册、登录、认证、个人信息管理 | Python Flask + SQLAlchemy |
| **商品服务** | 5002 | 商品管理、库存管理、商品搜索 | Python Flask + SQLAlchemy |
| **订单服务** | 5003 | 订单创建、支付处理、订单状态管理 | Python Flask + SQLAlchemy |
| **通知服务** | 5004 | 邮件通知、短信通知、推送通知 | Python Flask + Celery |

### 基础设施服务

| 服务名称 | 端口 | 功能描述 | 版本 |
|---------|------|----------|------|
| **PostgreSQL** | 5432 | 主数据库，存储业务数据 | 15-alpine |
| **Redis** | 6379 | 缓存服务，会话存储 | 7-alpine |
| **RabbitMQ** | 5672/15672 | 消息队列，异步通信 | 3.12-management |
| **Nginx** | 80/443 | 反向代理，负载均衡 | alpine |

## 目录结构

```
ecommerce-basic/
├── user-service/              # 用户管理服务
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   └── ...
├── product-service/           # 商品管理服务
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   └── ...
├── order-service/             # 订单服务
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   └── ...
├── notification-service/      # 通知服务
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   └── ...
├── nginx/                     # Nginx配置
│   ├── nginx.conf
│   └── conf.d/
├── database/                  # 数据库初始化脚本
│   └── init-scripts/
├── data/                      # 数据持久化目录
│   ├── postgres/
│   ├── redis/
│   └── rabbitmq/
├── logs/                      # 日志目录
├── docker-compose.yml         # Docker编排文件
├── .env.example              # 环境变量示例
└── README.md                 # 项目说明文档
```

## 快速开始

### 前置要求

- Docker >= 20.10
- Docker Compose >= 2.0
- 至少 4GB 可用内存
- 至少 10GB 可用磁盘空间

### 安装部署

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd ecommerce-basic
   ```

2. **配置环境变量**
   ```bash
   cp .env.example .env
   # 编辑 .env 文件，设置数据库密码、API密钥等
   ```

3. **创建必要目录**
   ```bash
   mkdir -p data/{postgres,redis,rabbitmq}
   mkdir -p logs/{user-service,product-service,order-service,notification-service,nginx}
   mkdir -p database/init-scripts
   mkdir -p nginx/conf.d
   ```

4. **启动服务**
   ```bash
   # 构建并启动所有服务
   docker-compose up -d

   # 查看服务状态
   docker-compose ps

   # 查看日志
   docker-compose logs -f
   ```

### 访问服务

- **应用入口（Nginx）**: http://localhost
- **用户服务**: http://localhost:5001
- **商品服务**: http://localhost:5002
- **订单服务**: http://localhost:5003
- **通知服务**: http://localhost:5004
- **RabbitMQ管理界面**: http://localhost:15672 (admin/rabbitmq123)

### 停止服务

```bash
# 停止所有服务
docker-compose down

# 停止并删除数据卷（注意：会丢失数据）
docker-compose down -v
```

## 开发指南

### API接口

#### 用户服务 API

- `POST /api/v1/register` - 用户注册
- `POST /api/v1/login` - 用户登录
- `GET /api/v1/profile` - 获取用户信息
- `PUT /api/v1/profile` - 更新用户信息

#### 商品服务 API

- `GET /api/v1/products` - 获取商品列表
- `GET /api/v1/products/{id}` - 获取商品详情
- `POST /api/v1/products` - 创建商品（管理员）
- `PUT /api/v1/products/{id}` - 更新商品（管理员）

#### 订单服务 API

- `POST /api/v1/orders` - 创建订单
- `GET /api/v1/orders` - 获取用户订单列表
- `GET /api/v1/orders/{id}` - 获取订单详情
- `POST /api/v1/orders/{id}/pay` - 支付订单

#### 通知服务 API

- `POST /api/v1/notifications/email` - 发送邮件
- `POST /api/v1/notifications/sms` - 发送短信
- `GET /api/v1/notifications/history` - 获取通知历史

### 数据库设计

#### 用户表 (users)
- id (主键)
- username (用户名)
- email (邮箱)
- password_hash (密码哈希)
- created_at (创建时间)
- updated_at (更新时间)

#### 商品表 (products)
- id (主键)
- name (商品名称)
- description (商品描述)
- price (价格)
- stock (库存)
- category_id (分类ID)
- created_at (创建时间)

#### 订单表 (orders)
- id (主键)
- user_id (用户ID)
- total_amount (总金额)
- status (订单状态)
- created_at (创建时间)
- payment_time (支付时间)

### 消息队列设计

#### 队列列表
- `user.events` - 用户相关事件
- `product.events` - 商品相关事件
- `order.events` - 订单相关事件
- `notification.tasks` - 通知任务队列

#### 事件类型
- `user.registered` - 用户注册事件
- `order.created` - 订单创建事件
- `order.paid` - 订单支付事件
- `product.stock.updated` - 库存更新事件

## 监控与运维

### 健康检查

每个服务都提供健康检查端点：
- `GET /health` - 服务健康状态

### 日志管理

日志文件存储在 `logs/` 目录下：
- 应用日志：`logs/{service-name}/app.log`
- 访问日志：`logs/nginx/access.log`
- 错误日志：`logs/nginx/error.log`

### 性能指标

推荐监控指标：
- 响应时间
- 请求量 (QPS)
- 错误率
- 资源使用率 (CPU/内存)
- 数据库连接数

## 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tulpn | grep :5432
   
   # 修改 docker-compose.yml 中的端口映射
   ```

2. **内存不足**
   ```bash
   # 检查容器资源限制
   docker stats
   
   # 调整 docker-compose.yml 中的 resource limits
   ```

3. **数据库连接失败**
   ```bash
   # 检查 PostgreSQL 服务状态
   docker-compose logs postgres
   
   # 检查网络连接
   docker-compose exec user-service ping postgres
   ```

### 调试命令

```bash
# 进入容器调试
docker-compose exec user-service bash

# 查看服务日志
docker-compose logs -f user-service

# 重启特定服务
docker-compose restart user-service

# 检查网络
docker network ls
docker network inspect ecommerce-network
```

## 后续发展

### Phase 2: Kubernetes 部署
- 将 Docker Compose 配置转换为 Kubernetes 清单
- 实现服务的自动扩缩容
- 添加 Ingress 控制器和服务网格

### Phase 3: 云原生特性
- 集成配置管理 (ConfigMap/Secret)
- 添加分布式追踪 (Jaeger)
- 实现可观测性 (Prometheus + Grafana)

### Phase 4: 高级功能
- 实现 CQRS 和事件溯源
- 添加 API 网关
- 集成 CI/CD 流水线

## 贡献指南

1. Fork 项目仓库
2. 创建功能分支 (`git checkout -b feature/new-feature`)
3. 提交变更 (`git commit -am 'Add new feature'`)
4. 推送分支 (`git push origin feature/new-feature`)
5. 创建 Pull Request

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 联系我们

- 项目维护者：Cloud Native Team
- 邮箱：team@cloudnative.dev
- 问题反馈：[GitHub Issues](https://github.com/your-org/ecommerce-basic/issues)