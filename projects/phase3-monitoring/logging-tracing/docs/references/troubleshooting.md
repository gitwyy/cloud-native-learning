# 🚨 故障排查指南

> 日志收集与链路追踪系统常见问题的诊断和解决方案

## 📋 故障排查概述

本指南涵盖了 EFK Stack + Jaeger 可观测性系统的常见问题和解决方案，帮助您快速定位和解决部署、配置、性能等方面的问题。

## 🔍 诊断工具和命令

### 基础诊断命令

```bash
# 查看所有 Pod 状态
kubectl get pods -A

# 查看特定命名空间的资源
kubectl get all -n logging
kubectl get all -n tracing

# 查看 Pod 详细信息
kubectl describe pod <pod-name> -n <namespace>

# 查看容器日志
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> -c <container-name>

# 查看事件
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 查看资源使用情况
kubectl top nodes
kubectl top pods -n <namespace>
```

### 网络诊断

```bash
# 测试服务连通性
kubectl exec -n <namespace> <pod-name> -- curl <service-name>:<port>

# 查看服务端点
kubectl get endpoints -n <namespace>

# 查看网络策略
kubectl get networkpolicy -n <namespace>

# DNS 解析测试
kubectl exec -n <namespace> <pod-name> -- nslookup <service-name>
```

## 🔧 Elasticsearch 故障排查

### 问题 1: Elasticsearch Pod 启动失败

**症状**：
- Pod 状态为 `Pending` 或 `CrashLoopBackOff`
- 容器无法启动或反复重启

**诊断步骤**：
```bash
# 查看 Pod 状态和事件
kubectl describe pod -n logging -l app=elasticsearch

# 查看容器日志
kubectl logs -n logging -l app=elasticsearch --tail=100

# 检查资源使用
kubectl top nodes
kubectl describe node <node-name>
```

**常见原因和解决方案**：

1. **内存不足**
```bash
# 检查节点内存
kubectl top nodes

# 调整内存限制
kubectl patch statefulset elasticsearch -n logging -p '{"spec":{"template":{"spec":{"containers":[{"name":"elasticsearch","resources":{"limits":{"memory":"2Gi"},"requests":{"memory":"1Gi"}}}]}}}}'
```

2. **存储问题**
```bash
# 检查 PVC 状态
kubectl get pvc -n logging

# 查看存储类
kubectl get storageclass

# 检查 PV 状态
kubectl get pv
```

3. **权限问题**
```bash
# 检查 SecurityContext
kubectl get pod -n logging -l app=elasticsearch -o yaml | grep -A 10 securityContext

# 修复权限（如果需要）
kubectl patch statefulset elasticsearch -n logging -p '{"spec":{"template":{"spec":{"securityContext":{"fsGroup":1000}}}}}'
```

### 问题 2: Elasticsearch 集群状态异常

**症状**：
- 集群状态为 `red`
- 部分分片无法分配
- 查询响应缓慢

**诊断步骤**：
```bash
# 检查集群健康状态
kubectl port-forward -n logging svc/elasticsearch 9200:9200 &
curl http://localhost:9200/_cluster/health?pretty

# 查看分片状态
curl http://localhost:9200/_cat/shards?v

# 查看节点状态
curl http://localhost:9200/_cat/nodes?v
```

**解决方案**：

1. **分片重新分配**
```bash
# 手动重新分配分片
curl -X POST "http://localhost:9200/_cluster/reroute?retry_failed=true"

# 增加副本数量
curl -X PUT "http://localhost:9200/_settings" -H 'Content-Type: application/json' -d'
{
  "index": {
    "number_of_replicas": 1
  }
}'
```

2. **清理旧索引**
```bash
# 查看索引大小
curl http://localhost:9200/_cat/indices?v&s=store.size:desc

# 删除旧索引
curl -X DELETE "http://localhost:9200/fluentbit-2024.01.01"
```

## 🔧 Fluent Bit 故障排查

### 问题 1: Fluent Bit 无法收集日志

**症状**：
- Elasticsearch 中没有日志数据
- Fluent Bit Pod 运行正常但无输出

**诊断步骤**：
```bash
# 查看 Fluent Bit 日志
kubectl logs -n logging -l app=fluent-bit --tail=100

# 检查配置
kubectl get configmap fluent-bit-config -n logging -o yaml

# 测试连接
kubectl exec -n logging -l app=fluent-bit -- curl elasticsearch:9200
```

**解决方案**：

1. **RBAC 权限问题**
```bash
# 检查权限
kubectl auth can-i get pods --as=system:serviceaccount:logging:fluent-bit

# 重新应用 RBAC
kubectl apply -f ../manifests/fluent-bit/fluent-bit.yaml
```

2. **配置问题**
```bash
# 验证配置语法
kubectl exec -n logging -l app=fluent-bit -- fluent-bit --dry-run --config /fluent-bit/etc/fluent-bit.conf

# 重启 DaemonSet
kubectl rollout restart daemonset/fluent-bit -n logging
```

### 问题 2: 日志解析错误

**症状**：
- 日志格式不正确
- 缺少 Kubernetes 元数据
- 时间戳解析失败

**解决方案**：

1. **更新解析器配置**
```yaml
[PARSER]
    Name        docker
    Format      json
    Time_Key    time
    Time_Format %Y-%m-%dT%H:%M:%S.%L
    Time_Keep   On
```

2. **调试解析过程**
```bash
# 查看原始日志
kubectl exec -n logging -l app=fluent-bit -- tail -f /var/log/containers/*.log

# 测试解析器
kubectl exec -n logging -l app=fluent-bit -- fluent-bit --parser /fluent-bit/etc/parsers.conf --input dummy --output stdout
```

## 🔧 Kibana 故障排查

### 问题 1: Kibana 无法连接 Elasticsearch

**症状**：
- Kibana 启动失败
- 无法访问 Kibana UI
- 连接超时错误

**诊断步骤**：
```bash
# 查看 Kibana 日志
kubectl logs -n logging -l app=kibana

# 测试网络连接
kubectl exec -n logging deployment/kibana -- curl elasticsearch:9200

# 检查配置
kubectl get configmap kibana-config -n logging -o yaml
```

**解决方案**：

1. **网络连接问题**
```bash
# 检查服务发现
kubectl get svc -n logging elasticsearch

# 测试 DNS 解析
kubectl exec -n logging deployment/kibana -- nslookup elasticsearch.logging.svc.cluster.local
```

2. **配置问题**
```bash
# 更新 Elasticsearch 地址
kubectl patch configmap kibana-config -n logging -p '{"data":{"kibana.yml":"elasticsearch.hosts: [\"http://elasticsearch.logging.svc.cluster.local:9200\"]"}}'

# 重启 Kibana
kubectl rollout restart deployment/kibana -n logging
```

### 问题 2: Kibana 性能问题

**症状**：
- 页面加载缓慢
- 查询超时
- 内存使用过高

**解决方案**：

1. **增加资源限制**
```bash
kubectl patch deployment kibana -n logging -p '{"spec":{"template":{"spec":{"containers":[{"name":"kibana","resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'
```

2. **优化查询**
- 减少查询时间范围
- 使用更具体的过滤条件
- 避免使用通配符查询

## 🔧 Jaeger 故障排查

### 问题 1: Jaeger 无法接收追踪数据

**症状**：
- Jaeger UI 中没有追踪数据
- 应用无法发送 Span

**诊断步骤**：
```bash
# 查看 Jaeger 组件状态
kubectl get pods -n tracing

# 检查 Collector 日志
kubectl logs -n tracing -l app=jaeger,component=collector

# 测试 Collector 连接
kubectl exec -n tracing deployment/jaeger -- curl jaeger-collector:14268
```

**解决方案**：

1. **网络连接问题**
```bash
# 检查服务端口
kubectl get svc -n tracing jaeger-collector

# 测试端口连通性
kubectl exec -n tracing deployment/jaeger -- telnet jaeger-collector 14268
```

2. **配置问题**
```bash
# 检查采样配置
kubectl get configmap jaeger-config -n tracing -o yaml

# 更新采样率
kubectl patch configmap jaeger-config -n tracing -p '{"data":{"jaeger-config.yaml":"sampling:\n  default_strategy:\n    type: const\n    param: 1"}}'
```

### 问题 2: Jaeger 存储问题

**症状**：
- 追踪数据丢失
- 查询响应缓慢
- 存储空间不足

**解决方案**：

1. **检查存储后端**
```bash
# 如果使用 Elasticsearch 存储
curl http://localhost:9200/_cat/indices?v | grep jaeger

# 检查存储配置
kubectl get configmap jaeger-config -n tracing -o yaml | grep -A 10 storage
```

2. **清理旧数据**
```bash
# 设置数据保留策略
curl -X PUT "http://localhost:9200/_template/jaeger-span" -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["jaeger-span-*"],
  "settings": {
    "index.lifecycle.name": "jaeger-policy",
    "index.lifecycle.rollover_alias": "jaeger-span"
  }
}'
```

## 📊 性能优化

### Elasticsearch 性能优化

1. **内存配置**
```bash
# 设置 JVM 堆内存（推荐为容器内存的 50%）
kubectl patch statefulset elasticsearch -n logging -p '{"spec":{"template":{"spec":{"containers":[{"name":"elasticsearch","env":[{"name":"ES_JAVA_OPTS","value":"-Xms2g -Xmx2g"}]}]}}}}'
```

2. **索引优化**
```bash
# 设置索引生命周期
curl -X PUT "http://localhost:9200/_ilm/policy/fluentbit-policy" -H 'Content-Type: application/json' -d'
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

### Fluent Bit 性能优化

1. **缓冲区配置**
```ini
[OUTPUT]
    Name  es
    Match *
    Host  elasticsearch.logging.svc.cluster.local
    Port  9200
    Buffer_Size 5MB
    Workers 2
```

2. **过滤优化**
```ini
[FILTER]
    Name grep
    Match *
    Exclude log ^\s*$
```

## 📝 监控和告警

### 设置监控指标

1. **Elasticsearch 监控**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-exporter
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9114"
```

2. **告警规则**
```yaml
groups:
- name: logging-alerts
  rules:
  - alert: ElasticsearchClusterRed
    expr: elasticsearch_cluster_health_status{color="red"} == 1
    for: 5m
    labels:
      severity: critical
```

## 🆘 紧急恢复

### 数据恢复

1. **Elasticsearch 快照恢复**
```bash
# 创建快照
curl -X PUT "http://localhost:9200/_snapshot/backup/snapshot_1"

# 恢复快照
curl -X POST "http://localhost:9200/_snapshot/backup/snapshot_1/_restore"
```

2. **配置备份**
```bash
# 备份配置
kubectl get configmap -n logging -o yaml > logging-config-backup.yaml
kubectl get configmap -n tracing -o yaml > tracing-config-backup.yaml
```

---

**遇到问题时，请按照本指南逐步排查，大多数问题都可以快速解决！** 🔧
