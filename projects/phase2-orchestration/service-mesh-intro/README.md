# 🕸️ 服务网格入门实践

> 通过 Istio 学习服务网格的核心概念和实践应用

## 📋 项目概述

本项目是云原生学习路径第二阶段的第三个实践项目，专注于服务网格技术的学习和应用。通过 Istio 服务网格，您将学习如何在微服务架构中实现高级的流量管理、安全策略和可观测性功能。

## 🎯 学习目标

完成本项目后，您将能够：

- **理解服务网格概念**: 掌握服务网格的基本原理和架构
- **部署 Istio 服务网格**: 在 Kubernetes 集群中安装和配置 Istio
- **实现流量管理**: 配置路由规则、负载均衡、故障注入等
- **配置安全策略**: 实现 mTLS、认证和授权机制
- **集成可观测性**: 监控、日志和分布式追踪
- **故障排查**: 诊断和解决服务网格相关问题

## 🏗️ 项目结构

```
service-mesh-intro/
├── README.md                    # 项目说明文档
├── docs/                        # 详细文档
│   ├── LEARNING_GUIDE.md       # 学习指南
│   ├── DEPLOYMENT_GUIDE.md     # 部署指南
│   └── TROUBLESHOOTING.md      # 故障排查
├── istio/                       # Istio 配置
│   ├── install.sh              # 安装脚本
│   ├── profiles/               # 安装配置文件
│   └── addons/                 # 插件配置
├── apps/                        # 示例应用
│   ├── bookinfo/               # Bookinfo 示例应用
│   ├── httpbin/                # HTTP 测试服务
│   └── sleep/                  # 客户端测试工具
├── manifests/                   # Kubernetes 清单
│   ├── traffic-management/     # 流量管理配置
│   ├── security/               # 安全策略配置
│   └── observability/          # 可观测性配置
├── scripts/                     # 辅助脚本
│   ├── setup.sh               # 环境设置
│   ├── cleanup.sh             # 清理脚本
│   └── test.sh                # 测试脚本
├── exercises/                   # 实践练习
│   ├── basic/                  # 基础练习
│   └── advanced/               # 高级练习
└── solutions/                   # 练习答案
```

## 🚀 快速开始

### 前置条件

- 运行中的 Kubernetes 集群 (v1.22+)
- kubectl 已配置并可访问集群
- 至少 4GB 可用内存
- 集群节点支持 LoadBalancer 服务类型

### 1. 环境准备

```bash
# 克隆项目到本地
cd projects/phase2-orchestration/service-mesh-intro

# 检查集群状态
kubectl cluster-info

# 设置环境变量
export ISTIO_VERSION=1.20.0
export NAMESPACE=istio-system
```

### 2. 安装 Istio

```bash
# 运行安装脚本
./scripts/setup.sh

# 或手动安装
./istio/install.sh
```

### 3. 部署示例应用

```bash
# 部署 Bookinfo 应用
kubectl apply -f apps/bookinfo/

# 验证部署
kubectl get pods -n default
```

### 4. 配置流量管理

```bash
# 应用流量管理规则
kubectl apply -f manifests/traffic-management/

# 测试路由规则
./scripts/test.sh
```

## 📚 学习路径

### 阶段一：基础概念 (第1-2天)
1. **服务网格概述**
   - 理解服务网格的价值和应用场景
   - 学习 Istio 架构和核心组件
   - 阅读：[docs/LEARNING_GUIDE.md](./docs/LEARNING_GUIDE.md)

2. **环境搭建**
   - 安装和配置 Istio
   - 部署示例应用
   - 验证基本功能

### 阶段二：流量管理 (第3-4天)
1. **路由控制**
   - 配置 VirtualService 和 DestinationRule
   - 实现基于权重的流量分发
   - 练习：[exercises/basic/traffic-routing.md](./exercises/basic/)

2. **高级流量管理**
   - 故障注入和超时控制
   - 重试和熔断机制
   - 练习：[exercises/basic/fault-injection.md](./exercises/basic/)

### 阶段三：安全策略 (第5-6天)
1. **mTLS 配置**
   - 启用自动 mTLS
   - 配置认证策略
   - 练习：[exercises/basic/security.md](./exercises/basic/)

2. **授权控制**
   - 实现基于角色的访问控制
   - 配置服务间授权策略
   - 练习：[exercises/advanced/authorization.md](./exercises/advanced/)

### 阶段四：可观测性 (第7天)
1. **监控和指标**
   - 集成 Prometheus 和 Grafana
   - 配置自定义指标
   - 练习：[exercises/advanced/observability.md](./exercises/advanced/)

2. **分布式追踪**
   - 配置 Jaeger 追踪
   - 分析请求链路
   - 故障排查实践

## 🔧 核心功能演示

### 流量管理示例

```yaml
# VirtualService 示例
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

### 安全策略示例

```yaml
# PeerAuthentication 示例
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
```

## 📊 验证检查点

### 基础功能验证
- [ ] Istio 控制平面正常运行
- [ ] 示例应用成功部署并注入 sidecar
- [ ] 可以通过 Istio Gateway 访问应用
- [ ] 基本的路由规则生效

### 高级功能验证
- [ ] 流量分发和故障注入正常工作
- [ ] mTLS 自动启用并正常工作
- [ ] 授权策略有效阻止未授权访问
- [ ] 监控指标正确收集和展示
- [ ] 分布式追踪链路完整

## 🛠️ 常用命令

```bash
# 查看 Istio 状态
istioctl analyze

# 检查代理配置
istioctl proxy-config cluster <pod-name>

# 查看访问日志
kubectl logs -f <pod-name> -c istio-proxy

# 生成流量
for i in {1..100}; do curl -s http://$GATEWAY_URL/productpage; done
```

## 🔍 故障排查

遇到问题时，请参考：
- [故障排查指南](./docs/TROUBLESHOOTING.md)
- [Istio 官方文档](https://istio.io/latest/docs/)
- [常见问题解答](./docs/FAQ.md)

## 📈 进阶学习

完成基础实践后，可以探索：
- 多集群服务网格部署
- 自定义 Envoy 过滤器
- 服务网格性能优化
- 与其他 CNCF 项目集成

## 🎉 项目完成标准

- [ ] 成功部署 Istio 服务网格
- [ ] 实现基本的流量管理功能
- [ ] 配置安全策略并验证效果
- [ ] 集成监控和追踪系统
- [ ] 完成所有基础练习
- [ ] 能够独立排查常见问题

---

**准备好探索服务网格的强大功能了吗？** 🚀

从 [学习指南](./docs/LEARNING_GUIDE.md) 开始您的服务网格之旅！
