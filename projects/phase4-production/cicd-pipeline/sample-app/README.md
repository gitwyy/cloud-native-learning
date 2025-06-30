# Sample CI/CD Application

这是一个用于学习和实践 CI/CD 流水线的示例 Node.js 应用程序。

## 🚀 项目概述

这个应用程序演示了现代 CI/CD 流水线的完整实现，包括：

- **自动化测试**：单元测试和覆盖率报告
- **容器化**：Docker 镜像构建和推送
- **安全扫描**：依赖漏洞检测和容器安全扫描
- **部署自动化**：Kubernetes 部署配置
- **监控集成**：健康检查和就绪探针

## 📋 功能特性

### API 端点

| 端点 | 方法 | 描述 |
|------|------|------|
| `/` | GET | 应用程序欢迎页面 |
| `/health` | GET | 健康检查端点 |
| `/ready` | GET | 就绪检查端点 |
| `/api/info` | GET | API 信息和版本 |
| `/api/users` | GET | 获取用户列表 |
| `/api/users` | POST | 创建新用户 |

### 健康检查

应用程序提供了标准的健康检查端点：

- **健康检查** (`/health`)：检查应用程序是否正在运行
- **就绪检查** (`/ready`)：检查应用程序是否准备好接收流量

## 🛠️ 本地开发

### 前置要求

- Node.js 18+ 
- npm 或 yarn
- Docker (可选)

### 安装依赖

```bash
npm install
```

### 运行应用

```bash
# 开发模式
npm run dev

# 生产模式
npm start
```

应用程序将在 http://localhost:3000 启动。

### 运行测试

```bash
# 运行所有测试
npm test

# 运行测试并生成覆盖率报告
npm run test:coverage

# 监听模式运行测试
npm run test:watch
```

## 🐳 Docker 使用

### 构建镜像

```bash
docker build -t sample-app .
```

### 运行容器

```bash
docker run -p 3000:3000 sample-app
```

### 环境变量

| 变量名 | 默认值 | 描述 |
|--------|--------|------|
| `PORT` | 3000 | 应用程序监听端口 |
| `NODE_ENV` | development | 运行环境 |
| `APP_VERSION` | 1.0.0 | 应用程序版本 |

## ☸️ Kubernetes 部署

### 部署到集群

```bash
kubectl apply -f k8s/
```

### 检查部署状态

```bash
kubectl get pods -l app=sample-app
kubectl get services -l app=sample-app
```

### 访问应用

```bash
# 端口转发
kubectl port-forward service/sample-app 3000:80

# 或者获取 LoadBalancer IP
kubectl get service sample-app
```

## 🔄 CI/CD 流水线

### GitHub Actions 工作流

项目使用 GitHub Actions 实现完整的 CI/CD 流水线：

1. **测试阶段**
   - 多版本 Node.js 测试 (18, 20)
   - 单元测试执行
   - 代码覆盖率报告
   - 依赖安全审计

2. **构建阶段**
   - Docker 镜像构建
   - 镜像推送到 GitHub Container Registry
   - 容器安全扫描

3. **部署阶段**
   - 测试环境部署
   - 生产环境部署（需要手动批准）

### 触发条件

- **自动触发**：推送到 main 分支
- **手动触发**：通过 GitHub Actions 界面
- **PR 触发**：创建或更新 Pull Request

## 🧪 测试策略

### 测试类型

- **单元测试**：API 端点功能测试
- **集成测试**：HTTP 请求/响应测试
- **错误处理测试**：异常情况处理验证

### 测试覆盖率

目标覆盖率：> 80%

当前覆盖的功能：
- ✅ 所有 API 端点
- ✅ 错误处理中间件
- ✅ 健康检查端点
- ✅ 用户管理功能

## 🔒 安全考虑

### 实施的安全措施

- **依赖扫描**：npm audit 检查已知漏洞
- **容器扫描**：Trivy 扫描容器镜像
- **最小权限**：Docker 容器使用非 root 用户
- **环境隔离**：敏感配置通过环境变量管理

### 安全最佳实践

- 定期更新依赖包
- 使用官方基础镜像
- 不在代码中硬编码密钥
- 启用 HTTPS（生产环境）

## 📊 监控和日志

### 应用监控

- 健康检查端点用于存活探针
- 就绪检查端点用于就绪探针
- 请求日志记录

### 日志格式

```
2024-01-01T12:00:00.000Z - GET /api/users
```

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📝 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🆘 故障排除

### 常见问题

**Q: 应用启动失败**
A: 检查端口是否被占用，确保 Node.js 版本 >= 18

**Q: 测试失败**
A: 确保所有依赖已安装，运行 `npm ci` 重新安装

**Q: Docker 构建失败**
A: 检查 Dockerfile 语法，确保基础镜像可访问

### 获取帮助

- 查看 [Issues](../../issues) 页面
- 阅读 [CI/CD 最佳实践文档](../docs/)
- 联系项目维护者

---

**注意**：这是一个学习项目，用于演示 CI/CD 流水线的实现。在生产环境中使用前，请确保进行充分的安全审查和性能测试。
