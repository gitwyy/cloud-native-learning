# 🚨 常见问题解决方案

> 云原生学习过程中常见问题的排查和解决方法

## 📋 目录

- [Docker相关问题](#docker相关问题)
- [Kubernetes相关问题](#kubernetes相关问题)
- [网络连接问题](#网络连接问题)
- [性能和资源问题](#性能和资源问题)
- [监控和日志问题](#监控和日志问题)
- [安全和权限问题](#安全和权限问题)
- [开发环境问题](#开发环境问题)

---

## 🐳 Docker相关问题

### 问题1：Docker守护进程连接失败

**错误信息**：
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**可能原因**：
- Docker服务未启动
- 用户权限不足
- Docker Socket权限问题

**解决方案**：

#### 方案1：启动Docker服务
```bash
# Ubuntu/Debian
sudo systemctl start docker
sudo systemctl enable docker

# macOS (Docker Desktop)
# 启动Docker Desktop应用程序

# Windows (Docker Desktop)
# 启动Docker Desktop应用程序
```

#### 方案2：添加用户到docker组
```bash
# 添加当前用户到docker组
sudo usermod -aG docker $USER

# 重新加载组权限
newgrp docker

# 或者重新登录系统
```

#### 方案3：检查Docker状态
```bash
# 检查Docker服务状态
sudo systemctl status docker

# 查看Docker版本
docker --version

# 测试Docker连接
docker info
```

### 问题2：镜像拉取失败

**错误信息**：
```
Error response from daemon: pull access denied for xxx, repository does not exist
```

**可能原因**：
- 网络连接问题
- 镜像名称错误
- 私有仓库认证失败
- 镜像不存在

**解决方案**：

#### 方案1：检查镜像名称
```bash
# 检查镜像名称格式
docker pull nginx:latest
docker pull docker.io/library/nginx:latest

# 搜索可用镜像
docker search nginx
```

#### 方案2：配置国内镜像源
```bash
# 创建或编辑daemon.json
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://reg-mirror.qiniu.com"
  ]
}
EOF

# 重启Docker服务
sudo systemctl restart docker
```

#### 方案3：私有仓库登录
```bash
# 登录私有仓库
docker login registry.example.com
docker login -u username -p password registry.example.com

# 拉取私有镜像
docker pull registry.example.com/myapp:latest
```

### 问题3：容器内存不足

**错误信息**：
```
container killed due to memory limit
```

**解决方案**：

```bash
# 查看容器资源使用
docker stats

# 增加内存限制
docker run -m 512m nginx

# 查看系统内存
free -h
df -h
```

### 问题4：端口冲突

**错误信息**：
```
bind: address already in use
```

**解决方案**：

```bash
# 查看端口占用
sudo netstat -tulpn | grep :8080
sudo lsof -i :8080

# 使用不同端口
docker run -p 8081:80 nginx

# 停止占用端口的容器
docker ps
docker stop <container_id>
```

---

## ⚙️ Kubernetes相关问题

### 问题1：kubectl连接集群失败

**错误信息**：
```
The connection to the server localhost:8080 was refused
```

**可能原因**：
- kubeconfig配置错误
- 集群未启动
- 网络连接问题

**解决方案**：

#### 方案1：检查kubeconfig
```bash
# 查看当前配置
kubectl config view

# 查看当前上下文
kubectl config current-context

# 切换上下文
kubectl config use-context minikube

# 设置kubeconfig环境变量
export KUBECONFIG=~/.kube/config
```

#### 方案2：检查集群状态
```bash
# Minikube
minikube status
minikube start

# Kind
kind get clusters
kind create cluster

# 检查集群信息
kubectl cluster-info
```

### 问题2：Pod处于Pending状态

**可能原因**：
- 资源不足
- 调度约束
- 镜像拉取失败
- 存储卷问题

**解决方案**：

```bash
# 查看Pod详细信息
kubectl describe pod <pod-name>

# 查看事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 查看节点资源
kubectl describe nodes

# 查看资源使用情况
kubectl top nodes
kubectl top pods
```

#### 具体问题排查：

**资源不足**：
```bash
# 检查节点资源
kubectl describe node <node-name>

# 查看资源配额
kubectl describe resourcequota

# 调整资源请求
kubectl edit deployment <deployment-name>
```

**镜像拉取失败**：
```bash
# 检查镜像拉取策略
kubectl describe pod <pod-name>

# 手动拉取镜像测试
docker pull <image-name>

# 创建镜像拉取密钥
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>
```

### 问题3：Service无法访问

**可能原因**：
- 标签选择器错误
- 端口配置错误
- 网络策略阻止
- DNS解析问题

**解决方案**：

```bash
# 检查Service配置
kubectl describe service <service-name>

# 检查Endpoint
kubectl get endpoints <service-name>

# 测试Service连通性
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
# 在Pod内测试
nslookup <service-name>
wget -qO- http://<service-name>:<port>

# 检查网络策略
kubectl get networkpolicy
```

### 问题4：ConfigMap或Secret未生效

**解决方案**：

```bash
# 检查ConfigMap
kubectl describe configmap <configmap-name>

# 检查Secret
kubectl describe secret <secret-name>

# 查看Pod中的挂载
kubectl exec <pod-name> -- ls -la /path/to/mount

# 重启Pod使配置生效
kubectl rollout restart deployment <deployment-name>
```

---

## 🌐 网络连接问题

### 问题1：无法访问外部服务

**解决方案**：

```bash
# 检查DNS配置
kubectl exec <pod-name> -- nslookup google.com

# 检查网络策略
kubectl get networkpolicy

# 测试网络连通性
kubectl exec <pod-name> -- ping 8.8.8.8
kubectl exec <pod-name> -- curl -I https://google.com
```

### 问题2：Pod间通信失败

**解决方案**：

```bash
# 检查CNI插件状态
kubectl get pods -n kube-system | grep -E "calico|flannel|weave"

# 检查Pod IP
kubectl get pods -o wide

# 测试Pod间连通性
kubectl exec pod1 -- ping <pod2-ip>
```

### 问题3：Ingress无法访问

**解决方案**：

```bash
# 检查Ingress Controller
kubectl get pods -n ingress-nginx

# 检查Ingress配置
kubectl describe ingress <ingress-name>

# 检查Service后端
kubectl get endpoints

# 测试本地访问
curl -H "Host: example.com" http://<ingress-ip>
```

---

## 📊 性能和资源问题

### 问题1：集群性能差

**诊断方法**：

```bash
# 查看集群资源使用
kubectl top nodes
kubectl top pods --all-namespaces

# 查看系统负载
top
htop
iostat -x 1

# 查看磁盘使用
df -h
du -sh /var/lib/docker
```

**优化建议**：

```bash
# 清理未使用的Docker资源
docker system prune -a

# 清理未使用的Kubernetes资源
kubectl delete pods --field-selector=status.phase=Succeeded
kubectl delete pods --field-selector=status.phase=Failed

# 调整资源限制
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"limits":{"memory":"1Gi","cpu":"500m"}}}]}}}}'
```

### 问题2：内存不足

**解决方案**：

```bash
# 检查内存使用
free -h
cat /proc/meminfo

# 查看大内存进程
ps aux --sort=-%mem | head

# 增加虚拟内存
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 问题3：磁盘空间不足

**解决方案**：

```bash
# 查看磁盘使用
df -h
du -sh /* | sort -rh

# 清理Docker
docker system prune -a
docker volume prune

# 清理日志
sudo journalctl --vacuum-time=7d
sudo find /var/log -name "*.log" -exec truncate -s 0 {} \;

# 清理Kubernetes
kubectl delete pods --all-namespaces --field-selector=status.phase=Succeeded
```

---

## 📋 监控和日志问题

### 问题1：Prometheus无法抓取指标

**解决方案**：

```bash
# 检查ServiceMonitor配置
kubectl describe servicemonitor <name>

# 检查Service标签
kubectl describe service <service-name>

# 查看Prometheus配置
kubectl exec -n monitoring prometheus-0 -- cat /etc/prometheus/prometheus.yml

# 检查网络连通性
kubectl exec -n monitoring prometheus-0 -- wget -qO- http://<service>:<port>/metrics
```

### 问题2：Grafana无法显示数据

**解决方案**：

```bash
# 检查数据源配置
# 在Grafana UI中：Configuration -> Data Sources

# 测试PromQL查询
# 在Prometheus UI中测试查询语句

# 检查时间范围
# 确保查询的时间范围内有数据

# 查看Grafana日志
kubectl logs -n monitoring grafana-xxx
```

### 问题3：日志收集不完整

**解决方案**：

```bash
# 检查Fluentd/Fluent Bit状态
kubectl get pods -n logging

# 查看日志收集器配置
kubectl describe configmap fluentd-config -n logging

# 检查Elasticsearch状态
kubectl exec -n logging elasticsearch-0 -- curl -X GET "localhost:9200/_cluster/health"

# 测试日志收集
kubectl logs <pod-name> | head -10
```

---

## 🔒 安全和权限问题

### 问题1：RBAC权限不足

**错误信息**：
```
forbidden: User "system:serviceaccount:default:default" cannot create pods
```

**解决方案**：

```bash
# 查看当前权限
kubectl auth can-i create pods

# 查看ServiceAccount
kubectl get serviceaccount

# 创建ClusterRoleBinding
kubectl create clusterrolebinding default-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=default:default

# 创建Role和RoleBinding
kubectl create role pod-reader --verb=get,list,watch --resource=pods
kubectl create rolebinding default-pod-reader \
  --role=pod-reader \
  --serviceaccount=default:default
```

### 问题2：镜像安全扫描失败

**解决方案**：

```bash
# 使用Trivy扫描镜像
trivy image nginx:latest

# 查看扫描结果
trivy image --severity HIGH,CRITICAL nginx:latest

# 使用安全的基础镜像
# 选择官方、最小化的镜像
# 及时更新镜像版本
```

### 问题3：Pod安全策略违反

**解决方案**：

```bash
# 查看Pod安全策略
kubectl get podsecuritypolicy

# 检查Pod安全上下文
kubectl describe pod <pod-name>

# 修改安全上下文
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
```

---

## 💻 开发环境问题

### 问题1：本地开发环境不一致

**解决方案**：

```bash
# 使用开发容器
# .devcontainer/devcontainer.json
{
  "name": "Cloud Native Dev",
  "image": "mcr.microsoft.com/vscode/devcontainers/kubernetes:latest",
  "features": {
    "docker-in-docker": "latest",
    "kubectl-helm-minikube": "latest"
  }
}

# 使用Docker Compose开发环境
version: '3.8'
services:
  dev:
    build: .
    volumes:
      - .:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - KUBECONFIG=/workspace/.kube/config
```

### 问题2：热重载不工作

**解决方案**：

```yaml
# Kubernetes开发配置
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:dev
        volumeMounts:
        - name: source-code
          mountPath: /app
        env:
        - name: NODE_ENV
          value: development
      volumes:
      - name: source-code
        hostPath:
          path: /path/to/source
```

### 问题3：IDE插件问题

**VSCode Kubernetes插件问题**：

```bash
# 重新加载窗口
Ctrl+Shift+P -> Developer: Reload Window

# 检查kubectl配置
kubectl config view

# 更新插件
Ctrl+Shift+X -> 搜索Kubernetes -> 更新
```

---

## 🛠️ 通用排查方法

### 日志查看技巧

```bash
# 查看Pod日志
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>
kubectl logs <pod-name> --previous

# 实时查看日志
kubectl logs -f <pod-name>

# 查看系统日志
sudo journalctl -u docker
sudo journalctl -u kubelet

# 查看事件
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events --field-selector type=Warning
```

### 网络调试技巧

```bash
# 创建调试Pod
kubectl run debug --image=busybox --rm -it -- /bin/sh

# 网络连通性测试
ping <ip>
nslookup <domain>
telnet <ip> <port>
curl -v http://<service>:<port>

# 查看网络配置
ip addr show
ip route show
cat /etc/resolv.conf
```

### 资源调试技巧

```bash
# 查看资源使用
kubectl top nodes
kubectl top pods

# 查看资源配额
kubectl describe resourcequota

# 查看限制范围
kubectl describe limitrange

# 临时扩容资源
kubectl scale deployment <name> --replicas=0
kubectl scale deployment <name> --replicas=1
```

---

## 📞 获取帮助

### 社区资源
- **Stack Overflow**: kubernetes, docker标签
- **GitHub Issues**: 相关项目的issues页面
- **Slack社区**: Kubernetes Slack
- **Reddit**: r/kubernetes, r/docker

### 官方文档
- **Kubernetes排错指南**: [https://kubernetes.io/docs/tasks/debug-application-cluster/](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- **Docker故障排除**: [https://docs.docker.com/config/troubleshooting/](https://docs.docker.com/config/troubleshooting/)

### 诊断工具
- **kubectl**: 官方命令行工具
- **k9s**: 终端UI管理工具
- **Lens**: 桌面Kubernetes IDE
- **Octant**: Web界面集群管理

---

**💡 记住**：遇到问题时，首先查看日志和事件，然后逐步缩小问题范围。大多数问题都有标准的解决方案，保持耐心和系统性的排查方法是关键！ 🚀