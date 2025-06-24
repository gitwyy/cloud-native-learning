# 练习1：创建和管理基础Pod

## 🎯 学习目标

- 理解Pod的基本概念和生命周期
- 掌握使用kubectl创建和管理Pod
- 学会查看Pod状态和日志
- 了解Pod的网络和存储特性

## 📋 前置条件

- 已安装并启动Minikube或Kind集群
- kubectl命令行工具可正常使用
- 能够执行基本的kubectl命令

## 🚀 练习步骤

### 步骤1：验证集群状态

```bash
# 检查集群状态
kubectl cluster-info

# 查看节点信息
kubectl get nodes

# 查看系统Pod状态
kubectl get pods -n kube-system
```

**期望结果：**
- 集群状态为Running
- 至少有一个Ready状态的节点
- 系统Pod都处于Running状态

### 步骤2：创建第一个Pod

#### 方法一：命令行创建
```bash
# 使用kubectl run创建Pod
kubectl run nginx-pod --image=nginx:1.25 --port=80

# 查看Pod状态
kubectl get pods

# 查看Pod详细信息
kubectl describe pod nginx-pod
```

#### 方法二：YAML文件创建
创建文件 `simple-pod.yaml`：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-nginx
  labels:
    app: nginx
    environment: learning
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
      name: http
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
```

```bash
# 应用YAML配置
kubectl apply -f simple-pod.yaml

# 验证创建结果
kubectl get pods -l app=nginx
```

### 步骤3：查看Pod信息

```bash
# 查看Pod列表
kubectl get pods

# 查看Pod详细信息
kubectl describe pod nginx-pod

# 查看Pod的YAML配置
kubectl get pod nginx-pod -o yaml

# 查看Pod的JSON格式信息
kubectl get pod nginx-pod -o json
```

### 步骤4：访问Pod

```bash
# 方法一：端口转发
kubectl port-forward nginx-pod 8080:80

# 在另一个终端测试访问
curl http://localhost:8080

# 方法二：直接进入Pod
kubectl exec -it nginx-pod -- /bin/bash

# 在Pod内部执行命令
kubectl exec nginx-pod -- ls -la /usr/share/nginx/html
kubectl exec nginx-pod -- cat /etc/nginx/nginx.conf
```

### 步骤5：查看Pod日志

```bash
# 查看Pod日志
kubectl logs nginx-pod

# 实时跟踪日志
kubectl logs -f nginx-pod

# 查看之前容器的日志（如果Pod重启过）
kubectl logs nginx-pod --previous
```

### 步骤6：Pod生命周期管理

```bash
# 查看Pod状态变化
watch kubectl get pods

# 删除Pod
kubectl delete pod nginx-pod

# 验证删除结果
kubectl get pods
```

## 🔧 进阶练习

### 练习A：多容器Pod

创建包含多个容器的Pod：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html
  - name: sidecar
    image: busybox
    command: ['sh', '-c', 'while true; do echo "$(date): Hello from sidecar" > /var/log/app.log; sleep 30; done']
    volumeMounts:
    - name: shared-data
      mountPath: /var/log
  volumes:
  - name: shared-data
    emptyDir: {}
```

```bash
# 创建多容器Pod
kubectl apply -f multi-container-pod.yaml

# 查看两个容器的日志
kubectl logs multi-container-pod -c nginx
kubectl logs multi-container-pod -c sidecar

# 进入不同容器
kubectl exec -it multi-container-pod -c nginx -- /bin/bash
kubectl exec -it multi-container-pod -c sidecar -- /bin/sh
```

### 练习B：Pod环境变量

创建带环境变量的Pod：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: env-test
    image: busybox
    command: ['sh', '-c', 'env && sleep 3600']
    env:
    - name: USERNAME
      value: "kubernetes-learner"
    - name: ENVIRONMENT
      value: "learning"
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
```

```bash
# 创建并查看环境变量
kubectl apply -f env-pod.yaml
kubectl logs env-pod
```

### 练习C：Pod资源限制测试

```bash
# 创建资源限制严格的Pod
kubectl run resource-limited-pod --image=nginx:1.25 \
  --requests='memory=64Mi,cpu=50m' \
  --limits='memory=128Mi,cpu=100m'

# 查看资源使用情况
kubectl top pod resource-limited-pod

# 查看资源限制详情
kubectl describe pod resource-limited-pod
```

## 🐛 故障排查练习

### 练习1：镜像拉取失败

```bash
# 创建一个使用不存在镜像的Pod
kubectl run broken-pod --image=nonexistent/image:latest

# 查看Pod状态
kubectl get pods

# 排查问题
kubectl describe pod broken-pod
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 练习2：容器启动失败

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: failing-pod
spec:
  containers:
  - name: failing-container
    image: busybox
    command: ['sh', '-c', 'exit 1']  # 故意让容器失败
```

```bash
# 创建失败的Pod
kubectl apply -f failing-pod.yaml

# 观察Pod状态变化
kubectl get pods -w

# 排查失败原因
kubectl describe pod failing-pod
kubectl logs failing-pod
```

## 📝 练习检查表

完成练习后，确保你能够：

- [ ] 使用kubectl run创建Pod
- [ ] 使用YAML文件创建Pod
- [ ] 查看Pod状态和详细信息
- [ ] 使用port-forward访问Pod
- [ ] 进入Pod执行命令
- [ ] 查看Pod日志
- [ ] 理解Pod的生命周期状态
- [ ] 创建多容器Pod
- [ ] 配置Pod环境变量
- [ ] 设置Pod资源限制
- [ ] 排查Pod启动问题

## 🎉 小结

通过本练习，你已经掌握了：

1. **Pod基础概念**：Pod是Kubernetes中最小的部署单元
2. **Pod创建方式**：命令行和YAML文件两种方式
3. **Pod管理操作**：查看状态、访问、执行命令、查看日志
4. **Pod高级特性**：多容器、环境变量、资源限制
5. **故障排查技能**：识别和解决常见Pod问题

**下一步**：完成所有检查点后，继续进行练习2：Deployment管理。