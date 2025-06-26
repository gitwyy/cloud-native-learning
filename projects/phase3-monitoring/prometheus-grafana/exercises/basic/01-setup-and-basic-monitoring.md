# 练习 1: 监控栈搭建和基础监控

> **目标**: 部署 Prometheus + Grafana 监控栈并验证基本功能

## 📋 练习概述

在这个练习中，您将：
1. 部署完整的 Prometheus + Grafana 监控栈
2. 验证各组件的正常运行
3. 配置基本的数据源和查询
4. 创建第一个监控图表

## 🎯 学习目标

- 理解监控栈的部署过程
- 掌握 Prometheus 的基本配置
- 学会使用 Grafana 创建图表
- 熟悉 PromQL 查询语言基础

## 📚 前置条件

- 运行中的 Kubernetes 集群
- kubectl 已配置并可访问集群
- 至少 4GB 可用内存

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

2. **进入项目目录**
```bash
cd projects/phase3-monitoring/prometheus-grafana
```

### 步骤 2: 部署监控栈

1. **运行一键部署脚本**
```bash
# 部署完整监控栈
./scripts/setup.sh

# 检查部署状态
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

2. **验证组件状态**
```bash
# 检查 Prometheus
kubectl get pods -n monitoring -l app=prometheus

# 检查 Grafana
kubectl get pods -n monitoring -l app=grafana

# 检查 Node Exporter
kubectl get pods -n monitoring -l app=node-exporter

# 检查 Kube State Metrics
kubectl get pods -n monitoring -l app=kube-state-metrics
```

**预期结果**: 所有 Pod 都处于 Running 状态

### 步骤 3: 访问 Prometheus

1. **设置端口转发**
```bash
# 转发 Prometheus 端口
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

2. **访问 Prometheus UI**
```bash
# 在浏览器中访问
open http://localhost:9090

# 或使用 curl 测试
curl http://localhost:9090/api/v1/targets
```

3. **验证目标状态**
- 在 Prometheus UI 中点击 "Status" -> "Targets"
- 确认所有目标都是 "UP" 状态
- 检查以下目标：
  - prometheus (自身监控)
  - kubernetes-apiservers
  - kubernetes-nodes
  - node-exporter
  - kube-state-metrics

### 步骤 4: 基础 PromQL 查询

1. **在 Prometheus UI 中尝试以下查询**

**基础指标查询**:
```promql
# 查看所有可用指标
{__name__=~".+"}

# 查看 Prometheus 自身状态
up

# 查看节点数量
count(kube_node_info)

# 查看 Pod 数量
count(kube_pod_info)
```

**资源使用查询**:
```promql
# 节点 CPU 使用率
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 节点内存使用率
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod 重启次数
rate(kube_pod_container_status_restarts_total[5m])
```

**时间范围查询**:
```promql
# 过去 5 分钟的 HTTP 请求率
rate(prometheus_http_requests_total[5m])

# 过去 1 小时的平均 CPU 使用率
avg_over_time(node_load1[1h])
```

### 步骤 5: 访问 Grafana

1. **设置端口转发**
```bash
# 在新终端中转发 Grafana 端口
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

2. **登录 Grafana**
```bash
# 在浏览器中访问
open http://localhost:3000

# 默认登录信息
用户名: admin
密码: admin123
```

3. **验证数据源**
- 点击左侧菜单 "Configuration" -> "Data Sources"
- 确认 Prometheus 数据源已配置
- 点击 "Test" 按钮验证连接

### 步骤 6: 创建第一个仪表板

1. **创建新仪表板**
- 点击左侧菜单 "+" -> "Dashboard"
- 点击 "Add new panel"

2. **配置 CPU 使用率图表**
```promql
# 查询表达式
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 图例格式
{{instance}} CPU Usage

# 图表设置
- Panel title: "Node CPU Usage"
- Y-axis unit: "percent (0-100)"
- Y-axis max: 100
```

3. **配置内存使用率图表**
```promql
# 查询表达式
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# 图例格式
{{instance}} Memory Usage

# 图表设置
- Panel title: "Node Memory Usage"
- Y-axis unit: "percent (0-100)"
- Y-axis max: 100
```

4. **保存仪表板**
- 点击右上角 "Save" 按钮
- 输入仪表板名称: "Basic Node Monitoring"
- 点击 "Save"

### 步骤 7: 部署示例应用

1. **构建示例应用镜像** (可选)
```bash
# 进入应用目录
cd apps/demo-app

# 构建 Docker 镜像
docker build -t demo-app:latest .

# 加载到 minikube (如果使用 minikube)
minikube image load demo-app:latest
```

2. **部署示例应用**
```bash
# 返回项目根目录
cd ../..

# 部署应用
kubectl apply -f manifests/apps/demo-app.yaml

# 检查部署状态
kubectl get pods -n monitoring -l app=demo-app
```

3. **测试应用指标**
```bash
# 端口转发到应用
kubectl port-forward -n monitoring svc/demo-app 8080:80

# 访问应用指标
curl http://localhost:8080/metrics

# 生成一些测试流量
curl http://localhost:8080/
curl http://localhost:8080/api/users
curl http://localhost:8080/api/orders
```

## ✅ 验证检查点

### 基础功能验证
- [ ] Prometheus 服务正常运行并可访问
- [ ] Grafana 可以登录并连接到 Prometheus
- [ ] 所有监控目标都是 UP 状态
- [ ] 基本 PromQL 查询可以执行

### 高级功能验证
- [ ] 成功创建了基础监控仪表板
- [ ] 图表显示正确的指标数据
- [ ] 示例应用部署成功并暴露指标
- [ ] 可以在 Prometheus 中查询应用指标

## 🔍 故障排查

### 常见问题

1. **Pod 启动失败**
```bash
# 查看 Pod 状态
kubectl describe pod <pod-name> -n monitoring

# 查看容器日志
kubectl logs <pod-name> -n monitoring
```

2. **Prometheus 无法抓取目标**
```bash
# 检查服务发现
kubectl get endpoints -n monitoring

# 检查网络策略
kubectl get networkpolicy -n monitoring

# 检查 RBAC 权限
kubectl auth can-i get pods --as=system:serviceaccount:monitoring:prometheus
```

3. **Grafana 无法连接 Prometheus**
```bash
# 检查 Prometheus 服务
kubectl get svc prometheus -n monitoring

# 测试内部连接
kubectl exec -it <grafana-pod> -n monitoring -- curl http://prometheus:9090/api/v1/targets
```

## 🎓 深入理解

### Prometheus 架构
- **时序数据库**: 存储带时间戳的指标数据
- **Pull 模型**: 主动抓取目标的指标
- **服务发现**: 自动发现 Kubernetes 中的目标
- **PromQL**: 强大的查询语言

### Grafana 功能
- **数据可视化**: 多种图表类型
- **仪表板管理**: 组织和共享监控视图
- **告警功能**: 基于指标的告警
- **用户管理**: 多用户和权限控制

### 监控最佳实践
- **四个黄金信号**: 延迟、流量、错误、饱和度
- **标签使用**: 合理设计标签维度
- **查询优化**: 避免高基数标签
- **存储管理**: 合理设置保留期

## 📝 练习总结

完成这个练习后，您应该：
- 成功部署了 Prometheus + Grafana 监控栈
- 理解了基本的监控架构和组件
- 掌握了 PromQL 查询的基础语法
- 学会了创建简单的 Grafana 仪表板

## 🚀 下一步

继续进行 [练习 2: 应用监控和自定义指标](./02-application-monitoring.md)，学习如何为应用添加自定义监控指标。
