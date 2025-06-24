# 微服务Kubernetes部署指南

## 📋 概述

本指南详细说明如何将电商微服务应用部署到Kubernetes集群。项目采用现代化的云原生架构，包含完整的微服务生态系统。

## 🎯 部署目标

- **微服务架构**: 4个独立的微服务（用户、商品、订单、通知）
- **基础设施**: PostgreSQL、Redis、RabbitMQ
- **API网关**: Nginx负载均衡和路由
- **高可用性**: 多副本、健康检查、自动扩缩容
- **数据持久化**: PVC存储数据库和文件
- **安全配置**: Secret管理、网络策略

## 🔧 前置条件

### 系统要求
- **Kubernetes集群**: v1.20+
- **kubectl**: 配置并连接到集群
- **Docker**: 用于构建镜像
- **资源需求**: 最少4GB内存，2CPU核心

### 支持的部署环境
- **本地开发**: Minikube、Kind、Docker Desktop
- **云平台**: GKE、EKS、AKS
- **私有云**: 自建Kubernetes集群

### 依赖项目
- **第一阶段项目**: `ecommerce-basic`必须完成
- **镜像构建**: 微服务Docker镜像已构建

## 🚀 快速部署

### 一键部署
```bash
# 进入项目目录
cd projects/phase2-orchestration/microservices-k8s

# 执行一键部署
make deploy

# 或使用脚本
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

### 验证部署
```bash
# 检查部署状态
make status

# 健康检查
make health

# 获取访问地址
make get-url
```

## 📝 详细部署步骤

### 步骤1: 环境准备

#### 1.1 检查Kubernetes集群
```bash
# 验证集群连接
kubectl cluster-info
kubectl get nodes

# 检查可用资源
kubectl top nodes
kubectl describe nodes
```

#### 1.2 配置本地环境
```bash
# Minikube用户
minikube start --cpus=2 --memory=4096
eval $(minikube docker-env)

# Kind用户
kind create cluster --config k8s/kind-config.yaml

# 验证集群状态
kubectl get all --all-namespaces
```

### 步骤2: 构建微服务镜像

#### 2.1 构建镜像
```bash
# 自动构建所有镜像
make build-images

# 手动构建（可选）
cd ../../phase1-containerization/ecommerce-basic
make build
cd ../../phase2-orchestration/microservices-k8s
```

#### 2.2 验证镜像
```bash
# 检查镜像是否存在
make check-images

# 查看镜像列表
docker images | grep -E "(user-service|product-service|order-service|notification-service)"
```

### 步骤3: 创建命名空间和配置

#### 3.1 创建命名空间
```bash
# 创建专用命名空间
kubectl apply -f k8s/namespace/

# 验证命名空间
kubectl get namespace ecommerce-k8s
```

#### 3.2 部署配置和密钥
```bash
# 部署Secret
kubectl apply -f k8s/secrets/

# 部署ConfigMap
kubectl apply -f k8s/configmaps/

# 验证配置
kubectl get secrets,configmaps -n ecommerce-k8s
```

### 步骤4: 部署持久化存储

#### 4.1 创建PVC
```bash
# 部署存储配置
kubectl apply -f k8s/storage/

# 检查PVC状态
kubectl get pvc -n ecommerce-k8s
```

#### 4.2 存储类配置（可选）
```bash
# 查看可用存储类
kubectl get storageclass

# 配置默认存储类（如需要）
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 步骤5: 部署基础设施服务

#### 5.1 部署PostgreSQL
```bash
# 部署数据库
kubectl apply -f k8s/infrastructure/postgres.yaml

# 等待Pod就绪
kubectl wait --for=condition=ready pod -l app=postgres -n ecommerce-k8s --timeout=300s

# 验证数据库
kubectl exec -it deployment/postgres -n ecommerce-k8s -- psql -U postgres -c "\l"
```

#### 5.2 部署Redis
```bash
# 部署缓存服务
kubectl apply -f k8s/infrastructure/redis.yaml

# 验证Redis
kubectl exec -it deployment/redis -n ecommerce-k8s -- redis-cli -a redis123 ping
```

#### 5.3 部署RabbitMQ
```bash
# 部署消息队列
kubectl apply -f k8s/infrastructure/rabbitmq.yaml

# 等待RabbitMQ就绪
kubectl wait --for=condition=ready pod -l app=rabbitmq -n ecommerce-k8s --timeout=300s

# 验证RabbitMQ
kubectl exec -it deployment/rabbitmq -n ecommerce-k8s -- rabbitmq-diagnostics ping
```

### 步骤6: 部署微服务应用

#### 6.1 部署用户服务
```bash
# 部署用户服务
kubectl apply -f k8s/microservices/user-service.yaml

# 检查服务状态
kubectl get pods,services -l app=user-service -n ecommerce-k8s

# 查看日志
kubectl logs -f deployment/user-service -n ecommerce-k8s
```

#### 6.2 部署其他微服务
```bash
# 部署商品服务
kubectl apply -f k8s/microservices/product-service.yaml

# 部署订单服务
kubectl apply -f k8s/microservices/order-service.yaml

# 部署通知服务
kubectl apply -f k8s/microservices/notification-service.yaml

# 等待所有微服务就绪
kubectl wait --for=condition=ready pod -l tier=backend -n ecommerce-k8s --timeout=300s
```

### 步骤7: 部署API网关

#### 7.1 部署网关
```bash
# 部署API网关
kubectl apply -f k8s/gateway/

# 验证网关状态
kubectl get pods,services -l app=api-gateway -n ecommerce-k8s
```

#### 7.2 配置Ingress（可选）
```bash
# 部署Ingress配置
kubectl apply -f k8s/ingress/

# 检查Ingress状态
kubectl get ingress -n ecommerce-k8s
```

### 步骤8: 验证部署

#### 8.1 检查所有组件
```bash
# 查看所有资源
kubectl get all -n ecommerce-k8s

# 检查Pod状态
kubectl get pods -n ecommerce-k8s -o wide

# 查看服务端点
kubectl get endpoints -n ecommerce-k8s
```

#### 8.2 健康检查
```bash
# 执行健康检查
./scripts/health-check.sh

# 手动检查服务
kubectl exec -it deployment/api-gateway -n ecommerce-k8s -- curl http://user-service/health
```

## 🌐 访问应用

### 本地环境访问

#### Minikube环境
```bash
# 获取访问地址
minikube service api-gateway -n ecommerce-k8s --url

# 或使用tunnel（推荐）
minikube tunnel
# 然后访问: http://localhost
```

#### Kind环境
```bash
# 端口转发
kubectl port-forward service/api-gateway 8080:80 -n ecommerce-k8s

# 访问应用
curl http://localhost:8080
open http://localhost:8080
```

#### NodePort访问
```bash
# 获取NodePort端口
kubectl get service api-gateway -n ecommerce-k8s

# 访问地址（需要替换节点IP）
# http://<节点IP>:30080
```

### 云环境访问

#### LoadBalancer类型
```bash
# 修改Service类型
kubectl patch service api-gateway -n ecommerce-k8s -p '{"spec":{"type":"LoadBalancer"}}'

# 获取外部IP
kubectl get service api-gateway -n ecommerce-k8s
```

#### Ingress访问
```bash
# 配置域名解析后访问
https://ecommerce.yourdomain.com

# 或使用Ingress IP
kubectl get ingress -n ecommerce-k8s
```

## 🔧 运维操作

### 扩缩容操作

#### 手动扩缩容
```bash
# 扩容用户服务
kubectl scale deployment user-service --replicas=5 -n ecommerce-k8s

# 使用Makefile
make scale SERVICE=user-service REPLICAS=5

# 扩缩容所有微服务
make scale-all REPLICAS=3
```

#### 自动扩缩容
```bash
# HPA已自动配置，查看状态
kubectl get hpa -n ecommerce-k8s

# 手动触发扩容测试
kubectl run load-generator --image=busybox --rm -it --restart=Never -n ecommerce-k8s -- sh
# 在容器内执行压力测试
```

### 滚动更新

#### 更新服务镜像
```bash
# 更新用户服务
kubectl set image deployment/user-service user-service=user-service:v2.0 -n ecommerce-k8s

# 查看更新状态
kubectl rollout status deployment/user-service -n ecommerce-k8s

# 查看更新历史
kubectl rollout history deployment/user-service -n ecommerce-k8s
```

#### 回滚操作
```bash
# 回滚到上一个版本
kubectl rollout undo deployment/user-service -n ecommerce-k8s

# 回滚到指定版本
kubectl rollout undo deployment/user-service --to-revision=2 -n ecommerce-k8s
```

### 日志和监控

#### 查看日志
```bash
# 查看特定服务日志
kubectl logs -f deployment/user-service -n ecommerce-k8s

# 查看所有微服务日志
kubectl logs -f -l tier=backend -n ecommerce-k8s --max-log-requests=10

# 使用脚本查看日志
./scripts/logs.sh
./scripts/logs.sh user-service
```

#### 监控资源使用
```bash
# 查看Pod资源使用
kubectl top pods -n ecommerce-k8s

# 查看节点资源使用
kubectl top nodes

# 查看详细资源信息
kubectl describe pods -n ecommerce-k8s
```

## 🐛 故障排查

### 常见问题及解决方案

#### Pod无法启动
```bash
# 查看Pod状态
kubectl get pods -n ecommerce-k8s

# 查看Pod详细信息
kubectl describe pod <pod-name> -n ecommerce-k8s

# 查看Pod日志
kubectl logs <pod-name> -n ecommerce-k8s

# 常见原因及解决方案：
# 1. 镜像拉取失败 -> 检查镜像名称和标签
# 2. 资源不足 -> 调整资源请求或节点容量
# 3. 配置错误 -> 检查ConfigMap和Secret配置
```

#### Service无法访问
```bash
# 检查Service状态
kubectl get services -n ecommerce-k8s

# 检查Endpoints
kubectl get endpoints -n ecommerce-k8s

# 检查网络连通性
kubectl exec -it deployment/api-gateway -n ecommerce-k8s -- curl http://user-service/health

# 常见原因：
# 1. 标签选择器不匹配
# 2. 端口配置错误
# 3. 网络策略阻止
```

#### 数据库连接失败
```bash
# 检查PostgreSQL状态
kubectl get pods -l app=postgres -n ecommerce-k8s

# 测试数据库连接
kubectl exec -it deployment/postgres -n ecommerce-k8s -- psql -U postgres -c "SELECT version();"

# 检查数据库配置
kubectl describe configmap app-config -n ecommerce-k8s
kubectl describe secret postgres-secret -n ecommerce-k8s
```

#### 存储问题
```bash
# 检查PVC状态
kubectl get pvc -n ecommerce-k8s

# 查看PVC详细信息
kubectl describe pvc <pvc-name> -n ecommerce-k8s

# 检查存储类
kubectl get storageclass

# 常见问题：
# 1. 存储类不存在 -> 配置默认存储类
# 2. 存储容量不足 -> 增加存储大小
# 3. 访问模式不支持 -> 修改访问模式
```

### 调试工具

#### 创建调试Pod
```bash
# 创建调试容器
kubectl run debug --image=busybox --rm -it --restart=Never -n ecommerce-k8s -- sh

# 网络调试容器
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -n ecommerce-k8s -- bash
```

#### 使用kubectl调试
```bash
# 进入Pod shell
kubectl exec -it <pod-name> -n ecommerce-k8s -- /bin/bash

# 端口转发调试
kubectl port-forward pod/<pod-name> 8080:5001 -n ecommerce-k8s

# 查看事件
kubectl get events -n ecommerce-k8s --sort-by=.metadata.creationTimestamp
```

## 🧹 清理资源

### 部分清理
```bash
# 删除特定服务
kubectl delete deployment user-service -n ecommerce-k8s

# 删除所有微服务
kubectl delete -f k8s/microservices/

# 删除基础设施
kubectl delete -f k8s/infrastructure/
```

### 完全清理
```bash
# 删除整个命名空间（推荐）
kubectl delete namespace ecommerce-k8s

# 或使用Makefile
make clean

# 或使用脚本
./scripts/cleanup.sh
```

### 清理本地镜像
```bash
# 清理Docker镜像
docker image prune -f

# 删除特定镜像
docker rmi user-service:1.0 product-service:1.0 order-service:1.0 notification-service:1.0
```

## 📚 进阶配置

### 生产环境优化

#### 资源配置优化
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

#### 安全配置
```yaml
# SecurityContext配置
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
```

#### 网络策略
```yaml
# 限制网络访问
spec:
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
```

### 监控和日志集成

#### Prometheus集成
```bash
# 部署Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack

# 配置ServiceMonitor
kubectl apply -f monitoring/service-monitor.yaml
```

#### 日志聚合
```bash
# 部署ELK Stack
helm install elasticsearch elastic/elasticsearch
helm install kibana elastic/kibana
helm install filebeat elastic/filebeat
```

## 🔗 相关资源

### 官方文档
- [Kubernetes官方文档](https://kubernetes.io/docs/)
- [kubectl命令参考](https://kubernetes.io/docs/reference/kubectl/)

### 最佳实践
- [Kubernetes应用部署最佳实践](https://kubernetes.io/docs/concepts/configuration/)
- [云原生应用架构指南](https://12factor.net/)

### 社区资源
- [Kubernetes GitHub](https://github.com/kubernetes/kubernetes)
- [CNCF项目](https://landscape.cncf.io/)

---

## 🆘 支持

如果遇到问题，请：
1. 查看本指南的故障排查部分
2. 检查项目的GitHub Issues
3. 参考Kubernetes官方文档
4. 在项目仓库提交Issue

**祝你部署成功！🚀**