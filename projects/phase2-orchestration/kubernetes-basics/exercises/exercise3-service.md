# 练习3：Service网络配置和服务发现

## 🎯 学习目标

- 理解Service的作用和类型
- 掌握不同类型Service的创建和配置
- 学会服务发现和负载均衡机制
- 了解网络策略和端口映射

## 📋 前置条件

- 完成练习1和练习2
- 有运行中的Deployment
- 理解Kubernetes网络基础概念

## 🚀 练习步骤

### 步骤1：准备测试环境

首先确保有一个运行中的Deployment：

```bash
# 创建测试用的Deployment
kubectl apply -f ../manifests/nginx-deployment.yaml

# 验证Pod运行状态
kubectl get pods -l app=nginx

# 获取Pod IP地址
kubectl get pods -l app=nginx -o wide
```

### 步骤2：创建ClusterIP Service

#### 方法一：命令行创建
```bash
# 创建ClusterIP Service
kubectl expose deployment nginx-deployment --type=ClusterIP --port=80

# 查看Service信息
kubectl get services
kubectl describe service nginx-deployment
```

#### 方法二：YAML文件创建
```yaml
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
# 应用配置
kubectl apply -f nginx-clusterip-service.yaml

# 查看Service和Endpoints
kubectl get service nginx-clusterip-service
kubectl get endpoints nginx-clusterip-service
```

### 步骤3：测试ClusterIP Service

```bash
# 创建测试Pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# 在测试Pod中执行：
# 1. 测试Service名称解析
nslookup nginx-clusterip-service

# 2. 测试HTTP访问
wget -qO- http://nginx-clusterip-service

# 3. 测试负载均衡
for i in {1..10}; do
  wget -qO- http://nginx-clusterip-service | grep -o 'nginx/[0-9.]*'
done

# 退出测试Pod
exit
```

### 步骤4：创建NodePort Service

```bash
# 应用NodePort Service配置
kubectl apply -f ../manifests/nginx-service.yaml

# 查看NodePort Service
kubectl get service nginx-service

# 获取NodePort端口
kubectl get service nginx-service -o jsonpath='{.spec.ports[0].nodePort}'
```

### 步骤5：访问NodePort Service

```bash
# 对于Minikube
minikube service nginx-service --url

# 对于Kind
kubectl port-forward service/nginx-service 8080:80

# 使用浏览器或curl访问
curl http://localhost:8080
```

### 步骤6：创建LoadBalancer Service

```bash
# 创建LoadBalancer Service
kubectl patch service nginx-service -p '{"spec":{"type":"LoadBalancer"}}'

# 查看LoadBalancer状态
kubectl get service nginx-service

# 注意：在本地环境中，LoadBalancer可能显示为Pending状态
# 这是正常的，因为没有云提供商的负载均衡器
```

## 🔧 进阶练习

### 练习A：多端口Service

```yaml
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
  - name: https
    port: 443
    targetPort: https
  type: ClusterIP
```

```bash
# 创建多端口应用
kubectl apply -f multi-port-app.yaml

# 查看Service端口配置
kubectl describe service multi-port-service
```

### 练习B：服务发现机制

```yaml
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

# 在Pod内执行以下命令：
# 1. 查看环境变量
env | grep NGINX

# 2. 测试DNS解析
nslookup nginx-service

# 3. 查看完整域名解析
nslookup nginx-service.default.svc.cluster.local

# 4. 测试不同命名空间的服务发现
nslookup kubernetes.default.svc.cluster.local
```

### 练习C：Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless-service
spec:
  clusterIP: None  # 设置为None创建Headless Service
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

```bash
# 创建Headless Service
kubectl apply -f nginx-headless-service.yaml

# 测试Headless Service的DNS解析
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup nginx-headless-service

# 观察返回的是Pod IP而不是Service IP
```

### 练习D：ExternalName Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-web-service
spec:
  type: ExternalName
  externalName: www.google.com
  ports:
  - port: 80
```

```bash
# 创建ExternalName Service
kubectl apply -f external-web-service.yaml

# 测试外部服务访问
kubectl run external-test --image=busybox --rm -it --restart=Never -- nslookup external-web-service
```

## 🌐 网络连通性测试

### 测试Service负载均衡

创建带有标识的多个Pod来测试负载均衡：

```yaml
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
# 创建负载均衡测试应用
kubectl apply -f load-balance-test.yaml

# 测试负载均衡
for i in {1..10}; do
  kubectl exec test-pod -- wget -qO- http://lb-test-service
done
```

### 网络策略演示（进阶）

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector:
    matchLabels:
      app: nginx
  policyTypes:
  - Ingress
  ingress: []  # 空数组表示拒绝所有入站流量
```

```bash
# 注意：NetworkPolicy需要支持的CNI插件（如Calico）
# 在基础环境中可能不起作用，仅作演示

# 应用网络策略
kubectl apply -f network-policy.yaml

# 测试访问（应该被阻止）
kubectl exec test-pod -- wget -qO- http://nginx-service --timeout=5
```

## 🔍 Service深度探索

### 查看Service内部机制

```bash
# 查看Service的Endpoints
kubectl get endpoints

# 查看Service的详细配置
kubectl get service nginx-service -o yaml

# 查看iptables规则（在节点上）
# 注意：这需要在实际节点上执行
# iptables -t nat -L | grep nginx-service

# 查看kube-proxy日志
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

### 服务监控和调试

```bash
# 监控Service状态
watch kubectl get services

# 查看Service事件
kubectl get events --field-selector involvedObject.kind=Service

# 测试Service连通性
kubectl run connectivity-test --image=busybox --rm -it --restart=Never -- sh
# 在容器内执行网络测试命令
```

## 🐛 故障排查练习

### 练习1：Service无法访问

```bash
# 创建一个标签不匹配的Service
kubectl create service clusterip broken-service --tcp=80:80

# 尝试访问（应该失败）
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://broken-service

# 排查问题
kubectl describe service broken-service
kubectl get endpoints broken-service

# 修复Service
kubectl patch service broken-service -p '{"spec":{"selector":{"app":"nginx"}}}'
```

### 练习2：端口配置错误

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wrong-port-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 8080  # 错误的目标端口
```

```bash
# 创建错误配置的Service
kubectl apply -f wrong-port-service.yaml

# 测试访问（会失败）
kubectl run port-test --image=busybox --rm -it --restart=Never -- wget -qO- http://wrong-port-service

# 排查和修复
kubectl describe service wrong-port-service
kubectl patch service wrong-port-service -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
```

## 📝 练习检查表

完成练习后，确保你能够：

- [ ] 创建不同类型的Service（ClusterIP、NodePort、LoadBalancer）
- [ ] 理解Service选择器和标签匹配机制
- [ ] 配置多端口Service
- [ ] 使用服务发现机制（DNS、环境变量）
- [ ] 创建和使用Headless Service
- [ ] 配置ExternalName Service
- [ ] 测试Service负载均衡功能
- [ ] 理解Endpoints的作用和状态
- [ ] 排查Service连通性问题
- [ ] 监控Service状态和性能

## 🔬 深入理解

### Service工作原理

```
Client Request → Service → Endpoints → Pod
                    ↓
                kube-proxy
                    ↓
              iptables/IPVS rules
```

### 服务发现机制

1. **DNS解析**：
   - 服务名：`service-name`
   - 完整域名：`service-name.namespace.svc.cluster.local`

2. **环境变量**：
   - `{SERVICE_NAME}_SERVICE_HOST`
   - `{SERVICE_NAME}_SERVICE_PORT`

### Service类型对比

| 类型 | 访问范围 | 使用场景 |
|------|----------|----------|
| ClusterIP | 集群内部 | 内部服务通信 |
| NodePort | 外部访问 | 开发测试 |
| LoadBalancer | 外部访问 | 生产环境 |
| ExternalName | 外部服务 | 服务代理 |

## 🎉 小结

通过本练习，你已经掌握了：

1. **Service核心概念**：服务发现和负载均衡
2. **多种Service类型**：适用不同场景的网络配置
3. **服务发现机制**：DNS和环境变量方式
4. **网络调试技能**：排查Service连通性问题
5. **高级网络特性**：Headless Service、网络策略等

**下一步**：完成所有检查点后，你已经具备了Kubernetes基础部署的核心技能！可以开始尝试将第一阶段的完整应用迁移到Kubernetes集群。