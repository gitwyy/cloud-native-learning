# 练习2：Deployment部署和管理

## 🎯 学习目标

- 理解Deployment的作用和优势
- 掌握Deployment的创建和管理
- 学会配置副本数量和更新策略
- 了解滚动更新和回滚机制

## 📋 前置条件

- 完成练习1：基础Pod操作
- 集群状态正常
- 理解Pod的基本概念

## 🚀 练习步骤

### 步骤1：创建基础Deployment

#### 方法一：命令行创建
```bash
# 创建nginx Deployment
kubectl create deployment nginx-deployment --image=nginx:1.25 --replicas=3

# 查看Deployment状态
kubectl get deployments

# 查看关联的ReplicaSet
kubectl get replicasets

# 查看创建的Pod
kubectl get pods -l app=nginx-deployment
```

#### 方法二：YAML文件创建
使用项目中的配置文件：

```bash
# 应用现有的Deployment配置
kubectl apply -f ../manifests/nginx-deployment.yaml

# 查看创建结果
kubectl get deployments nginx-deployment
kubectl get pods -l app=nginx
```

### 步骤2：观察Deployment行为

```bash
# 查看Deployment详细信息
kubectl describe deployment nginx-deployment

# 观察Pod分布
kubectl get pods -o wide

# 查看ReplicaSet详情
kubectl get rs -l app=nginx
kubectl describe rs <replicaset-name>
```

### 步骤3：扩容和缩容

```bash
# 扩容到5个副本
kubectl scale deployment nginx-deployment --replicas=5

# 观察扩容过程
watch kubectl get pods

# 验证扩容结果
kubectl get deployment nginx-deployment

# 缩容到2个副本
kubectl scale deployment nginx-deployment --replicas=2

# 观察缩容过程
kubectl get pods -l app=nginx
```

### 步骤4：滚动更新

```bash
# 更新镜像版本
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# 观察更新过程
kubectl rollout status deployment/nginx-deployment

# 查看更新历史
kubectl rollout history deployment/nginx-deployment

# 查看新的ReplicaSet
kubectl get rs -l app=nginx
```

### 步骤5：回滚操作

```bash
# 查看回滚历史
kubectl rollout history deployment/nginx-deployment

# 回滚到上一个版本
kubectl rollout undo deployment/nginx-deployment

# 回滚到指定版本
kubectl rollout undo deployment/nginx-deployment --to-revision=1

# 验证回滚结果
kubectl describe deployment nginx-deployment
```

## 🔧 进阶练习

### 练习A：自定义更新策略

创建带有自定义更新策略的Deployment：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-update-deployment
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  selector:
    matchLabels:
      app: custom-update
  template:
    metadata:
      labels:
        app: custom-update
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

```bash
# 创建Deployment
kubectl apply -f custom-update-deployment.yaml

# 执行更新并观察过程
kubectl set image deployment/custom-update-deployment nginx=nginx:1.26
watch kubectl get pods -l app=custom-update
```

### 练习B：使用标签选择器

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-label-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-server
      version: v1
      environment: production
  template:
    metadata:
      labels:
        app: web-server
        version: v1
        environment: production
        team: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

```bash
# 创建多标签Deployment
kubectl apply -f multi-label-deployment.yaml

# 使用不同标签查询
kubectl get pods -l app=web-server
kubectl get pods -l version=v1
kubectl get pods -l environment=production
kubectl get pods -l team=frontend

# 组合标签查询
kubectl get pods -l app=web-server,version=v1
```

### 练习C：Deployment与第一阶段项目集成

创建使用第一阶段镜像的Deployment：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
      tier: backend
  template:
    metadata:
      labels:
        app: user-service
        tier: backend
    spec:
      containers:
      - name: user-service
        image: user-service:1.0  # 来自第一阶段项目
        ports:
        - containerPort: 5000
        env:
        - name: FLASK_ENV
          value: "production"
        - name: DATABASE_URL
          value: "postgresql://user:password@postgres:5432/userdb"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
```

```bash
# 注意：需要先构建第一阶段的镜像
# 如果使用Minikube：
eval $(minikube docker-env)
cd ../../phase1-containerization/ecommerce-basic
make build

# 创建Deployment
kubectl apply -f user-service-deployment.yaml
kubectl get pods -l app=user-service
```

## 🧪 故障排查练习

### 练习1：镜像拉取失败处理

```bash
# 创建使用错误镜像的Deployment
kubectl create deployment broken-deployment --image=nonexistent/image:latest --replicas=3

# 观察问题
kubectl get pods
kubectl describe deployment broken-deployment

# 修复问题
kubectl set image deployment/broken-deployment nonexistent=nginx:1.25

# 验证修复
kubectl get pods
```

### 练习2：资源不足处理

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-heavy-deployment
spec:
  replicas: 10
  selector:
    matchLabels:
      app: resource-heavy
  template:
    metadata:
      labels:
        app: resource-heavy
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          requests:
            memory: "1Gi"  # 故意设置很高的资源需求
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
```

```bash
# 创建资源密集型Deployment
kubectl apply -f resource-heavy-deployment.yaml

# 观察调度问题
kubectl get pods
kubectl describe pods -l app=resource-heavy

# 查看节点资源
kubectl top nodes
kubectl describe nodes
```

## 📊 监控和观察

### 查看Deployment指标

```bash
# 查看Deployment状态
kubectl get deployments

# 查看详细状态
kubectl describe deployment nginx-deployment

# 查看Pod分布
kubectl get pods -o wide

# 查看资源使用
kubectl top pods -l app=nginx

# 查看事件
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 使用Watch模式观察

```bash
# 实时观察Pod状态
watch kubectl get pods

# 实时观察Deployment状态
watch kubectl get deployments

# 观察滚动更新过程
kubectl set image deployment/nginx-deployment nginx=nginx:alpine &
watch kubectl get pods -l app=nginx
```

## 📝 练习检查表

完成练习后，确保你能够：

- [ ] 使用命令行和YAML创建Deployment
- [ ] 理解Deployment、ReplicaSet、Pod之间的关系
- [ ] 执行Deployment的扩容和缩容操作
- [ ] 配置和执行滚动更新
- [ ] 执行版本回滚操作
- [ ] 自定义更新策略参数
- [ ] 使用标签选择器管理资源
- [ ] 配置健康检查探针
- [ ] 设置资源限制和请求
- [ ] 排查Deployment常见问题

## 🔍 深入理解

### Deployment工作原理

```
Deployment Controller 监控 Deployment 对象
    ↓
创建/更新 ReplicaSet
    ↓
ReplicaSet Controller 监控 ReplicaSet 对象
    ↓
创建/删除 Pod
    ↓
Kubelet 在节点上运行 Pod
```

### 滚动更新策略

- **maxUnavailable**: 更新过程中不可用Pod的最大数量
- **maxSurge**: 更新过程中可以创建的超出期望副本数的Pod数量

### 标签选择器最佳实践

```yaml
labels:
  app: my-app           # 应用名称
  version: v1.0         # 版本信息
  component: frontend   # 组件类型
  environment: prod     # 环境标识
```

## 🎉 小结

通过本练习，你已经掌握了：

1. **Deployment核心概念**：声明式管理Pod副本
2. **生命周期管理**：创建、扩缩容、更新、回滚
3. **更新策略**：滚动更新的配置和控制
4. **标签管理**：使用标签组织和选择资源
5. **故障排查**：识别和解决常见Deployment问题

**下一步**：完成所有检查点后，继续进行练习3：Service网络配置。