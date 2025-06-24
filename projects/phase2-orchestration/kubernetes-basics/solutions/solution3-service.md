# 练习3解答：Service网络配置和服务发现

## 📋 解答要点

### 步骤1：准备测试环境

```bash
# 确保有运行中的Deployment
kubectl apply -f ../manifests/nginx-deployment.yaml

# 验证Pod运行状态
kubectl get pods -l app=nginx
# 应显示3个Running状态的Pod

# 获取Pod IP地址用于后续对比
kubectl get pods -l app=nginx -o wide
# 记录Pod的IP地址，例如：10.244.0.10, 10.244.0.11, 10.244.0.12
```

### 步骤2：创建ClusterIP Service

#### 命令行方式
```bash
# 创建ClusterIP Service
kubectl expose deployment nginx-deployment --type=ClusterIP --port=80

# 查看Service信息
kubectl get services
# 输出应包含：
# NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# nginx-deployment   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    1m

kubectl describe service nginx-deployment
# 关键信息：
# Type: ClusterIP
# IP: 10.96.xxx.xxx
# Port: 80/TCP
# TargetPort: 80/TCP
# Endpoints: <Pod IPs>:80
```

#### YAML文件方式
```yaml
# nginx-clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-clusterip-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
```

```bash
# 应用YAML配置
kubectl apply -f nginx-clusterip-service.yaml

# 验证Service和Endpoints
kubectl get service nginx-clusterip-service
kubectl get endpoints nginx-clusterip-service
# Endpoints应显示所有nginx Pod的IP:80
```

### 步骤3：测试ClusterIP Service

```bash
# 创建测试Pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# 在测试Pod内执行以下测试：

# 1. DNS解析测试
nslookup nginx-clusterip-service
# 输出应显示Service的ClusterIP

# 2. HTTP访问测试
wget -qO- http://nginx-clusterip-service
# 应返回nginx默认页面HTML

# 3. 负载均衡测试
for i in {1..10}; do
  wget -qO- http://nginx-clusterip-service | grep -o 'nginx/[0-9.]*'
done
# 多次请求应分发到不同的Pod

# 4. 完整域名测试
nslookup nginx-clusterip-service.default.svc.cluster.local
# 应解析到相同的ClusterIP

exit  # 退出测试Pod
```

**服务发现验证结果：**
- DNS名称：`nginx-clusterip-service` 解析到ClusterIP
- 完整FQDN：`nginx-clusterip-service.default.svc.cluster.local`
- 负载均衡：请求自动分发到不同的后端Pod

### 步骤4：创建NodePort Service

```bash
# 应用NodePort Service配置
kubectl apply -f ../manifests/nginx-service.yaml

# 查看NodePort Service
kubectl get service nginx-service
# 输出示例：
# NAME           TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx-service  NodePort   10.96.xxx.xxx   <none>        80:30080/TCP   1m

# 获取NodePort端口号
kubectl get service nginx-service -o jsonpath='{.spec.ports[0].nodePort}'
# 应输出端口号，例如：30080
```

### 步骤5：访问NodePort Service

```bash
# 对于Minikube环境
minikube service nginx-service --url
# 输出访问URL，例如：http://192.168.49.2:30080

# 测试访问
curl $(minikube service nginx-service --url)
# 应返回nginx默认页面

# 对于Kind环境（需要端口转发）
kubectl port-forward service/nginx-service 8080:80
# 在另一个终端测试：curl http://localhost:8080

# 使用节点IP直接访问（如果知道节点IP）
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl get service nginx-service -o jsonpath='{.spec.ports[0].nodePort}')
curl http://$NODE_IP:$NODE_PORT
```

### 步骤6：创建LoadBalancer Service

```bash
# 将NodePort Service转换为LoadBalancer
kubectl patch service nginx-service -p '{"spec":{"type":"LoadBalancer"}}'

# 查看LoadBalancer状态
kubectl get service nginx-service
# 在本地环境中，EXTERNAL-IP可能显示为<pending>，这是正常的

# 描述Service查看详情
kubectl describe service nginx-service
# Events部分可能显示没有可用的负载均衡器
```

**注意：** 在本地环境（Minikube/Kind）中，LoadBalancer类型的Service通常无法获得外部IP，因为没有云提供商的负载均衡器支持。

## 🔧 进阶练习解答

### 多端口Service解答

```yaml
# multi-port-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-port
  template:
    metadata:
      labels:
        app: multi-port
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: multi-port-service
spec:
  selector:
    app: multi-port
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  - name: https
    port: 443
    targetPort: https
    protocol: TCP
  type: ClusterIP
```

```bash
# 部署和验证
kubectl apply -f multi-port-app.yaml

# 查看Service端口配置
kubectl describe service multi-port-service
# 应显示两个端口映射：80->80 和 443->443

# 测试多端口访问
kubectl run test-client --image=busybox --rm -it --restart=Never -- sh
# 在容器内测试：
# wget -qO- http://multi-port-service:80
# wget -qO- http://multi-port-service:443
```

### 服务发现机制解答

```yaml
# service-discovery-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: service-discovery-test
spec:
  containers:
  - name: test-container
    image: busybox
    command: ['sleep', '3600']
```

```bash
# 创建测试Pod
kubectl apply -f service-discovery-test.yaml

# 进入Pod测试服务发现
kubectl exec -it service-discovery-test -- sh

# 在Pod内执行测试：

# 1. 查看Service相关环境变量
env | grep -i nginx
# 输出示例：
# NGINX_SERVICE_SERVICE_HOST=10.96.xxx.xxx
# NGINX_SERVICE_SERVICE_PORT=80
# NGINX_SERVICE_PORT_80_TCP=tcp://10.96.xxx.xxx:80

# 2. DNS解析测试
nslookup nginx-service
# 输出：
# Server: 10.96.0.10
# Address: 10.96.0.10:53
# Name: nginx-service.default.svc.cluster.local
# Address: 10.96.xxx.xxx

# 3. 完整域名解析
nslookup nginx-service.default.svc.cluster.local
# 应解析到相同的Service IP

# 4. 跨命名空间服务发现
nslookup kubernetes.default.svc.cluster.local
# 应解析到Kubernetes API Server的Service IP

exit
```

**服务发现机制总结：**
1. **环境变量**：自动注入Service的HOST和PORT
2. **DNS短名称**：`service-name` 在同一命名空间内有效
3. **DNS全名**：`service-name.namespace.svc.cluster.local` 跨命名空间有效

### Headless Service解答

```yaml
# nginx-headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless-service
spec:
  clusterIP: None  # 关键：设置为None创建Headless Service
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

```bash
# 创建Headless Service
kubectl apply -f nginx-headless-service.yaml

# 测试DNS解析差异
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup nginx-headless-service

# 输出对比：
# 普通Service：返回单个ClusterIP
# Headless Service：返回所有Pod的IP地址列表

# 详细DNS测试
kubectl exec -it service-discovery-test -- nslookup nginx-headless-service
# 应看到多个IP地址，对应每个Pod的IP
```

**Headless Service特点：**
- 不分配ClusterIP（clusterIP: None）
- DNS解析返回所有匹配Pod的IP地址
- 适用于有状态应用（如数据库集群）

### ExternalName Service解答

```yaml
# external-web-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: external-web-service
spec:
  type: ExternalName
  externalName: www.google.com
  ports:
  - port: 80
    protocol: TCP
```

```bash
# 创建ExternalName Service
kubectl apply -f external-web-service.yaml

# 测试外部服务映射
kubectl run external-test --image=busybox --rm -it --restart=Never -- nslookup external-web-service

# 输出应显示：
# external-web-service.default.svc.cluster.local canonical name = www.google.com

# 测试HTTP访问（如果网络允许）
kubectl exec -it service-discovery-test -- wget -qO- http://external-web-service
```

**ExternalName Service用途：**
- 将外部服务映射到集群内的DNS名称
- 便于应用迁移和服务抽象
- 不创建Endpoints，直接DNS CNAME记录

## 🌐 网络连通性测试解答

### 负载均衡测试

```yaml
# load-balance-test.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-balance-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: lb-test
  template:
    metadata:
      labels:
        app: lb-test
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args: ["-c", "echo 'Pod: '$(hostname) > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
---
apiVersion: v1
kind: Service
metadata:
  name: lb-test-service
spec:
  selector:
    app: lb-test
  ports:
  - port: 80
    targetPort: 80
```

```bash
# 部署负载均衡测试应用
kubectl apply -f load-balance-test.yaml

# 等待Pod就绪
kubectl wait --for=condition=ready pod -l app=lb-test --timeout=60s

# 测试负载均衡
kubectl run test-client --image=busybox --rm -it --restart=Never -- sh
# 在容器内执行：
for i in {1..10}; do
  wget -qO- http://lb-test-service
done

# 输出应显示不同的Pod主机名，证明负载均衡工作
# 例如：
# Pod: load-balance-test-xxx-yyy
# Pod: load-balance-test-xxx-zzz
# Pod: load-balance-test-xxx-www
```

## 🔍 Service深度探索解答

### Service内部机制分析

```bash
# 查看Service的Endpoints
kubectl get endpoints
# 显示所有Service的后端Pod列表

kubectl describe endpoints nginx-service
# 详细显示：
# Addresses: <Pod IP列表>
# Ports: 80/TCP

# 查看Service的YAML配置
kubectl get service nginx-service -o yaml
# 重点关注：
# - spec.selector: 标签选择器
# - spec.ports: 端口映射
# - spec.type: Service类型

# 查看Service在etcd中的存储
kubectl get service nginx-service -o json | jq '.metadata'
```

### kube-proxy工作机制

```bash
# 查看kube-proxy日志
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=50

# 查看kube-proxy配置
kubectl get configmap -n kube-system kube-proxy -o yaml

# 在节点上查看iptables规则（需要节点访问权限）
# iptables -t nat -L | grep nginx-service
# 显示Service的NAT规则

# 查看IPVS规则（如果使用IPVS模式）
# ipvsadm -ln
```

**kube-proxy模式：**
1. **iptables模式**：通过iptables规则实现负载均衡
2. **IPVS模式**：通过IPVS实现更高性能的负载均衡
3. **userspace模式**：较旧的实现方式，性能较低

## 🐛 故障排查解答

### Service无法访问问题

```bash
# 创建标签不匹配的Service
kubectl create service clusterip broken-service --tcp=80:80

# 查看问题现象
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://broken-service --timeout=5
# 应该连接超时或拒绝连接

# 排查步骤
kubectl describe service broken-service
# 查看Selector是否正确

kubectl get endpoints broken-service
# 应该显示<none>，说明没有匹配的Pod

kubectl get pods --show-labels
# 查看Pod标签，找到正确的标签

# 修复Service
kubectl patch service broken-service -p '{"spec":{"selector":{"app":"nginx"}}}'

# 验证修复
kubectl get endpoints broken-service
# 现在应该显示nginx Pod的IP地址

kubectl run verify-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://broken-service
# 应该成功返回nginx页面
```

### 端口配置错误问题

```yaml
# wrong-port-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: wrong-port-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 8080  # 错误：nginx容器监听80端口，不是8080
```

```bash
# 创建错误配置的Service
kubectl apply -f wrong-port-service.yaml

# 测试访问（会失败）
kubectl run port-test --image=busybox --rm -it --restart=Never -- wget -qO- http://wrong-port-service --timeout=5
# 连接被拒绝

# 排查问题
kubectl describe service wrong-port-service
# 查看TargetPort配置

kubectl get pods -l app=nginx -o jsonpath='{.items[0].spec.containers[0].ports}'
# 查看容器实际监听的端口

# 修复端口配置
kubectl patch service wrong-port-service -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'

# 验证修复
kubectl run verify-fix --image=busybox --rm -it --restart=Never -- wget -qO- http://wrong-port-service
# 现在应该成功
```

## 📊 监控和调试工具

### Service状态监控

```bash
# 实时监控Service状态
watch kubectl get services,endpoints

# 查看Service详细状态
kubectl describe service nginx-service

# 查看Service相关事件
kubectl get events --field-selector involvedObject.kind=Service,involvedObject.name=nginx-service

# 监控Pod和Service的关联关系
kubectl get pods,endpoints -l app=nginx

# 查看网络策略（如果有）
kubectl get networkpolicies
```

### 连通性测试工具

```bash
# 创建网络调试Pod
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -- bash

# 在netshoot Pod内可使用更多网络工具：
# nslookup, dig, curl, wget, ping, traceroute, netstat, ss等

# DNS调试
dig nginx-service.default.svc.cluster.local

# 端口连通性测试
nc -zv nginx-service 80

# 路由追踪
traceroute nginx-service

# 网络接口信息
ip addr show
ip route show
```

## 📝 检查清单验证

| 检查项 | 验证命令 | 预期结果 |
|--------|----------|----------|
| ClusterIP Service | `kubectl get svc nginx-clusterip-service` | 显示ClusterIP |
| Service DNS解析 | `kubectl exec test-pod -- nslookup nginx-service` | 解析到Service IP |
| 负载均衡功能 | `for i in {1..5}; do kubectl exec test-pod -- wget -qO- nginx-service; done` | 分发到不同Pod |
| NodePort访问 | `curl $(minikube service nginx-service --url)` | 返回nginx页面 |
| Endpoints更新 | `kubectl scale deployment nginx-deployment --replicas=5 && kubectl get endpoints nginx-service` | Endpoints自动更新 |
| 多端口Service | `kubectl describe svc multi-port-service` | 显示多个端口 |
| Headless Service | `kubectl exec test-pod -- nslookup nginx-headless-service` | 返回Pod IP列表 |

## 💡 关键概念总结

### Service类型对比

| 类型 | ClusterIP | NodePort | LoadBalancer | ExternalName |
|------|-----------|----------|--------------|--------------|
| **访问范围** | 集群内部 | 集群外部 | 集群外部 | 外部服务映射 |
| **IP分配** | 是 | 是 | 是 | 否 |
| **端口映射** | Cluster端口 | Node端口 | LB端口 | N/A |
| **使用场景** | 内部通信 | 开发测试 | 生产环境 | 服务抽象 |

### 服务发现机制

```
1. DNS解析 (推荐)
   service-name → ClusterIP
   service-name.namespace.svc.cluster.local → ClusterIP

2. 环境变量 (自动注入)
   {SERVICE_NAME}_SERVICE_HOST=<ClusterIP>
   {SERVICE_NAME}_SERVICE_PORT=<Port>

3. Headless Service
   service-name → Pod IP列表 (用于有状态应用)
```

### 负载均衡算法

默认情况下，kube-proxy使用随机选择算法进行负载均衡。可以通过Service的`sessionAffinity`字段配置会话亲和性：

```yaml
spec:
  sessionAffinity: ClientIP  # 基于客户端IP的会话保持
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3小时
```

## 🎯 学习成果

完成本练习后，你应该能够：

1. **Service类型掌握**：理解并创建不同类型的Service
2. **服务发现精通**：熟练使用DNS和环境变量进行服务发现
3. **网络调试能力**：诊断和解决Service连通性问题
4. **负载均衡理解**：明白Service如何实现流量分发
5. **高级特性应用**：使用Headless Service和ExternalName Service

**准备就绪标志**：能够为微服务应用设计完整的网络架构，包括内部通信和外部访问策略。

**下一步**：现在你已经掌握了Kubernetes的核心资源对象，可以开始将复杂的微服务应用部署到Kubernetes集群中了！