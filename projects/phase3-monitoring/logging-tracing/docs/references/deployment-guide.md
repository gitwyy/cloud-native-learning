# 🚀 日志收集与链路追踪系统部署指南

> 详细的分步部署指南，帮助您快速搭建完整的可观测性系统

## 📋 部署概述

本指南将引导您在 Kubernetes 集群中部署完整的 EFK + Jaeger 可观测性栈，包括：
- Elasticsearch 集群（日志存储）
- Fluent Bit（日志收集）
- Kibana（日志可视化）
- Jaeger（分布式链路追踪）
- 示例微服务应用

## 🎯 前置条件

### 系统要求
- Kubernetes 集群版本 >= 1.20
- 至少 3 个工作节点
- 每个节点至少 4GB 内存
- 支持 PersistentVolume 的存储类
- kubectl 已配置并可访问集群

### 已部署组件
- Prometheus + Grafana 监控栈（第三阶段第一个项目）
- Ingress Controller（可选，用于外部访问）

### 验证环境
```bash
# 检查集群状态
kubectl cluster-info
kubectl get nodes

# 检查存储类
kubectl get storageclass

# 检查可用资源
kubectl top nodes
```

## 📦 部署步骤

### 步骤 1: 创建命名空间

```bash
# 创建日志系统命名空间
kubectl create namespace logging

# 创建追踪系统命名空间
kubectl create namespace tracing

# 验证命名空间创建
kubectl get namespaces
```

### 步骤 2: 部署 Elasticsearch 集群

#### 2.1 创建存储类和 PVC
```bash
# 应用 Elasticsearch 存储配置
kubectl apply -f manifests/elasticsearch/storage.yaml

# 验证 PVC 状态
kubectl get pvc -n logging
```

#### 2.2 部署 Elasticsearch 配置
```bash
# 应用 Elasticsearch 配置
kubectl apply -f manifests/elasticsearch/configmap.yaml

# 部署 Elasticsearch 集群
kubectl apply -f manifests/elasticsearch/elasticsearch.yaml

# 等待 Pod 启动
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s
```

#### 2.3 验证 Elasticsearch 集群
```bash
# 检查 Pod 状态
kubectl get pods -n logging -l app=elasticsearch

# 检查集群健康状态
kubectl port-forward -n logging svc/elasticsearch 9200:9200 &
curl -X GET "localhost:9200/_cluster/health?pretty"

# 预期输出：status: "green" 或 "yellow"
```

### 步骤 3: 部署 Fluent Bit

#### 3.1 创建 RBAC 权限
```bash
# 应用 Fluent Bit RBAC 配置
kubectl apply -f manifests/fluent-bit/rbac.yaml
```

#### 3.2 部署 Fluent Bit 配置
```bash
# 应用 Fluent Bit 配置
kubectl apply -f manifests/fluent-bit/configmap.yaml

# 部署 Fluent Bit DaemonSet
kubectl apply -f manifests/fluent-bit/fluent-bit.yaml

# 验证 DaemonSet 状态
kubectl get daemonset -n logging
kubectl get pods -n logging -l app=fluent-bit
```

#### 3.3 验证日志收集
```bash
# 检查 Fluent Bit 日志
kubectl logs -n logging -l app=fluent-bit --tail=50

# 验证 Elasticsearch 中的日志索引
curl -X GET "localhost:9200/_cat/indices?v"
```

### 步骤 4: 部署 Kibana

#### 4.1 部署 Kibana 服务
```bash
# 应用 Kibana 配置
kubectl apply -f manifests/kibana/configmap.yaml

# 部署 Kibana
kubectl apply -f manifests/kibana/kibana.yaml

# 等待 Kibana 启动
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s
```

#### 4.2 访问 Kibana
```bash
# 端口转发
kubectl port-forward -n logging svc/kibana 5601:5601

# 在浏览器中访问 http://localhost:5601
# 首次访问需要配置索引模式
```

#### 4.3 配置 Kibana 索引模式
1. 访问 Kibana Web UI
2. 进入 "Stack Management" > "Index Patterns"
3. 创建索引模式：`fluentbit-*`
4. 选择时间字段：`@timestamp`

### 步骤 5: 部署 Jaeger

#### 5.1 部署 Jaeger Operator（可选）
```bash
# 如果使用 Operator 方式部署
kubectl apply -f manifests/jaeger/operator.yaml
```

#### 5.2 部署 Jaeger 组件
```bash
# 部署 Jaeger 配置
kubectl apply -f manifests/jaeger/configmap.yaml

# 部署 Jaeger Collector
kubectl apply -f manifests/jaeger/collector.yaml

# 部署 Jaeger Query
kubectl apply -f manifests/jaeger/query.yaml

# 部署 Jaeger Agent
kubectl apply -f manifests/jaeger/agent.yaml

# 验证部署状态
kubectl get pods -n tracing
```

#### 5.3 访问 Jaeger UI
```bash
# 端口转发
kubectl port-forward -n tracing svc/jaeger-query 16686:16686

# 在浏览器中访问 http://localhost:16686
```

### 步骤 6: 部署示例应用

#### 6.1 部署微服务应用
```bash
# 部署用户服务
kubectl apply -f manifests/apps/user-service.yaml

# 部署订单服务
kubectl apply -f manifests/apps/order-service.yaml

# 部署支付服务
kubectl apply -f manifests/apps/payment-service.yaml

# 验证应用部署
kubectl get pods -n default -l tier=microservice
```

#### 6.2 部署负载生成器
```bash
# 部署负载生成器
kubectl apply -f manifests/apps/load-generator.yaml

# 检查负载生成器状态
kubectl logs -f deployment/load-generator
```

## 🔧 配置优化

### Elasticsearch 性能调优

#### 内存配置
```yaml
# 在 elasticsearch.yaml 中调整
env:
  - name: ES_JAVA_OPTS
    value: "-Xms2g -Xmx2g"  # 根据节点内存调整
```

#### 索引生命周期管理
```bash
# 配置索引生命周期策略
curl -X PUT "localhost:9200/_ilm/policy/fluentbit-policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "5GB",
            "max_age": "1d"
          }
        }
      },
      "delete": {
        "min_age": "7d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'
```

### Fluent Bit 配置优化

#### 缓冲区配置
```ini
[OUTPUT]
    Name  es
    Match *
    Host  elasticsearch.logging.svc.cluster.local
    Port  9200
    Index fluentbit
    Buffer_Size 5MB
    Workers 2
```

### Jaeger 采样配置

#### 采样策略
```yaml
# 在 jaeger-collector 配置中
sampling:
  default_strategy:
    type: probabilistic
    param: 0.1  # 10% 采样率
  per_service_strategies:
    - service: "user-service"
      type: probabilistic
      param: 1.0  # 100% 采样率
```

## 🔍 验证和测试

### 功能验证脚本
```bash
#!/bin/bash
# 运行完整的功能验证

echo "=== 验证 Elasticsearch 集群 ==="
curl -s "localhost:9200/_cluster/health" | jq '.status'

echo "=== 验证日志收集 ==="
curl -s "localhost:9200/_cat/indices?v" | grep fluentbit

echo "=== 验证 Kibana 连接 ==="
curl -s "localhost:5601/api/status" | jq '.status.overall.state'

echo "=== 验证 Jaeger 服务 ==="
curl -s "localhost:16686/api/services" | jq '.data[].name'

echo "=== 生成测试数据 ==="
kubectl exec deployment/load-generator -- curl -s http://user-service:8080/api/users
kubectl exec deployment/load-generator -- curl -s http://order-service:8080/api/orders
```

### 性能测试
```bash
# 日志收集性能测试
kubectl run log-stress --image=busybox --restart=Never -- sh -c '
while true; do
  echo "$(date): Test log message with random data: $RANDOM" >> /dev/stdout
  sleep 0.1
done'

# 追踪性能测试
kubectl exec deployment/load-generator -- ab -n 1000 -c 10 http://user-service:8080/api/users
```

## 🚨 故障排查

### 常见问题和解决方案

#### Elasticsearch 启动失败
```bash
# 检查资源限制
kubectl describe pod -n logging -l app=elasticsearch

# 检查存储权限
kubectl get pvc -n logging
kubectl describe pvc elasticsearch-data-0 -n logging

# 调整内存限制
kubectl patch deployment elasticsearch -n logging -p '{"spec":{"template":{"spec":{"containers":[{"name":"elasticsearch","resources":{"limits":{"memory":"4Gi"}}}]}}}}'
```

#### Fluent Bit 无法收集日志
```bash
# 检查 RBAC 权限
kubectl auth can-i get pods --as=system:serviceaccount:logging:fluent-bit

# 检查配置文件
kubectl get configmap fluent-bit-config -n logging -o yaml

# 查看 Fluent Bit 日志
kubectl logs -n logging -l app=fluent-bit --tail=100
```

#### Jaeger 无法接收追踪数据
```bash
# 检查 Jaeger Agent 状态
kubectl get pods -n tracing -l app=jaeger-agent

# 检查网络连接
kubectl exec -n tracing deployment/jaeger-collector -- netstat -tlnp

# 验证采样配置
kubectl get configmap jaeger-config -n tracing -o yaml
```

## 📊 监控部署状态

### 添加监控指标
```yaml
# 为 Elasticsearch 添加监控
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-metrics
  namespace: logging
  labels:
    app: elasticsearch
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9114"
spec:
  ports:
  - port: 9114
    name: metrics
  selector:
    app: elasticsearch-exporter
```

### 配置告警规则
```yaml
groups:
- name: logging-alerts
  rules:
  - alert: ElasticsearchClusterRed
    expr: elasticsearch_cluster_health_status{color="red"} == 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Elasticsearch cluster status is RED"
      
  - alert: FluentBitDown
    expr: up{job="fluent-bit"} == 0
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Fluent Bit is down"
```

## ✅ 部署完成检查清单

### 基础组件验证
- [ ] Elasticsearch 集群状态为 green 或 yellow
- [ ] Fluent Bit DaemonSet 在所有节点运行
- [ ] Kibana 可以访问并连接到 Elasticsearch
- [ ] Jaeger 所有组件正常运行

### 功能验证
- [ ] 可以在 Kibana 中查询到应用日志
- [ ] 可以在 Jaeger UI 中看到追踪数据
- [ ] 日志和追踪数据包含正确的元数据
- [ ] 负载生成器产生的数据可以被收集

### 性能验证
- [ ] 日志收集延迟 < 30 秒
- [ ] Elasticsearch 查询响应时间 < 5 秒
- [ ] Jaeger 追踪查询响应时间 < 3 秒
- [ ] 系统资源使用在合理范围内

---

**恭喜！您已成功部署了完整的可观测性系统！** 🎉

接下来可以查看 [日志管理指南](./LOGGING_GUIDE.md) 和 [链路追踪指南](./TRACING_GUIDE.md) 学习如何使用这些工具。
