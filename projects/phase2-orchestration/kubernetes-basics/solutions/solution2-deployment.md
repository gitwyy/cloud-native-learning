# 练习2解答：Deployment部署和管理

## 📋 解答要点

### 步骤1：创建基础Deployment

#### 命令行方式
```bash
# 创建nginx Deployment
kubectl create deployment nginx-deployment --image=nginx:1.25 --replicas=3

# 验证创建结果
kubectl get deployments
# 输出应显示nginx-deployment，READY 3/3

kubectl get replicasets
# 应显示关联的ReplicaSet

kubectl get pods -l app=nginx-deployment
# 应显示3个运行中的Pod
```

#### YAML文件方式
使用项目中的nginx-deployment.yaml：

```yaml
# 标准Deployment配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
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
kubectl apply -f ../manifests/nginx-deployment.yaml
kubectl get pods -l app=nginx
# 应显示3个nginx Pod运行中
```

### 步骤2：观察Deployment行为

```bash
# 查看Deployment详细信息
kubectl describe deployment nginx-deployment
# 关键信息：
# - Replicas: 3 desired | 3 updated | 3 total | 3 available
# - StrategyType: RollingUpdate
# - Events: 显示创建过程

# 观察Pod分布
kubectl get pods -o wide
# 查看Pod分布在不同节点（如有多节点）

# 查看ReplicaSet详情
kubectl get rs -l app=nginx
kubectl describe rs <replicaset-name>
# ReplicaSet负责维护Pod数量
```

### 步骤3：扩容和缩容

```bash
# 扩容到5个副本
kubectl scale deployment nginx-deployment --replicas=5

# 观察扩容过程
watch kubectl get pods
# 应看到新Pod从Pending->ContainerCreating->Running

# 验证扩容结果
kubectl get deployment nginx-deployment
# READY应显示5/5

# 缩容到2个副本
kubectl scale deployment nginx-deployment --replicas=2

# 观察缩容过程
kubectl get pods -l app=nginx
# 应看到3个Pod被终止，剩余2个Running
```

**扩缩容机制说明：**
- 扩容：创建新Pod直到达到期望副本数
- 缩容：选择最新创建的Pod优先终止

### 步骤4：滚动更新

```bash
# 更新镜像版本
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# 观察更新过程
kubectl rollout status deployment/nginx-deployment
# 输出：deployment "nginx-deployment" successfully rolled out

# 查看更新历史
kubectl rollout history deployment/nginx-deployment
# 显示版本历史和变更记录

# 查看新的ReplicaSet
kubectl get rs -l app=nginx
# 应看到新旧两个ReplicaSet，旧的副本数为0
```

**滚动更新过程：**
1. 创建新ReplicaSet
2. 逐步增加新ReplicaSet的Pod数量
3. 同时减少旧ReplicaSet的Pod数量
4. 直到新ReplicaSet达到期望副本数，旧ReplicaSet为0

### 步骤5：回滚操作

```bash
# 查看回滚历史
kubectl rollout history deployment/nginx-deployment
# 输出：
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

# 回滚到上一个版本
kubectl rollout undo deployment/nginx-deployment

# 回滚到指定版本
kubectl rollout undo deployment/nginx-deployment --to-revision=1

# 验证回滚结果
kubectl describe deployment nginx-deployment | grep Image
# 应显示镜像已回滚到nginx:1.25
```

## 🔧 进阶练习解答

### 自定义更新策略解答

```yaml
# custom-update-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-update-deployment
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1    # 最多1个Pod不可用
      maxSurge: 2          # 最多额外创建2个Pod
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

**更新策略解释：**
- `maxUnavailable: 1`: 更新过程中最多有1个Pod不可用
- `maxSurge: 2`: 更新过程中最多可以额外创建2个Pod
- 总Pod数范围：5-8个（6-1到6+2）

```bash
# 执行更新并观察
kubectl apply -f custom-update-deployment.yaml
kubectl set image deployment/custom-update-deployment nginx=nginx:1.26
watch kubectl get pods -l app=custom-update
# 观察更新过程中Pod数量变化
```

### 多标签选择器解答

```yaml
# multi-label-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-label-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-server      # 必须匹配
      version: v1          # 必须匹配
      environment: production  # 必须匹配
  template:
    metadata:
      labels:
        app: web-server
        version: v1
        environment: production
        team: frontend     # 额外标签，不影响选择
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

```bash
# 验证标签查询
kubectl apply -f multi-label-deployment.yaml

# 不同标签查询
kubectl get pods -l app=web-server
kubectl get pods -l version=v1
kubectl get pods -l environment=production

# 组合标签查询
kubectl get pods -l app=web-server,version=v1
kubectl get pods -l app=web-server,version=v1,environment=production
```

### 集成第一阶段项目解答

```yaml
# user-service-deployment.yaml
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
        version: v1.0
    spec:
      containers:
      - name: user-service
        image: user-service:1.0
        imagePullPolicy: Never  # 使用本地镜像
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: FLASK_ENV
          value: "production"
        - name: DATABASE_URL
          value: "postgresql://user:password@postgres:5432/userdb"
        - name: REDIS_URL
          value: "redis://redis:6379/0"
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

**健康检查配置说明：**
- `readinessProbe`: 检查容器是否准备好接收流量
- `livenessProbe`: 检查容器是否还活着，失败会重启容器

## 🐛 故障排查解答

### 镜像拉取失败处理

```bash
# 创建问题Deployment
kubectl create deployment broken-deployment --image=nonexistent/image:latest --replicas=3

# 观察问题现象
kubectl get pods
# 状态：ErrImagePull 或 ImagePullBackOff

kubectl describe deployment broken-deployment
# Events显示镜像拉取失败

# 解决方案
kubectl set image deployment/broken-deployment nonexistent=nginx:1.25

# 验证修复
kubectl get pods
# 状态应变为Running
```

### 资源不足处理

```yaml
# resource-heavy-deployment.yaml
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
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
```

```bash
# 观察资源不足问题
kubectl apply -f resource-heavy-deployment.yaml
kubectl get pods
# 部分Pod可能处于Pending状态

kubectl describe pods -l app=resource-heavy
# Events显示：FailedScheduling: Insufficient memory/cpu

# 解决方案
kubectl get nodes
kubectl describe nodes
# 查看节点可用资源

# 调整资源请求
kubectl patch deployment resource-heavy-deployment -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"memory":"64Mi","cpu":"50m"}}}]}}}}'
```

## 📊 监控和验证

### Deployment状态监控

```bash
# 实时监控命令
watch kubectl get deployments,rs,pods

# 查看详细状态
kubectl describe deployment nginx-deployment

# 查看资源使用
kubectl top pods -l app=nginx

# 查看事件时间线
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 关键指标解读

```bash
# Deployment状态字段
kubectl get deployment nginx-deployment -o wide
# READY: 就绪副本数/期望副本数
# UP-TO-DATE: 已更新到最新配置的副本数
# AVAILABLE: 可用副本数

# ReplicaSet状态
kubectl get rs -l app=nginx
# DESIRED: 期望副本数
# CURRENT: 当前副本数
# READY: 就绪副本数
```

## 🔍 深入理解

### Deployment控制器工作流程

```
1. Deployment Controller 监控 Deployment 对象变化
   ↓
2. 计算期望状态与当前状态的差异
   ↓
3. 创建或更新 ReplicaSet 对象
   ↓
4. ReplicaSet Controller 监控 ReplicaSet 对象
   ↓
5. 创建或删除 Pod 对象
   ↓
6. Kubelet 在节点上运行 Pod
```

### 滚动更新策略详解

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%    # 可以是数字或百分比
    maxSurge: 25%          # 可以是数字或百分比
```

**计算示例（replicas=4）：**
- maxUnavailable: 25% → 1个Pod
- maxSurge: 25% → 1个Pod
- 更新过程中Pod数量范围：3-5个

### 标签最佳实践

```yaml
labels:
  app: my-application        # 应用名称
  version: v1.2.3           # 版本号
  component: frontend       # 组件类型
  part-of: ecommerce-system # 所属系统
  managed-by: helm          # 管理工具
```

## 📝 检查清单验证

| 检查项 | 验证命令 | 预期结果 |
|--------|----------|----------|
| Deployment创建 | `kubectl get deployment nginx-deployment` | READY 3/3 |
| Pod运行状态 | `kubectl get pods -l app=nginx` | 3个Running |
| 扩容功能 | `kubectl scale deployment nginx-deployment --replicas=5` | READY 5/5 |
| 滚动更新 | `kubectl set image deployment/nginx-deployment nginx=nginx:1.26` | 成功更新 |
| 版本回滚 | `kubectl rollout undo deployment/nginx-deployment` | 成功回滚 |
| 健康检查 | `kubectl describe pod <pod-name>` | 探针配置正确 |

## 💡 关键概念总结

### Deployment vs ReplicaSet vs Pod

```
Deployment (声明式管理)
    ↓ 管理
ReplicaSet (副本控制)
    ↓ 创建
Pod (运行容器)
```

### 更新策略对比

| 策略 | 描述 | 适用场景 |
|------|------|----------|
| RollingUpdate | 逐步替换 | 生产环境（默认） |
| Recreate | 先删除后创建 | 开发环境或无状态应用 |

### 常用操作总结

```bash
# 创建
kubectl create deployment <name> --image=<image>
kubectl apply -f deployment.yaml

# 查看
kubectl get deployments
kubectl describe deployment <name>

# 扩缩容
kubectl scale deployment <name> --replicas=<number>

# 更新
kubectl set image deployment/<name> <container>=<image>

# 回滚
kubectl rollout undo deployment/<name>

# 删除
kubectl delete deployment <name>
```

## 🎯 学习成果

完成本练习后，你应该能够：

1. **理解Deployment架构**：掌握Deployment、ReplicaSet、Pod的层次关系
2. **生命周期管理**：创建、扩缩容、更新、回滚Deployment
3. **更新策略配置**：理解并配置滚动更新参数
4. **故障排查能力**：识别和解决常见Deployment问题
5. **标签选择器使用**：有效管理和查询Kubernetes资源

**准备就绪标志**：能够独立设计和管理生产级的Deployment配置，理解声明式管理的优势。

**下一步**：继续学习Service，了解如何为Deployment提供稳定的网络访问接口。