# 🔧 服务网格故障排查指南

> 常见问题的诊断和解决方法

## 📋 故障排查概览

本指南涵盖了 Istio 服务网格部署和使用过程中的常见问题，提供系统性的排查方法和解决方案。

## 🔍 通用排查方法

### 1. 基础信息收集

```bash
# 检查集群状态
kubectl cluster-info
kubectl get nodes
kubectl top nodes

# 检查 Istio 组件状态
kubectl get pods -n istio-system
kubectl get svc -n istio-system

# 运行 Istio 分析
istioctl analyze

# 检查代理状态
istioctl proxy-status
```

### 2. 日志收集

```bash
# 查看控制平面日志
kubectl logs -n istio-system deployment/istiod

# 查看 Ingress Gateway 日志
kubectl logs -n istio-system deployment/istio-ingressgateway

# 查看应用的 sidecar 日志
kubectl logs <pod-name> -c istio-proxy

# 查看应用容器日志
kubectl logs <pod-name> -c <app-container>
```

## 🚨 常见问题分类

### 安装和配置问题

#### 问题 1: Istio 安装失败

**症状**:
- istioctl install 命令失败
- 控制平面 Pod 无法启动

**排查步骤**:
```bash
# 检查 Kubernetes 版本兼容性
kubectl version --short

# 检查集群资源
kubectl describe nodes

# 查看安装日志
istioctl install --dry-run

# 检查 CRD 安装
kubectl get crd | grep istio
```

**解决方案**:
```bash
# 清理并重新安装
istioctl uninstall --purge
kubectl delete namespace istio-system

# 使用正确的版本重新安装
istioctl install --set values.defaultRevision=default
```

#### 问题 2: Sidecar 注入失败

**症状**:
- Pod 只有一个容器
- 应用无法通过服务网格通信

**排查步骤**:
```bash
# 检查命名空间标签
kubectl get namespace default --show-labels

# 检查注入配置
kubectl get configmap istio-sidecar-injector -n istio-system

# 查看 Pod 注解
kubectl describe pod <pod-name>
```

**解决方案**:
```bash
# 启用自动注入
kubectl label namespace default istio-injection=enabled

# 重新部署应用
kubectl delete pod <pod-name>

# 或手动注入
istioctl kube-inject -f app.yaml | kubectl apply -f -
```

### 网络连接问题

#### 问题 3: 无法访问应用

**症状**:
- 外部无法访问应用
- 连接超时或拒绝连接

**排查步骤**:
```bash
# 检查 Gateway 配置
kubectl get gateway
kubectl describe gateway <gateway-name>

# 检查 VirtualService 配置
kubectl get virtualservice
kubectl describe virtualservice <vs-name>

# 检查 Ingress Gateway 状态
kubectl get pods -n istio-system -l istio=ingressgateway
kubectl get svc -n istio-system istio-ingressgateway

# 检查端口转发
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

**解决方案**:
```bash
# 修复 Gateway 配置
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF

# 检查 LoadBalancer 服务
kubectl get svc -n istio-system istio-ingressgateway
```

#### 问题 4: 服务间通信失败

**症状**:
- 服务间调用失败
- 连接被拒绝

**排查步骤**:
```bash
# 检查服务发现
kubectl get svc
kubectl get endpoints

# 检查代理配置
istioctl proxy-config cluster <pod-name>
istioctl proxy-config endpoints <pod-name>

# 检查路由配置
istioctl proxy-config routes <pod-name>

# 测试连接
kubectl exec -it <pod-name> -- curl <service-name>:<port>
```

**解决方案**:
```bash
# 检查 DestinationRule
kubectl get destinationrule
kubectl describe destinationrule <dr-name>

# 重置网络策略
kubectl delete networkpolicy --all
```

### 安全策略问题

#### 问题 5: mTLS 认证失败

**症状**:
- 服务间通信被拒绝
- 证书相关错误

**排查步骤**:
```bash
# 检查 mTLS 状态
istioctl authn tls-check <pod-name> <service-name>

# 查看证书
istioctl proxy-config secret <pod-name>

# 检查认证策略
kubectl get peerauthentication
kubectl describe peerauthentication <pa-name>
```

**解决方案**:
```bash
# 启用严格 mTLS
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF

# 或禁用 mTLS 进行测试
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: DISABLE
EOF
```

#### 问题 6: 授权策略阻止访问

**症状**:
- 请求被拒绝 (403 错误)
- 授权失败日志

**排查步骤**:
```bash
# 检查授权策略
kubectl get authorizationpolicy
kubectl describe authorizationpolicy <ap-name>

# 查看访问日志
kubectl logs <pod-name> -c istio-proxy | grep RBAC

# 测试无授权策略的情况
kubectl delete authorizationpolicy --all
```

**解决方案**:
```bash
# 创建允许访问的策略
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-all
  namespace: default
spec:
  rules:
  - {}
EOF
```

### 性能问题

#### 问题 7: 高延迟

**症状**:
- 请求响应时间过长
- 性能下降明显

**排查步骤**:
```bash
# 检查资源使用
kubectl top pods
kubectl top nodes

# 查看代理统计
istioctl proxy-config bootstrap <pod-name>

# 检查连接池设置
kubectl get destinationrule -o yaml

# 分析追踪数据
istioctl dashboard jaeger
```

**解决方案**:
```bash
# 优化连接池配置
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-destination-rule
spec:
  host: my-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        maxRequestsPerConnection: 10
EOF

# 调整资源限制
kubectl patch deployment <deployment-name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"istio-proxy","resources":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"200m","memory":"256Mi"}}}]}}}}'
```

## 🛠️ 高级排查工具

### 1. istioctl 诊断命令

```bash
# 分析配置问题
istioctl analyze

# 检查代理配置
istioctl proxy-config all <pod-name>

# 验证安装
istioctl verify-install

# 检查版本兼容性
istioctl version
```

### 2. 网络调试

```bash
# 端口转发测试
kubectl port-forward <pod-name> 8080:8080

# 网络策略测试
kubectl exec -it <pod-name> -- nc -zv <service-name> <port>

# DNS 解析测试
kubectl exec -it <pod-name> -- nslookup <service-name>
```

### 3. 日志分析

```bash
# 实时查看日志
kubectl logs -f <pod-name> -c istio-proxy

# 过滤特定错误
kubectl logs <pod-name> -c istio-proxy | grep ERROR

# 查看访问日志
kubectl logs <pod-name> -c istio-proxy | grep "GET\|POST"
```

## 📊 监控和告警

### 关键指标监控

```bash
# 检查 Prometheus 指标
kubectl port-forward -n istio-system svc/prometheus 9090:9090

# 访问 Grafana 面板
istioctl dashboard grafana

# 查看 Kiali 服务图
istioctl dashboard kiali
```

### 常见告警规则

- 控制平面组件不可用
- 代理配置同步失败
- 证书即将过期
- 高错误率或延迟

## 🔄 恢复策略

### 1. 配置回滚

```bash
# 查看配置历史
kubectl rollout history deployment/<deployment-name>

# 回滚到上一版本
kubectl rollout undo deployment/<deployment-name>

# 回滚到特定版本
kubectl rollout undo deployment/<deployment-name> --to-revision=2
```

### 2. 紧急恢复

```bash
# 禁用 sidecar 注入
kubectl label namespace default istio-injection-

# 重启所有 Pod
kubectl delete pods --all

# 绕过服务网格
kubectl patch svc <service-name> -p '{"spec":{"selector":{"app":"<app-name>","version":"<version>"}}}'
```

## 📞 获取帮助

### 社区资源
- [Istio 官方文档](https://istio.io/latest/docs/)
- [Istio 社区论坛](https://discuss.istio.io/)
- [GitHub Issues](https://github.com/istio/istio/issues)

### 日志收集脚本
```bash
# 收集诊断信息
istioctl bug-report

# 生成支持包
kubectl cluster-info dump --output-directory=cluster-dump
```

---

**记住**: 系统性的排查方法比随机尝试更有效。先收集信息，再分析问题，最后实施解决方案。
