# 练习 1: 环境搭建和验证

> **目标**: 安装 Istio 服务网格并验证基本功能

## 📋 练习概述

在这个练习中，您将：
1. 安装 Istio 服务网格
2. 部署示例应用
3. 验证 sidecar 注入
4. 测试基本功能

## 🎯 学习目标

- 理解 Istio 安装过程
- 掌握 sidecar 注入机制
- 学会验证服务网格状态
- 熟悉基本的 istioctl 命令

## 📚 前置知识

- Kubernetes 基础概念
- kubectl 命令使用
- 容器和 Pod 概念

## 🛠️ 实践步骤

### 步骤 1: 环境准备

1. **检查集群状态**
```bash
# 检查集群信息
kubectl cluster-info

# 检查节点状态
kubectl get nodes

# 检查可用资源
kubectl top nodes
```

2. **设置环境变量**
```bash
export ISTIO_VERSION=1.20.0
export NAMESPACE=istio-system
```

### 步骤 2: 安装 Istio

1. **运行安装脚本**
```bash
# 进入项目目录
cd projects/phase2-orchestration/service-mesh-intro

# 运行安装脚本
./istio/install.sh
```

2. **验证安装**
```bash
# 检查 Istio 组件
kubectl get pods -n istio-system

# 检查服务状态
kubectl get svc -n istio-system

# 运行 istioctl 分析
istioctl analyze
```

**预期结果**: 所有 Istio 组件都处于 Running 状态

### 步骤 3: 启用 Sidecar 注入

1. **为命名空间启用自动注入**
```bash
# 启用自动注入
kubectl label namespace default istio-injection=enabled

# 验证标签
kubectl get namespace -L istio-injection
```

2. **检查注入配置**
```bash
# 查看注入配置
kubectl get configmap istio-sidecar-injector -n istio-system -o yaml
```

### 步骤 4: 部署示例应用

1. **部署 Bookinfo 应用**
```bash
# 部署应用
kubectl apply -f apps/bookinfo/bookinfo.yaml

# 检查部署状态
kubectl get pods
```

2. **验证 sidecar 注入**
```bash
# 检查容器数量（应该是 2 个容器）
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}'

# 查看 Pod 详细信息
kubectl describe pod <pod-name>
```

**预期结果**: 每个 Pod 都包含应用容器和 istio-proxy 容器

### 步骤 5: 配置网关

1. **部署 Gateway 和 VirtualService**
```bash
# 应用网关配置
kubectl apply -f apps/bookinfo/gateway.yaml

# 检查配置
kubectl get gateway
kubectl get virtualservice
```

2. **获取访问地址**
```bash
# 获取 Ingress Gateway 地址
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "Gateway URL: $GATEWAY_URL"
```

### 步骤 6: 验证应用访问

1. **测试应用访问**
```bash
# 访问 Bookinfo 应用
curl -s "http://$GATEWAY_URL/productpage" | grep -o "<title>.*</title>"

# 多次访问查看不同版本
for i in {1..10}; do
  curl -s "http://$GATEWAY_URL/productpage" | grep -A 5 -B 5 "reviews"
  echo "---"
done
```

2. **部署测试客户端**
```bash
# 部署 sleep 客户端
kubectl apply -f apps/sleep/sleep.yaml

# 等待部署完成
kubectl wait --for=condition=available --timeout=300s deployment/sleep
```

3. **测试服务间通信**
```bash
# 获取 sleep pod 名称
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}')

# 测试内部服务访问
kubectl exec -it $SLEEP_POD -- curl productpage:9080/productpage | grep -o "<title>.*</title>"
```

## ✅ 验证检查点

### 基础验证
- [ ] Istio 控制平面所有组件正常运行
- [ ] default 命名空间启用了 sidecar 自动注入
- [ ] Bookinfo 应用成功部署并包含 sidecar
- [ ] Gateway 和 VirtualService 配置正确

### 功能验证
- [ ] 可以通过 Ingress Gateway 访问 Bookinfo 应用
- [ ] 应用显示正确的页面内容
- [ ] 服务间通信正常工作
- [ ] istioctl 命令可以正常使用

### 高级验证
- [ ] 可以看到不同版本的 reviews 服务响应
- [ ] 代理配置正确加载
- [ ] 访问日志正常记录

## 🔍 故障排查

### 常见问题

1. **Pod 启动失败**
```bash
# 查看 Pod 状态
kubectl describe pod <pod-name>

# 查看容器日志
kubectl logs <pod-name> -c <container-name>
```

2. **Sidecar 未注入**
```bash
# 检查命名空间标签
kubectl get namespace default --show-labels

# 重新部署应用
kubectl delete -f apps/bookinfo/bookinfo.yaml
kubectl apply -f apps/bookinfo/bookinfo.yaml
```

3. **无法访问应用**
```bash
# 检查服务状态
kubectl get svc

# 检查 Gateway 配置
kubectl describe gateway bookinfo-gateway

# 检查 Ingress Gateway 状态
kubectl get pods -n istio-system -l istio=ingressgateway
```

## 🎓 深入理解

### Sidecar 模式
- 每个应用 Pod 都会注入一个 Envoy 代理容器
- 代理拦截所有进出流量
- 提供负载均衡、安全、监控等功能

### Istio 组件
- **Istiod**: 控制平面，管理配置和证书
- **Envoy Proxy**: 数据平面，处理流量
- **Ingress Gateway**: 管理进入网格的流量

### 配置资源
- **Gateway**: 定义进入网格的入口点
- **VirtualService**: 定义路由规则
- **DestinationRule**: 定义目标服务的策略

## 📝 练习总结

完成这个练习后，您应该：
- 成功安装了 Istio 服务网格
- 理解了 sidecar 注入的工作原理
- 掌握了基本的验证方法
- 熟悉了 istioctl 工具的使用

## 🚀 下一步

继续进行 [练习 2: 流量管理基础](./02-traffic-management-basics.md)，学习如何控制服务间的流量路由。
