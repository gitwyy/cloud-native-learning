# 🚀 Prometheus + Grafana 部署指南

> 详细的监控栈部署步骤和配置说明

## 📋 部署概览

本指南将引导您完成 Prometheus + Grafana 监控栈的完整部署过程，包括环境准备、组件安装、配置优化和验证测试。

## 🔧 环境要求

### 硬件要求
- **CPU**: 最少 2 核，推荐 4 核以上
- **内存**: 最少 4GB，推荐 8GB 以上
- **存储**: 最少 50GB 可用空间，推荐 SSD

### 软件要求
- **Kubernetes**: v1.20.0 或更高版本
- **kubectl**: 与集群版本兼容
- **Helm**: v3.0 或更高版本 (可选)
- **存储类**: 支持动态 PV 分配

### 集群要求
```bash
# 检查集群版本
kubectl version --short

# 检查节点状态
kubectl get nodes

# 检查存储类
kubectl get storageclass

# 检查可用资源
kubectl top nodes
```

## 📦 部署方式选择

### 方式一：使用脚本一键部署 (推荐)

```bash
# 进入项目目录
cd projects/phase3-monitoring/prometheus-grafana

# 运行一键部署脚本
./scripts/setup.sh
```

### 方式二：使用 Helm 部署

```bash
# 添加 Helm 仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 创建命名空间
kubectl create namespace monitoring

# 部署 Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus/config/values.yaml

# 部署 Grafana
helm install grafana grafana/grafana \
  --namespace monitoring \
  --values grafana/config/values.yaml
```

### 方式三：手动部署

详细的手动部署步骤见下文。

## 🛠️ 手动部署步骤

### 步骤 1: 环境准备

1. **创建命名空间**
```bash
kubectl create namespace monitoring
```

2. **创建存储类 (如果需要)**
```yaml
# storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: monitoring-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

3. **设置 RBAC 权限**
```bash
kubectl apply -f manifests/monitoring/rbac.yaml
```

### 步骤 2: 部署 Prometheus

1. **创建配置文件**
```bash
# 创建 ConfigMap
kubectl create configmap prometheus-config \
  --from-file=prometheus/config/prometheus.yml \
  --namespace monitoring

# 创建告警规则
kubectl create configmap prometheus-rules \
  --from-file=prometheus/rules/ \
  --namespace monitoring
```

2. **部署 Prometheus 服务器**
```bash
kubectl apply -f manifests/prometheus/deployment.yaml
kubectl apply -f manifests/prometheus/service.yaml
kubectl apply -f manifests/prometheus/pvc.yaml
```

3. **验证 Prometheus 部署**
```bash
# 检查 Pod 状态
kubectl get pods -n monitoring -l app=prometheus

# 检查服务状态
kubectl get svc -n monitoring prometheus

# 端口转发测试
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

### 步骤 3: 部署数据收集组件

1. **部署 Node Exporter**
```bash
kubectl apply -f manifests/monitoring/node-exporter.yaml
```

2. **部署 Kube State Metrics**
```bash
kubectl apply -f manifests/monitoring/kube-state-metrics.yaml
```

3. **配置 ServiceMonitor**
```bash
kubectl apply -f manifests/monitoring/servicemonitors.yaml
```

### 步骤 4: 部署 Grafana

1. **创建配置文件**
```bash
# 创建数据源配置
kubectl create configmap grafana-datasources \
  --from-file=grafana/config/datasources.yaml \
  --namespace monitoring

# 创建仪表板配置
kubectl create configmap grafana-dashboards \
  --from-file=grafana/dashboards/ \
  --namespace monitoring
```

2. **部署 Grafana 服务器**
```bash
kubectl apply -f manifests/grafana/deployment.yaml
kubectl apply -f manifests/grafana/service.yaml
kubectl apply -f manifests/grafana/pvc.yaml
```

3. **验证 Grafana 部署**
```bash
# 检查 Pod 状态
kubectl get pods -n monitoring -l app=grafana

# 获取管理员密码
kubectl get secret -n monitoring grafana-admin-secret -o jsonpath="{.data.password}" | base64 --decode

# 端口转发测试
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## ⚙️ 配置详解

### Prometheus 配置

**主配置文件 (prometheus.yml)**:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'kubernetes'
    replica: '1'

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Kubernetes API Server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubernetes Nodes
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

  # Kubernetes Pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
```

### Grafana 配置

**数据源配置 (datasources.yaml)**:
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: "POST"
```

**仪表板提供者配置**:
```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

## 🔍 验证和测试

### 1. 基础功能验证

```bash
# 检查所有组件状态
kubectl get pods -n monitoring

# 检查服务状态
kubectl get svc -n monitoring

# 检查 PVC 状态
kubectl get pvc -n monitoring
```

### 2. Prometheus 功能测试

```bash
# 访问 Prometheus UI
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# 在浏览器中访问 http://localhost:9090
# 执行测试查询:
# - up (检查所有目标状态)
# - prometheus_tsdb_head_samples_appended_total (检查数据摄入)
# - rate(prometheus_http_requests_total[5m]) (检查查询性能)
```

### 3. Grafana 功能测试

```bash
# 访问 Grafana UI
kubectl port-forward -n monitoring svc/grafana 3000:3000

# 在浏览器中访问 http://localhost:3000
# 默认登录: admin / admin (首次登录需要修改密码)

# 验证数据源连接
# 导入预制仪表板
# 创建测试图表
```

### 4. 指标收集验证

```bash
# 检查 Node Exporter 指标
curl http://localhost:9100/metrics

# 检查 Kube State Metrics
kubectl port-forward -n monitoring svc/kube-state-metrics 8080:8080
curl http://localhost:8080/metrics

# 在 Prometheus 中查询指标
# - node_cpu_seconds_total (节点 CPU 指标)
# - kube_pod_status_phase (Pod 状态指标)
```

## 🔧 配置优化

### 1. 性能优化

**Prometheus 性能配置**:
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 15s

# 存储配置
storage:
  tsdb:
    retention.time: 15d
    retention.size: 50GB
    wal-compression: true
```

**资源限制配置**:
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### 2. 安全配置

**启用 HTTPS**:
```yaml
# prometheus.yml
global:
  external_labels:
    cluster: 'production'

# TLS 配置
tls_config:
  cert_file: /etc/prometheus/certs/tls.crt
  key_file: /etc/prometheus/certs/tls.key
```

**Grafana 安全配置**:
```ini
[security]
admin_user = admin
admin_password = $__env{GF_SECURITY_ADMIN_PASSWORD}
secret_key = $__env{GF_SECURITY_SECRET_KEY}
disable_gravatar = true

[auth]
disable_login_form = false
disable_signout_menu = false

[auth.anonymous]
enabled = false
```

## 📊 监控配置

### 1. 告警规则配置

```yaml
# alerts.yml
groups:
  - name: kubernetes-alerts
    rules:
      - alert: KubernetesPodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"

      - alert: KubernetesNodeNotReady
        expr: kube_node_status_condition{condition="Ready",status="true"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.node }} is not ready"
          description: "Node {{ $labels.node }} has been not ready for more than 5 minutes"
```

### 2. 服务发现配置

```yaml
# ServiceMonitor 示例
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-application
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## 🧹 清理和卸载

### 完整清理

```bash
# 删除所有监控组件
kubectl delete namespace monitoring

# 删除 CRD (如果使用了 Operator)
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com

# 清理持久化数据 (谨慎操作)
kubectl delete pv --selector=app=prometheus
kubectl delete pv --selector=app=grafana
```

### 选择性清理

```bash
# 只删除 Prometheus
kubectl delete deployment,service,pvc -n monitoring -l app=prometheus

# 只删除 Grafana
kubectl delete deployment,service,pvc -n monitoring -l app=grafana

# 删除配置但保留数据
kubectl delete configmap -n monitoring prometheus-config
kubectl delete configmap -n monitoring grafana-datasources
```

## 📚 参考资源

- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 官方文档](https://grafana.com/docs/)
- [Kubernetes 监控最佳实践](https://kubernetes.io/docs/concepts/cluster-administration/monitoring/)
- [PromQL 查询语言指南](https://prometheus.io/docs/prometheus/latest/querying/basics/)

---

**下一步**: 查看 [监控指南](./MONITORING_GUIDE.md) 了解如何创建有效的监控策略和仪表板。
