# 微服务Kubernetes部署项目

## 🎯 项目概述

本项目是云原生学习路径第二阶段的核心项目，展示如何将完整的微服务应用部署到Kubernetes集群。项目基于第一阶段的电商微服务应用，实现了从Docker Compose到Kubernetes的完整迁移。

### 核心目标
- **微服务编排**：将4个微服务（用户、商品、订单、通知）部署到Kubernetes
- **服务治理**：实现服务发现、负载均衡、健康检查
- **配置管理**：使用ConfigMap和Secret管理应用配置
- **数据持久化**：使用PersistentVolume存储数据库数据
- **网络管理**：通过Service和Ingress暴露服务
- **运维自动化**：提供部署、监控、扩缩容脚本

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Ingress Controller                       │
│                     (nginx-ingress)                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────────────┐
│                   API Gateway Service                          │
│                    (Nginx Pods)                               │
└─────┬─────────┬─────────┬─────────┬─────────────────────────────┘
      │         │         │         │
      ▼         ▼         ▼         ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│   用户    │ │   商品    │ │   订单    │ │   通知    │
│   服务    │ │   服务    │ │   服务    │ │   服务    │
│ (2 Pods) │ │ (2 Pods) │ │ (2 Pods) │ │ (1 Pod)  │
└─────┬────┘ └─────┬────┘ └─────┬────┘ └─────┬────┘
      │            │            │            │
      └────────────┴────────────┴────────────┘
                              │
      ┌─────────────────────────┴─────────────────────────┐
      │                基础设施层                          │
      │  ┌──────────┐ ┌──────────┐ ┌──────────┐          │
      │  │PostgreSQL│ │  Redis   │ │ RabbitMQ │          │
      │  │(1 Pod)   │ │ (1 Pod)  │ │ (1 Pod)  │          │
      │  └────┬─────┘ └──────────┘ └──────────┘          │
      │       │                                          │
      │  ┌────┴─────┐                                    │
      │  │    PVC   │  (持久化存储)                        │
      │  └──────────┘                                    │
      └─────────────────────────────────────────────────┘
```

## 📁 项目结构

```
microservices-k8s/
├── README.md                          # 项目说明
├── DEPLOYMENT_GUIDE.md                # 部署指南
├── Makefile                           # 项目管理
├── scripts/
│   └── deploy.sh                      # 自动化部署
├── k8s/
│   ├── namespace/                     # 命名空间
│   ├── secrets/                       # 密钥配置
│   ├── configmaps/                    # 配置映射
│   ├── storage/                       # 存储配置
│   ├── infrastructure/                # 基础设施
│   │   ├── postgres.yaml              # PostgreSQL
│   │   └── redis.yaml                 # Redis
│   ├── microservices/                 # 微服务
│   │   └── user-service.yaml          # 用户服务
│   └── gateway/                       # API网关
│       └── api-gateway.yaml           # Nginx网关
└── docs/                              # 文档目录
```

## 🚀 快速开始

### 前置条件
- Kubernetes集群 (Minikube/Kind/云服务商K8s)
- kubectl命令行工具
- Docker (用于构建镜像)
- 第一阶段ecommerce-basic项目镜像

### 一键部署
```bash
# 1. 克隆项目到本地
cd projects/phase2-orchestration/microservices-k8s

# 2. 构建第一阶段镜像 (如果还没有)
make build-images

# 3. 部署到Kubernetes
make deploy

# 4. 检查部署状态
make status

# 5. 访问应用
make get-url
```

### 手动部署步骤
```bash
# 1. 创建命名空间和基础配置
kubectl apply -f k8s/namespace/
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# 2. 部署存储和基础设施
kubectl apply -f k8s/storage/
kubectl apply -f k8s/infrastructure/

# 3. 等待基础设施就绪
kubectl wait --for=condition=ready pod -l tier=infrastructure -n ecommerce-k8s --timeout=300s

# 4. 部署微服务
kubectl apply -f k8s/microservices/

# 5. 部署网关和Ingress
kubectl apply -f k8s/gateway/
kubectl apply -f k8s/ingress/

# 6. 验证部署
kubectl get all -n ecommerce-k8s
```

## 🔧 运维管理

### 扩缩容操作
```bash
# 扩容用户服务到5个副本
./scripts/scale.sh user-service 5

# 扩容所有服务
make scale-all replicas=3

# 查看当前副本数
kubectl get deployments -n ecommerce-k8s
```

### 滚动更新
```bash
# 更新用户服务镜像
kubectl set image deployment/user-service user-service=user-service:v2.0 -n ecommerce-k8s

# 查看更新状态
kubectl rollout status deployment/user-service -n ecommerce-k8s

# 回滚更新
kubectl rollout undo deployment/user-service -n ecommerce-k8s
```

### 监控和日志
```bash
# 查看所有服务日志
./scripts/logs.sh

# 查看特定服务日志
./scripts/logs.sh user-service

# 健康检查
./scripts/health-check.sh

# 查看资源使用情况
kubectl top pods -n ecommerce-k8s
```

## 🌐 服务访问

### 本地开发环境 (Minikube)
```bash
# 获取API网关访问地址
minikube service api-gateway -n ecommerce-k8s --url

# 或使用端口转发
kubectl port-forward service/api-gateway 8080:80 -n ecommerce-k8s
```

### 生产环境 (Ingress)
```bash
# 配置域名解析后访问
https://ecommerce.yourdomain.com

# 或使用NodePort
http://<节点IP>:30080
```

### API端点
- **用户服务**: `/api/v1/users/*`
- **商品服务**: `/api/v1/products/*`, `/api/v1/categories/*`
- **订单服务**: `/api/v1/orders/*`
- **通知服务**: `/api/v1/notifications/*`, `/api/v1/templates/*`

## 📊 监控和可观测性

### 健康检查端点
- **API网关**: `/health`
- **各微服务**: `/health`
- **基础设施**: 通过存活和就绪探针

### 关键指标监控
- **Pod状态**: Running/Pending/Failed
- **服务可用性**: EndPoints状态
- **资源使用**: CPU/内存使用率
- **网络状态**: 服务间连通性

### 日志聚合
- **应用日志**: 通过kubectl logs收集
- **系统日志**: 集群级别事件监控
- **审计日志**: API调用追踪

## 🔐 安全配置

### 密钥管理
- **数据库密码**: 通过Secret管理
- **API密钥**: 加密存储
- **证书**: TLS证书自动管理

### 网络安全
- **网络策略**: 限制Pod间通信
- **Ingress TLS**: HTTPS加密传输
- **RBAC**: 基于角色的访问控制

### 镜像安全
- **镜像扫描**: 安全漏洞检测
- **私有仓库**: 镜像访问控制
- **镜像签名**: 完整性验证

## 📈 性能优化

### 资源配置
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### 水平自动扩缩容 (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 负载测试
```bash
# 运行负载测试
./tests/load-tests.sh

# 压力测试API网关
kubectl run load-test --image=busybox --rm -it --restart=Never -- sh
```

## 🛠️ 管理工具

### 部署脚本
```bash
# 完整部署
./scripts/deploy.sh

# 清理环境
./scripts/deploy.sh --cleanup
```

### 运维脚本
```bash
# 健康检查
./scripts/health-check.sh

# 日志管理
./scripts/logs.sh user                    # 查看用户服务日志
./scripts/logs.sh -f all                  # 实时跟踪所有服务日志
./scripts/logs.sh -l 100 product          # 查看商品服务最后100行日志

# 扩缩容管理
./scripts/scale.sh user 3                 # 手动扩容用户服务到3个副本
./scripts/scale.sh -a user --min 2 --max 10  # 启用自动扩缩容
./scripts/scale.sh all 2                  # 扩容所有服务到2个副本
```

### 测试工具
```bash
# API功能测试
./tests/api-tests.sh                      # 运行完整API测试
./tests/api-tests.sh -v                   # 详细模式
./tests/api-tests.sh -u http://localhost:8080  # 指定测试URL

# 负载测试
./tests/load-tests.sh                     # 基础负载测试
./tests/load-tests.sh -s stress           # 压力测试
./tests/load-tests.sh -c 50 -n 1000       # 自定义并发和请求数
```

## 🐛 故障排查

### 常见问题

#### Pod无法启动
```bash
# 查看Pod状态
kubectl describe pod <pod-name> -n ecommerce-k8s

# 查看Pod日志
kubectl logs <pod-name> -n ecommerce-k8s

# 检查镜像拉取
kubectl get events -n ecommerce-k8s
```

#### 服务无法访问
```bash
# 检查Service端点
kubectl get endpoints -n ecommerce-k8s

# 检查网络策略
kubectl get networkpolicies -n ecommerce-k8s

# 测试服务连通性
kubectl exec -it <pod-name> -n ecommerce-k8s -- curl http://service-name
```

#### 存储问题
```bash
# 检查PVC状态
kubectl get pvc -n ecommerce-k8s

# 查看存储事件
kubectl describe pvc <pvc-name> -n ecommerce-k8s

# 检查存储类
kubectl get storageclass
```

## 📚 文档资源

### 项目文档
- [部署指南](DEPLOYMENT_GUIDE.md) - 详细的部署步骤和配置说明
- [故障排查指南](TROUBLESHOOTING.md) - 常见问题诊断和解决方案
- [API参考文档](docs/API_REFERENCE.md) - 完整的API接口文档
- [运维手册](docs/OPERATIONS_MANUAL.md) - 日常运维操作指南

### 官方文档
- [Kubernetes官方文档](https://kubernetes.io/docs/)
- [kubectl命令参考](https://kubernetes.io/docs/reference/kubectl/)

### 最佳实践
- [Kubernetes应用部署最佳实践](https://kubernetes.io/docs/concepts/configuration/)
- [微服务架构设计模式](https://microservices.io/)

### 进阶学习
- Helm包管理器
- Istio服务网格
- Prometheus + Grafana监控
- GitOps部署流程

## 🤝 贡献指南

1. Fork项目仓库
2. 创建功能分支 (`git checkout -b feature/new-feature`)
3. 提交变更 (`git commit -am 'Add new feature'`)
4. 推送分支 (`git push origin feature/new-feature`)
5. 创建Pull Request

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🆘 支持

如遇问题，请查看：
1. [故障排查指南](TROUBLESHOOTING.md) - 常见问题的诊断和解决方案
2. [运维手册](docs/OPERATIONS_MANUAL.md) - 日常运维操作指导
3. [API文档](docs/API_REFERENCE.md) - 接口使用说明
---

**⭐ 如果这个项目对你有帮助，请给个Star支持！**