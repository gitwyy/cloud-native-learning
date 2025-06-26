# 📊 Prometheus + Grafana 监控体系实践

> 构建完整的云原生应用监控解决方案

## 📋 项目概述

本项目是云原生学习路径第三阶段的第一个实践项目，专注于使用 Prometheus 和 Grafana 构建完整的监控体系。您将学习如何收集、存储、查询和可视化云原生应用的各种指标数据。

## 🎯 学习目标

完成本项目后，您将能够：

- **理解监控体系架构**: 掌握现代监控系统的设计原理
- **部署 Prometheus**: 在 Kubernetes 中部署和配置 Prometheus
- **配置 Grafana**: 创建美观实用的监控仪表板
- **应用指标收集**: 为微服务应用添加自定义指标
- **告警规则配置**: 设置智能告警和通知机制
- **性能优化**: 监控系统本身的性能调优

## 🏗️ 项目结构

```
prometheus-grafana/
├── README.md                    # 项目说明文档
├── docs/                        # 详细文档
│   ├── ARCHITECTURE.md         # 架构设计文档
│   ├── DEPLOYMENT_GUIDE.md     # 部署指南
│   ├── MONITORING_GUIDE.md     # 监控指南
│   └── TROUBLESHOOTING.md      # 故障排查
├── prometheus/                  # Prometheus 配置
│   ├── config/                 # 配置文件
│   ├── rules/                  # 告警规则
│   └── data/                   # 数据存储
├── grafana/                     # Grafana 配置
│   ├── config/                 # 配置文件
│   ├── dashboards/             # 仪表板定义
│   └── data/                   # 数据存储
├── apps/                        # 示例应用
│   ├── demo-app/               # 演示应用
│   ├── metrics-exporter/       # 指标导出器
│   └── load-generator/         # 负载生成器
├── manifests/                   # Kubernetes 清单
│   ├── prometheus/             # Prometheus 部署
│   ├── grafana/                # Grafana 部署
│   ├── apps/                   # 应用部署
│   └── monitoring/             # 监控配置
├── scripts/                     # 辅助脚本
│   ├── setup.sh               # 环境设置
│   ├── deploy.sh              # 部署脚本
│   ├── test.sh                # 测试脚本
│   └── cleanup.sh             # 清理脚本
├── exercises/                   # 实践练习
│   ├── basic/                  # 基础练习
│   └── advanced/               # 高级练习
└── dashboards/                  # 预制仪表板
    ├── kubernetes/             # Kubernetes 监控
    ├── applications/           # 应用监控
    └── infrastructure/         # 基础设施监控
```

## 🚀 快速开始

### 前置条件

- 运行中的 Kubernetes 集群
- kubectl 已配置并可访问集群
- 至少 4GB 可用内存
- 支持 PersistentVolume 的存储类

### 1. 环境准备

```bash
# 进入项目目录
cd projects/phase3-monitoring/prometheus-grafana

# 检查集群状态
kubectl cluster-info

# 创建监控命名空间
kubectl create namespace monitoring
```

### 2. 部署监控栈

```bash
# 一键部署完整监控栈
./scripts/setup.sh

# 或分步部署
./scripts/deploy.sh prometheus
./scripts/deploy.sh grafana
./scripts/deploy.sh apps
```

### 3. 访问监控界面

```bash
# 获取访问地址
kubectl get svc -n monitoring

# 端口转发访问
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

### 4. 验证监控功能

```bash
# 运行测试脚本
./scripts/test.sh

# 生成测试负载
kubectl apply -f apps/load-generator/
```

## 📚 学习路径

### 第一天：基础概念和环境搭建
1. **理论学习** (60分钟)
   - 监控体系架构设计
   - Prometheus 数据模型
   - Grafana 可视化原理

2. **环境部署** (90分钟)
   - 部署 Prometheus 服务器
   - 配置 Grafana 仪表板
   - 验证基本功能

3. **基础练习** (60分钟)
   - 查询 Prometheus 指标
   - 创建简单图表
   - 配置数据源

### 第二天：应用监控集成
1. **指标收集** (90分钟)
   - 应用指标暴露
   - ServiceMonitor 配置
   - 自定义指标开发

2. **仪表板创建** (90分钟)
   - 设计监控面板
   - 配置图表类型
   - 模板变量使用

3. **实践练习** (60分钟)
   - 微服务监控
   - 业务指标追踪
   - 性能分析

### 第三天：告警和优化
1. **告警配置** (90分钟)
   - 告警规则编写
   - 通知渠道配置
   - 告警策略设计

2. **性能优化** (90分钟)
   - 查询优化
   - 存储配置
   - 资源调优

3. **高级功能** (60分钟)
   - 联邦集群
   - 长期存储
   - 高可用部署

## 🔧 核心功能演示

### Prometheus 配置示例

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### Grafana 仪表板示例

```json
{
  "dashboard": {
    "title": "Kubernetes Cluster Monitoring",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(cpu_usage_seconds_total[5m])",
            "legendFormat": "{{instance}}"
          }
        ]
      }
    ]
  }
}
```

### 告警规则示例

```yaml
groups:
  - name: kubernetes-alerts
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage_percent > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"
```

## 📊 监控指标类型

### 基础设施指标
- **节点指标**: CPU、内存、磁盘、网络
- **Pod 指标**: 资源使用、状态、重启次数
- **容器指标**: 运行时指标、资源限制

### 应用指标
- **业务指标**: 请求量、响应时间、错误率
- **自定义指标**: 业务逻辑相关的指标
- **SLI/SLO**: 服务水平指标和目标

### 中间件指标
- **数据库**: 连接数、查询性能、锁等待
- **消息队列**: 队列长度、处理速度、积压
- **缓存**: 命中率、内存使用、连接数

## 📈 仪表板类型

### 概览仪表板
- 集群整体状态
- 关键指标摘要
- 告警状态概览

### 详细仪表板
- 节点详细监控
- 应用性能分析
- 故障排查视图

### 业务仪表板
- 用户行为分析
- 业务指标追踪
- 收入影响分析

## 🔍 故障排查

### 常见问题
- Prometheus 无法抓取指标
- Grafana 无法连接数据源
- 告警规则不生效
- 仪表板显示异常

### 排查工具
- Prometheus 目标状态检查
- Grafana 查询调试
- 日志分析方法
- 性能瓶颈定位

## 📝 验证检查点

### 基础功能验证
- [ ] Prometheus 服务正常运行
- [ ] Grafana 可以访问并登录
- [ ] 基本指标数据正常收集
- [ ] 简单查询可以执行

### 高级功能验证
- [ ] 自定义指标收集正常
- [ ] 告警规则配置生效
- [ ] 仪表板显示准确数据
- [ ] 通知渠道工作正常

### 性能验证
- [ ] 查询响应时间合理
- [ ] 存储使用量可控
- [ ] 系统资源消耗正常
- [ ] 高负载下稳定运行

## 🎉 项目完成标准

- [ ] 成功部署 Prometheus + Grafana 监控栈
- [ ] 创建至少 3 个不同类型的仪表板
- [ ] 配置应用和基础设施监控
- [ ] 设置关键指标的告警规则
- [ ] 完成所有基础和高级练习
- [ ] 能够独立排查监控相关问题

---

**准备好构建强大的监控体系了吗？** 📊

从 [架构设计文档](./docs/ARCHITECTURE.md) 开始了解监控系统的设计原理！
