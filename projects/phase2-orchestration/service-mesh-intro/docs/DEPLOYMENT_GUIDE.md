# 🚀 Istio 服务网格部署指南

> 详细的 Istio 安装、配置和部署步骤

## 📋 部署概览

本指南将引导您完成 Istio 服务网格的完整部署过程，包括：
- 环境准备和前置条件检查
- Istio 控制平面安装
- 示例应用部署和配置
- 功能验证和测试

## 🔧 环境要求

### 硬件要求
- **CPU**: 最少 2 核，推荐 4 核以上
- **内存**: 最少 4GB，推荐 8GB 以上
- **存储**: 最少 20GB 可用空间

### 软件要求
- **Kubernetes**: v1.22.0 或更高版本
- **kubectl**: 与集群版本兼容
- **curl**: 用于下载和测试
- **操作系统**: Linux、macOS 或 Windows (WSL2)

### 集群要求
```bash
# 检查集群版本
kubectl version --short

# 检查节点状态
kubectl get nodes

# 检查可用资源
kubectl top nodes
```

## 📦 Istio 安装

### 方法一：使用 istioctl (推荐)

#### 1. 下载 Istio
```bash
# 设置版本变量
export ISTIO_VERSION=1.20.0

# 下载 Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -

# 添加到 PATH
export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH

# 验证安装
istioctl version
```

#### 2. 预检查
```bash
# 检查集群兼容性
istioctl x precheck

# 分析集群配置
istioctl analyze
```

#### 3. 安装控制平面
```bash
# 使用默认配置安装
istioctl install --set values.defaultRevision=default

# 或使用自定义配置
istioctl install --set values.pilot.traceSampling=100.0

# 验证安装
kubectl get pods -n istio-system
```

### 方法二：使用 Helm

#### 1. 添加 Helm 仓库
```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

#### 2. 安装基础组件
```bash
# 创建命名空间
kubectl create namespace istio-system

# 安装 Istio base
helm install istio-base istio/base -n istio-system

# 安装 Istiod
helm install istiod istio/istiod -n istio-system --wait
```

#### 3. 安装 Ingress Gateway
```bash
# 创建命名空间
kubectl create namespace istio-ingress

# 安装 Gateway
helm install istio-ingress istio/gateway -n istio-ingress --wait
```

## 🏷️ Sidecar 注入配置

### 自动注入
```bash
# 为命名空间启用自动注入
kubectl label namespace default istio-injection=enabled

# 验证标签
kubectl get namespace -L istio-injection
```

### 手动注入
```bash
# 手动注入 sidecar
istioctl kube-inject -f app.yaml | kubectl apply -f -

# 或使用注解
metadata:
  annotations:
    sidecar.istio.io/inject: "true"
```

## 📱 示例应用部署

### 1. Bookinfo 应用

#### 部署应用
```bash
# 部署 Bookinfo 应用
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml

# 验证部署
kubectl get services
kubectl get pods
```

#### 配置 Gateway
```bash
# 应用 Gateway 配置
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/networking/bookinfo-gateway.yaml

# 验证 Gateway
kubectl get gateway
```

#### 获取访问地址
```bash
# 获取 Ingress IP
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

# 测试访问
curl -s "http://${GATEWAY_URL}/productpage" | grep -o "<title>.*</title>"
```

### 2. HTTPBin 测试服务

```bash
# 部署 HTTPBin
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/httpbin.yaml

# 部署 Sleep 客户端
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/sleep/sleep.yaml
```

## 🔧 插件安装

### 1. Prometheus (监控)
```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
```

### 2. Grafana (可视化)
```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml

# 访问 Grafana
istioctl dashboard grafana
```

### 3. Jaeger (分布式追踪)
```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml

# 访问 Jaeger
istioctl dashboard jaeger
```

### 4. Kiali (服务网格可视化)
```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# 访问 Kiali
istioctl dashboard kiali
```

## ✅ 部署验证

### 1. 控制平面验证
```bash
# 检查 Istio 组件状态
kubectl get pods -n istio-system

# 检查 Istio 配置
istioctl analyze

# 查看代理状态
istioctl proxy-status
```

### 2. 数据平面验证
```bash
# 检查 sidecar 注入
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}'

# 验证代理配置
istioctl proxy-config cluster <pod-name>

# 检查监听器
istioctl proxy-config listeners <pod-name>
```

### 3. 网络连通性测试
```bash
# 从 sleep pod 测试连接
kubectl exec -it $(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl httpbin:8000/ip

# 测试外部访问
curl -s "http://${GATEWAY_URL}/productpage"
```

## 🔧 配置优化

### 1. 资源限制
```yaml
# 为 sidecar 设置资源限制
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-sidecar-injector
  namespace: istio-system
data:
  config: |
    policy: enabled
    template: |
      spec:
        containers:
        - name: istio-proxy
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
```

### 2. 性能调优
```bash
# 调整并发连接数
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false \
  --set values.global.proxy.resources.requests.cpu=100m \
  --set values.global.proxy.resources.requests.memory=128Mi
```

### 3. 安全配置
```yaml
# 启用严格 mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

## 🧹 清理和卸载

### 清理示例应用
```bash
# 清理 Bookinfo
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/networking/bookinfo-gateway.yaml

# 清理插件
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/
```

### 卸载 Istio
```bash
# 使用 istioctl 卸载
istioctl uninstall --purge

# 删除命名空间
kubectl delete namespace istio-system

# 移除注入标签
kubectl label namespace default istio-injection-
```

## 🔍 故障排查

### 常见问题

#### 1. Pod 启动失败
```bash
# 检查 Pod 状态
kubectl describe pod <pod-name>

# 查看 sidecar 日志
kubectl logs <pod-name> -c istio-proxy
```

#### 2. 网络连接问题
```bash
# 检查服务发现
istioctl proxy-config endpoints <pod-name>

# 验证路由配置
istioctl proxy-config routes <pod-name>
```

#### 3. 证书问题
```bash
# 检查证书状态
istioctl proxy-config secret <pod-name>

# 验证 mTLS 配置
istioctl authn tls-check <pod-name>.<namespace>
```

## 📚 参考资源

- [Istio 官方安装指南](https://istio.io/latest/docs/setup/getting-started/)
- [Kubernetes 集群要求](https://istio.io/latest/docs/setup/platform-setup/)
- [性能和可扩展性](https://istio.io/latest/docs/ops/deployment/performance-and-scalability/)
- [生产部署最佳实践](https://istio.io/latest/docs/ops/best-practices/)

---

**部署完成后，请继续阅读 [学习指南](./LEARNING_GUIDE.md) 开始您的服务网格实践！** 🎉
