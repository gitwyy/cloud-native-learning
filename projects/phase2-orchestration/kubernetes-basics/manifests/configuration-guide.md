# Kubernetes配置文件说明指南

## 📋 概述

本指南详细解释了项目中Kubernetes YAML配置文件的结构、字段含义和最佳实践。

## 🔧 Deployment配置解析

### nginx-deployment.yaml

```yaml
apiVersion: apps/v1  # API版本，apps/v1是Deployment的稳定版本
kind: Deployment     # 资源类型
metadata:           # 元数据部分
  name: nginx-deployment  # Deployment名称，集群内唯一
  labels:               # 标签，用于组织和选择资源
    app: nginx
    version: v1
spec:                # 规格定义
  replicas: 3         # 期望的Pod副本数量
  selector:           # 选择器，定义Deployment管理哪些Pod
    matchLabels:      # 标签匹配规则
      app: nginx
  template:           # Pod模板
    metadata:
      labels:         # Pod标签，必须匹配selector
        app: nginx
        version: v1
    spec:             # Pod规格
      containers:     # 容器定义
      - name: nginx
        image: nginx:1.25    # 容器镜像
        ports:
        - containerPort: 80  # 容器暴露端口
          name: http
        resources:           # 资源限制和请求
          requests:          # 最小资源需求
            memory: "64Mi"
            cpu: "50m"
          limits:            # 最大资源限制
            memory: "128Mi"
            cpu: "100m"
        readinessProbe:      # 就绪性探针
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5  # 首次检查延迟
          periodSeconds: 10       # 检查间隔
        livenessProbe:       # 存活性探针
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
      restartPolicy: Always  # 重启策略
```

### 字段详解

#### 1. API版本和资源类型
- `apiVersion`: 指定使用的Kubernetes API版本
- `kind`: 声明资源类型（Deployment、Service、Pod等）

#### 2. 元数据（metadata）
- `name`: 资源名称，在同一命名空间内必须唯一
- `labels`: 键值对标签，用于资源组织和选择
- `annotations`: 注解，存储额外的非标识性信息

#### 3. 规格（spec）
- `replicas`: 期望运行的Pod副本数
- `selector`: 定义Deployment如何找到要管理的Pod
- `template`: Pod创建模板

#### 4. 容器配置
- `image`: 容器镜像名称和标签
- `ports`: 容器暴露的端口列表
- `resources`: CPU和内存的请求和限制
- `env`: 环境变量配置

#### 5. 健康检查
- `readinessProbe`: 检查容器是否准备好接收流量
- `livenessProbe`: 检查容器是否仍在运行

## 🌐 Service配置解析

### nginx-service.yaml

本文件包含三种Service类型的示例：

#### 1. NodePort Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort      # 服务类型
  selector:           # 选择后端Pod
    app: nginx
  ports:
    - name: http
      protocol: TCP
      port: 80         # Service端口
      targetPort: 80   # Pod端口
      nodePort: 30080  # 节点端口（30000-32767）
```

**特点：**
- 在每个节点上开放指定端口
- 外部可通过 `<NodeIP>:<NodePort>` 访问
- 适合开发和测试环境

#### 2. ClusterIP Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service-clusterip
spec:
  type: ClusterIP     # 默认类型
  selector:
    app: nginx
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

**特点：**
- 仅集群内部访问
- 提供稳定的内部IP
- 默认的Service类型

#### 3. LoadBalancer Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

**特点：**
- 由云提供商创建外部负载均衡器
- 自动分配外部IP
- 适合生产环境

### Service字段详解

#### 1. 选择器（selector）
- 通过标签选择后端Pod
- 必须与Pod标签匹配
- 支持多个标签的AND关系

#### 2. 端口配置
- `port`: Service暴露的端口
- `targetPort`: 后端Pod的端口
- `nodePort`: 节点端口（仅NodePort类型）
- `protocol`: 协议（TCP/UDP）

## 🔧 Kind集群配置

### kind-config.yaml
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k8s-basics
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
- role: worker
- role: worker
```

## 📝 最佳实践

### 1. 标签使用
```yaml
labels:
  app: nginx           # 应用名称
  version: v1.0        # 版本号
  component: frontend  # 组件类型
  environment: dev     # 环境标识
```

### 2. 资源限制
```yaml
resources:
  requests:     # 最小保证资源
    memory: "64Mi"
    cpu: "50m"
  limits:       # 最大允许资源
    memory: "128Mi"
    cpu: "100m"
```

### 3. 健康检查
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

### 4. 安全配置
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
```

## 🚨 常见错误及解决方案

### 1. 镜像拉取失败
**错误信息：** `ErrImagePull`

**解决方案：**
```bash
# 检查镜像名称和标签
kubectl describe pod <pod-name>

# 对于私有镜像，创建Secret
kubectl create secret docker-registry myregistrykey \
  --docker-server=DOCKER_REGISTRY_SERVER \
  --docker-username=DOCKER_USER \
  --docker-password=DOCKER_PASSWORD \
  --docker-email=DOCKER_EMAIL
```

### 2. 服务无法访问
**错误信息：** 无法通过Service访问Pod

**解决方案：**
```bash
# 检查Endpoints
kubectl get endpoints <service-name>

# 检查Pod标签
kubectl get pods --show-labels

# 验证Service选择器
kubectl describe service <service-name>
```

### 3. Pod启动失败
**错误信息：** `CrashLoopBackOff`

**解决方案：**
```bash
# 查看Pod日志
kubectl logs <pod-name>

# 查看Pod事件
kubectl describe pod <pod-name>

# 检查资源限制
kubectl top pods
```

### 4. 端口配置错误
**错误信息：** 连接被拒绝

**解决方案：**
```bash
# 验证容器端口
kubectl exec -it <pod-name> -- netstat -tlnp

# 测试Pod直接访问
kubectl port-forward <pod-name> 8080:80

# 检查Service配置
kubectl get service <service-name> -o yaml
```

## 📚 配置模板

### 基础Web应用模板
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: your-app:latest
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
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
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

## 🎓 学习检查点

完成配置文件学习后，确保你能够：

- [ ] 理解YAML基本语法和结构
- [ ] 解释Deployment各字段的作用
- [ ] 配置不同类型的Service
- [ ] 设置合适的资源限制
- [ ] 配置健康检查探针
- [ ] 排查常见配置错误
- [ ] 编写基本的Kubernetes配置文件

## 📖 参考资料

- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [Deployment配置详解](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Service配置指南](https://kubernetes.io/docs/concepts/services-networking/service/)
- [资源管理最佳实践](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)