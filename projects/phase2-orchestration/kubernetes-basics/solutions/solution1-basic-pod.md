# 练习1解答：创建和管理基础Pod

## 📋 解答要点

### 步骤1：验证集群状态
```bash
# 检查集群状态
kubectl cluster-info
# 预期输出：显示master和DNS服务的URL

# 查看节点信息
kubectl get nodes
# 预期输出：显示节点状态为Ready

# 查看系统Pod状态
kubectl get pods -n kube-system
# 预期输出：所有系统Pod状态为Running
```

### 步骤2：创建第一个Pod

#### 命令行方式
```bash
kubectl run nginx-pod --image=nginx:1.25 --port=80
# 创建名为nginx-pod的Pod

kubectl get pods
# 查看Pod状态，应显示Running状态
```

#### YAML文件方式
```yaml
# simple-pod.yaml
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
kubectl apply -f simple-pod.yaml
kubectl get pods -l app=nginx
# 应显示simple-nginx Pod运行中
```

### 步骤3：查看Pod信息

```bash
# 基本信息
kubectl get pods
# 显示Pod列表和状态

# 详细信息
kubectl describe pod nginx-pod
# 显示Pod的详细配置、事件和状态

# YAML格式
kubectl get pod nginx-pod -o yaml
# 显示完整的Pod配置

# JSON格式
kubectl get pod nginx-pod -o json
# 显示JSON格式的Pod信息
```

### 步骤4：访问Pod

```bash
# 端口转发方式
kubectl port-forward nginx-pod 8080:80
# 在浏览器访问 http://localhost:8080

# 直接进入Pod
kubectl exec -it nginx-pod -- /bin/bash
# 进入Pod的shell环境

# 执行单个命令
kubectl exec nginx-pod -- ls -la /usr/share/nginx/html
# 列出nginx默认页面目录内容
```

### 步骤5：查看Pod日志

```bash
# 查看日志
kubectl logs nginx-pod
# 显示nginx访问日志

# 实时跟踪
kubectl logs -f nginx-pod
# 实时显示新的日志条目

# 查看之前容器日志
kubectl logs nginx-pod --previous
# 如果Pod重启过，查看之前容器的日志
```

## 🔧 进阶练习解答

### 多容器Pod解答

```yaml
# multi-container-pod.yaml
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

**关键点解释：**
- 两个容器共享`shared-data`卷
- nginx容器挂载到网页目录
- sidecar容器写入日志文件
- 使用`emptyDir`类型的临时存储

```bash
# 验证多容器Pod
kubectl apply -f multi-container-pod.yaml

# 查看两个容器的日志
kubectl logs multi-container-pod -c nginx
kubectl logs multi-container-pod -c sidecar

# 进入不同容器
kubectl exec -it multi-container-pod -c nginx -- bash
kubectl exec -it multi-container-pod -c sidecar -- sh
```

### 环境变量Pod解答

```yaml
# env-pod.yaml
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

**环境变量类型：**
- 静态值：`USERNAME`、`ENVIRONMENT`
- 字段引用：`NODE_NAME`（节点名称）、`POD_NAME`（Pod名称）

```bash
kubectl apply -f env-pod.yaml
kubectl logs env-pod
# 输出应包含设置的环境变量和系统信息
```

## 🐛 故障排查解答

### 镜像拉取失败

```bash
# 创建问题Pod
kubectl run broken-pod --image=nonexistent/image:latest

# 查看状态
kubectl get pods
# 状态应显示为ErrImagePull或ImagePullBackOff

# 排查详情
kubectl describe pod broken-pod
# Events部分应显示拉取镜像失败的错误信息
```

**常见错误信息：**
```
Failed to pull image "nonexistent/image:latest": rpc error: code = NotFound desc = failed to pull and unpack image
```

**解决方案：**
```bash
# 修正镜像名称
kubectl delete pod broken-pod
kubectl run fixed-pod --image=nginx:1.25
```

### 容器启动失败

```yaml
# failing-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: failing-pod
spec:
  containers:
  - name: failing-container
    image: busybox
    command: ['sh', '-c', 'exit 1']
```

```bash
kubectl apply -f failing-pod.yaml
kubectl get pods
# 状态应显示为CrashLoopBackOff

kubectl describe pod failing-pod
# Events显示容器退出码为1

kubectl logs failing-pod
# 可能没有日志输出，因为容器立即退出
```

**解决方案：**
```bash
# 修正容器命令
kubectl patch pod failing-pod -p '{"spec":{"containers":[{"name":"failing-container","command":["sleep","3600"]}]}}'
```

## 📊 验证和测试

### 网络连通性测试

```bash
# 创建测试Pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# 在Pod内测试网络
# ping其他Pod的IP
ping <pod-ip>

# 测试DNS解析
nslookup kubernetes.default.svc.cluster.local
```

### 资源使用监控

```bash
# 查看Pod资源使用
kubectl top pods

# 查看节点资源使用
kubectl top nodes

# 查看Pod详细资源信息
kubectl describe pod nginx-pod | grep -A 5 -B 5 Resources
```

## 📝 检查清单验证

| 检查项 | 验证命令 | 预期结果 |
|--------|----------|----------|
| Pod创建 | `kubectl get pods` | 显示Running状态 |
| Pod访问 | `kubectl port-forward nginx-pod 8080:80` | 可访问nginx页面 |
| Pod日志 | `kubectl logs nginx-pod` | 显示nginx日志 |
| Pod执行 | `kubectl exec nginx-pod -- ls /` | 显示根目录内容 |
| 多容器 | `kubectl logs multi-container-pod -c sidecar` | 显示sidecar日志 |
| 环境变量 | `kubectl logs env-pod` | 显示设置的环境变量 |

## 💡 关键概念理解

### Pod生命周期

```
Pending → Running → Succeeded/Failed
   ↑         ↑         ↑
调度阶段   运行阶段   完成阶段
```

**状态说明：**
- **Pending**: Pod已创建但容器尚未启动
- **Running**: 至少有一个容器正在运行
- **Succeeded**: 所有容器成功完成
- **Failed**: 至少有一个容器失败退出
- **Unknown**: 无法获取Pod状态

### 容器重启策略

```yaml
spec:
  restartPolicy: Always  # 默认，总是重启
  # restartPolicy: OnFailure  # 仅失败时重启
  # restartPolicy: Never  # 从不重启
```

### 资源配置最佳实践

```yaml
resources:
  requests:    # 最小保证资源
    memory: "64Mi"
    cpu: "50m"
  limits:      # 最大允许资源
    memory: "128Mi"
    cpu: "100m"
```

## 🎯 学习成果

完成本练习后，你应该能够：

1. **创建Pod**: 使用命令行和YAML文件
2. **管理Pod**: 查看状态、日志、执行命令
3. **调试Pod**: 排查启动失败和运行问题
4. **理解概念**: Pod生命周期、多容器模式
5. **配置资源**: 环境变量、资源限制

**准备就绪标志**: 能够独立创建、管理和调试Pod，理解Pod的基本工作原理。

**下一步**: 继续学习Deployment，了解如何管理Pod副本和滚动更新。