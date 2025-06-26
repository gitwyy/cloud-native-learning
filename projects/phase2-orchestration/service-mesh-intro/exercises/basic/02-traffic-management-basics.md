# 练习 2: 流量管理基础

> **目标**: 学习使用 VirtualService 和 DestinationRule 进行基本的流量管理

## 📋 练习概述

在这个练习中，您将：
1. 理解 VirtualService 和 DestinationRule 的作用
2. 实现基于版本的路由
3. 配置基于用户的路由
4. 实现权重路由

## 🎯 学习目标

- 掌握 VirtualService 的配置方法
- 理解 DestinationRule 的子集概念
- 学会实现不同的路由策略
- 了解流量分发的控制方法

## 📚 前置条件

- 完成练习 1: 环境搭建和验证
- Bookinfo 应用正常运行
- 熟悉 kubectl 基本操作

## 🛠️ 实践步骤

### 步骤 1: 理解当前状态

1. **查看当前路由配置**
```bash
# 查看现有的 VirtualService
kubectl get virtualservice

# 查看 DestinationRule
kubectl get destinationrule

# 查看详细配置
kubectl describe virtualservice bookinfo
kubectl describe destinationrule reviews
```

2. **观察当前行为**
```bash
# 多次访问应用，观察 reviews 服务的不同版本
for i in {1..10}; do
  curl -s "http://$GATEWAY_URL/productpage" | grep -A 2 -B 2 "reviews"
  echo "---"
  sleep 1
done
```

**观察**: 默认情况下，流量会随机分发到不同版本的 reviews 服务

### 步骤 2: 配置所有流量到 v1

1. **应用 v1 路由规则**
```bash
# 将所有流量路由到 v1 版本
kubectl apply -f manifests/traffic-management/virtual-service-all-v1.yaml

# 查看配置
kubectl get virtualservice reviews -o yaml
```

2. **验证路由效果**
```bash
# 多次访问，确认只看到 v1 版本（无星级）
for i in {1..5}; do
  curl -s "http://$GATEWAY_URL/productpage" | grep -A 5 -B 5 "reviews"
  echo "---"
done
```

**预期结果**: 所有请求都显示无星级的 reviews（v1 版本）

### 步骤 3: 基于用户的路由

1. **配置用户路由规则**
```bash
# 为 jason 用户配置路由到 v2
kubectl apply -f manifests/traffic-management/virtual-service-reviews-test-v2.yaml

# 查看配置变化
kubectl describe virtualservice reviews
```

2. **测试用户路由**
```bash
# 测试普通用户（应该看到 v1 - 无星级）
curl -s "http://$GATEWAY_URL/productpage" | grep -A 5 -B 5 "reviews"

echo "---"

# 测试 jason 用户（应该看到 v2 - 黑色星级）
curl -s -H "end-user: jason" "http://$GATEWAY_URL/productpage" | grep -A 5 -B 5 "reviews"
```

3. **在浏览器中测试**
```bash
# 获取访问地址
echo "访问地址: http://$GATEWAY_URL/productpage"
echo "1. 正常访问应该看到无星级"
echo "2. 登录为 jason 用户应该看到黑色星级"
```

**预期结果**: 
- 普通用户看到无星级 reviews
- jason 用户看到黑色星级 reviews

### 步骤 4: 权重路由

1. **配置权重路由**
```bash
# 配置 50% 流量到 v1，50% 到 v3
kubectl apply -f manifests/traffic-management/virtual-service-reviews-50-v3.yaml

# 查看配置
kubectl get virtualservice reviews -o yaml
```

2. **测试权重分发**
```bash
# 发送多个请求，统计不同版本的比例
echo "测试权重路由（50% v1 无星级，50% v3 红色星级）:"
v1_count=0
v3_count=0

for i in {1..20}; do
  response=$(curl -s "http://$GATEWAY_URL/productpage")
  if echo "$response" | grep -q "glyphicon-star-empty"; then
    v1_count=$((v1_count + 1))
    echo "Request $i: v1 (无星级)"
  elif echo "$response" | grep -q "red"; then
    v3_count=$((v3_count + 1))
    echo "Request $i: v3 (红色星级)"
  else
    echo "Request $i: 未知版本"
  fi
done

echo "统计结果:"
echo "v1 (无星级): $v1_count 次"
echo "v3 (红色星级): $v3_count 次"
```

**预期结果**: 大约 50% 的请求显示无星级，50% 显示红色星级

### 步骤 5: 完全切换到 v3

1. **切换所有流量到 v3**
```bash
# 将所有流量路由到 v3
kubectl apply -f manifests/traffic-management/virtual-service-reviews-v3.yaml

# 验证配置
kubectl describe virtualservice reviews
```

2. **验证切换效果**
```bash
# 多次访问，确认只看到 v3 版本（红色星级）
for i in {1..5}; do
  curl -s "http://$GATEWAY_URL/productpage" | grep -A 5 -B 5 "reviews"
  echo "---"
done
```

**预期结果**: 所有请求都显示红色星级的 reviews（v3 版本）

### 步骤 6: 高级路由配置

1. **基于请求头的路由**
```yaml
# 创建自定义路由规则
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        user-agent:
          regex: ".*Chrome.*"
    route:
    - destination:
        host: reviews
        subset: v2
  - match:
    - headers:
        user-agent:
          regex: ".*Firefox.*"
    route:
    - destination:
        host: reviews
        subset: v3
  - route:
    - destination:
        host: reviews
        subset: v1
EOF
```

2. **测试不同 User-Agent**
```bash
# Chrome 用户应该看到 v2
curl -s -H "User-Agent: Mozilla/5.0 (Chrome)" "http://$GATEWAY_URL/productpage" | grep -A 5 -B 5 "reviews"

echo "---"

# Firefox 用户应该看到 v3
curl -s -H "User-Agent: Mozilla/5.0 (Firefox)" "http://$GATEWAY_URL/productpage" | grep -A 5 -B 5 "reviews"
```

## ✅ 验证检查点

### 基础验证
- [ ] 成功配置所有流量到 v1 版本
- [ ] 基于用户的路由正常工作
- [ ] 权重路由按预期分发流量
- [ ] 完全切换到 v3 版本成功

### 高级验证
- [ ] 理解 VirtualService 的匹配规则
- [ ] 掌握 DestinationRule 的子集概念
- [ ] 能够自定义路由规则
- [ ] 了解不同路由策略的应用场景

## 🔍 故障排查

### 常见问题

1. **路由规则不生效**
```bash
# 检查配置语法
kubectl describe virtualservice reviews

# 查看代理配置
istioctl proxy-config routes $SLEEP_POD

# 检查是否有冲突的规则
kubectl get virtualservice --all-namespaces
```

2. **权重分发不均匀**
```bash
# 检查 DestinationRule 配置
kubectl describe destinationrule reviews

# 查看端点配置
istioctl proxy-config endpoints $SLEEP_POD
```

3. **用户路由失效**
```bash
# 检查请求头是否正确传递
kubectl logs -f deployment/productpage-v1 -c istio-proxy

# 验证匹配条件
kubectl get virtualservice reviews -o yaml
```

## 🎓 深入理解

### VirtualService 核心概念
- **hosts**: 定义路由适用的服务
- **http**: HTTP 路由规则
- **match**: 匹配条件（headers, uri, method 等）
- **route**: 路由目标和权重

### DestinationRule 核心概念
- **host**: 目标服务
- **subsets**: 服务子集定义
- **trafficPolicy**: 流量策略（负载均衡、连接池等）

### 路由策略类型
1. **版本路由**: 基于服务版本
2. **用户路由**: 基于用户身份
3. **权重路由**: 基于流量比例
4. **条件路由**: 基于请求特征

## 📝 练习总结

完成这个练习后，您应该：
- 掌握了基本的流量管理配置
- 理解了不同路由策略的应用
- 学会了金丝雀部署的实现方法
- 熟悉了 VirtualService 和 DestinationRule 的使用

## 🚀 下一步

继续进行 [练习 3: 故障注入和恢复](./03-fault-injection.md)，学习如何测试系统的弹性和故障处理能力。
