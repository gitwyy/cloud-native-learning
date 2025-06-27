# 练习 1: EFK 日志收集栈搭建

> **目标**: 部署和配置 Elasticsearch、Fluent Bit、Kibana 日志收集分析系统

## 📋 练习概述

在这个练习中，您将：
1. 部署 Elasticsearch 集群作为日志存储后端
2. 配置 Fluent Bit 收集 Kubernetes 集群日志
3. 部署 Kibana 进行日志可视化和分析
4. 验证日志收集和查询功能

## 🎯 学习目标

- 理解 EFK Stack 的架构和组件关系
- 掌握 Elasticsearch 集群的部署和配置
- 学会配置 Fluent Bit 日志收集器
- 熟悉 Kibana 的基本使用方法
- 了解日志数据的索引和查询

## 📚 前置条件

- 运行中的 Kubernetes 集群
- kubectl 已配置并可访问集群
- 至少 6GB 可用内存
- 基本的 Kubernetes 概念知识

## 🛠️ 实践步骤

### 步骤 1: 环境准备

1. **检查集群状态**
```bash
# 检查集群信息
kubectl cluster-info

# 检查节点状态和资源
kubectl get nodes
kubectl top nodes

# 检查存储类
kubectl get storageclass
```

2. **创建命名空间**
```bash
# 创建日志系统命名空间
kubectl create namespace logging

# 验证命名空间创建
kubectl get namespaces
```

### 步骤 2: 部署 Elasticsearch 集群

1. **了解 Elasticsearch 配置**
```bash
# 查看 Elasticsearch 配置文件
cat ../manifests/elasticsearch/elasticsearch.yaml
```

**配置要点分析**：
- StatefulSet 部署确保数据持久性
- 3 个副本提供高可用性
- 配置集群发现和节点角色
- 设置合适的资源限制

2. **部署 Elasticsearch**
```bash
# 应用 Elasticsearch 配置
kubectl apply -f ../manifests/elasticsearch/elasticsearch.yaml

# 观察 Pod 启动过程
kubectl get pods -n logging -w
```

3. **验证 Elasticsearch 集群**
```bash
# 等待所有 Pod 就绪
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

# 检查 Pod 状态
kubectl get pods -n logging -l app=elasticsearch

# 查看 Pod 详细信息
kubectl describe pod -n logging -l app=elasticsearch
```

4. **测试 Elasticsearch 连接**
```bash
# 端口转发到本地
kubectl port-forward -n logging svc/elasticsearch 9200:9200 &

# 测试连接
curl http://localhost:9200

# 检查集群健康状态
curl http://localhost:9200/_cluster/health?pretty

# 查看节点信息
curl http://localhost:9200/_nodes?pretty
```

### 步骤 3: 部署 Fluent Bit

1. **了解 Fluent Bit 配置**
```bash
# 查看 Fluent Bit 配置
cat ../manifests/fluent-bit/fluent-bit.yaml
```

**配置要点分析**：
- DaemonSet 确保每个节点都有日志收集器
- RBAC 权限允许访问 Kubernetes API
- 配置日志解析器和过滤器
- 输出到 Elasticsearch

2. **部署 Fluent Bit**
```bash
# 应用 Fluent Bit 配置
kubectl apply -f ../manifests/fluent-bit/fluent-bit.yaml

# 检查 DaemonSet 状态
kubectl get daemonset -n logging

# 检查 Pod 状态
kubectl get pods -n logging -l app=fluent-bit
```

3. **验证日志收集**
```bash
# 查看 Fluent Bit 日志
kubectl logs -n logging -l app=fluent-bit --tail=50

# 检查 Elasticsearch 中的索引
curl http://localhost:9200/_cat/indices?v

# 查看日志数据
curl http://localhost:9200/fluentbit-*/_search?pretty&size=5
```

### 步骤 4: 部署 Kibana

1. **了解 Kibana 配置**
```bash
# 查看 Kibana 配置
cat ../manifests/kibana/kibana.yaml
```

2. **部署 Kibana**
```bash
# 应用 Kibana 配置
kubectl apply -f ../manifests/kibana/kibana.yaml

# 等待 Kibana 启动
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s

# 检查 Pod 状态
kubectl get pods -n logging -l app=kibana
```

3. **访问 Kibana**
```bash
# 端口转发到本地
kubectl port-forward -n logging svc/kibana 5601:5601 &

# 在浏览器中访问 http://localhost:5601
```

### 步骤 5: 配置 Kibana

1. **创建索引模式**
- 在 Kibana 中进入 "Stack Management" > "Index Patterns"
- 点击 "Create index pattern"
- 输入索引模式：`fluentbit-*`
- 选择时间字段：`@timestamp`
- 点击 "Create index pattern"

2. **探索日志数据**
- 进入 "Discover" 页面
- 选择刚创建的索引模式
- 设置时间范围为最近 15 分钟
- 观察日志数据结构

3. **创建基础可视化**
- 进入 "Visualize" 页面
- 创建一个 "Line chart"
- 配置 Y 轴为文档计数
- 配置 X 轴为时间戳
- 保存可视化图表

## 🔍 深入探索

### 日志数据结构分析

1. **查看日志字段**
```bash
# 获取日志字段映射
curl http://localhost:9200/fluentbit-*/_mapping?pretty
```

2. **分析日志内容**
- `kubernetes.namespace_name`: 命名空间
- `kubernetes.pod_name`: Pod 名称
- `kubernetes.container_name`: 容器名称
- `log`: 原始日志内容
- `@timestamp`: 时间戳

### 高级查询示例

1. **按命名空间过滤**
```json
{
  "query": {
    "term": {
      "kubernetes.namespace_name": "kube-system"
    }
  }
}
```

2. **按时间范围查询**
```json
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h",
        "lte": "now"
      }
    }
  }
}
```

3. **全文搜索**
```json
{
  "query": {
    "match": {
      "log": "error"
    }
  }
}
```

## ✅ 验证检查点

### 基础功能验证
- [ ] Elasticsearch 集群状态为 green 或 yellow
- [ ] Fluent Bit DaemonSet 在所有节点运行
- [ ] Kibana 可以访问并连接到 Elasticsearch
- [ ] 可以在 Kibana 中看到日志数据

### 高级功能验证
- [ ] 成功创建了索引模式
- [ ] 可以在 Discover 中查询和过滤日志
- [ ] 创建了基础的可视化图表
- [ ] 理解了日志数据的结构和字段

### 性能验证
- [ ] Elasticsearch 查询响应时间 < 5 秒
- [ ] Fluent Bit 日志收集延迟 < 30 秒
- [ ] Kibana 页面加载时间 < 10 秒
- [ ] 系统资源使用在合理范围内

## 🔧 故障排查

### 常见问题

1. **Elasticsearch Pod 启动失败**
```bash
# 查看 Pod 事件
kubectl describe pod -n logging <elasticsearch-pod-name>

# 查看容器日志
kubectl logs -n logging <elasticsearch-pod-name>

# 检查资源限制
kubectl top pod -n logging
```

2. **Fluent Bit 无法收集日志**
```bash
# 检查 RBAC 权限
kubectl auth can-i get pods --as=system:serviceaccount:logging:fluent-bit

# 查看 Fluent Bit 配置
kubectl get configmap fluent-bit-config -n logging -o yaml

# 检查日志输出
kubectl logs -n logging -l app=fluent-bit --tail=100
```

3. **Kibana 无法连接 Elasticsearch**
```bash
# 检查 Kibana 配置
kubectl get configmap kibana-config -n logging -o yaml

# 查看 Kibana 日志
kubectl logs -n logging -l app=kibana

# 测试网络连接
kubectl exec -n logging deployment/kibana -- curl elasticsearch:9200
```

## 📝 练习总结

完成本练习后，您应该：

1. **理解 EFK Stack 架构**
   - Elasticsearch 作为搜索和存储引擎
   - Fluent Bit 作为轻量级日志收集器
   - Kibana 作为数据可视化平台

2. **掌握部署技能**
   - StatefulSet 部署有状态应用
   - DaemonSet 部署节点级服务
   - ConfigMap 管理配置文件
   - Service 提供服务发现

3. **学会基础操作**
   - 创建和管理索引模式
   - 使用 Discover 探索日志数据
   - 创建基础的可视化图表
   - 执行日志查询和过滤

## 🚀 下一步

- 继续学习 [练习 2: Jaeger 链路追踪系统](./02-jaeger-tracing-setup.md)
- 探索更高级的 Kibana 功能
- 学习日志数据的分析和告警
- 了解 Elasticsearch 性能优化

---

**恭喜完成 EFK Stack 搭建练习！** 🎉

您已经成功构建了一个功能完整的日志收集和分析系统。
