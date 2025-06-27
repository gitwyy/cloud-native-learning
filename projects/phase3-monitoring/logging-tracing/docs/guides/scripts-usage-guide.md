# 云原生日志收集与分析项目脚本使用说明

## 脚本概览

本项目提供了三个主要脚本来管理云原生可观测性系统：

1. **scripts/setup.sh** - 一键部署脚本
2. **scripts/test.sh** - 功能测试脚本
3. **scripts/cleanup.sh** - 环境清理脚本

所有脚本都位于 `scripts/` 目录中，保持项目结构的整洁性。

## 1. 部署脚本 (scripts/setup.sh)

### 功能描述
自动部署完整的云原生可观测性栈，包括：
- Elasticsearch 集群（日志存储）
- Fluent Bit（日志收集器）
- Kibana（日志可视化）
- Jaeger（链路追踪）
- 示例微服务应用

### 使用方法
```bash
cd scripts
./setup.sh
```

### 前置条件
- Kubernetes 集群正在运行
- kubectl 已配置并可连接集群
- Docker 已安装（用于构建镜像）
- 如果使用 minikube，会自动启用存储提供程序

### 部署流程
1. 检查前置条件
2. 创建 logging 和 tracing 命名空间
3. 部署 Elasticsearch（使用简化配置）
4. 部署 Fluent Bit（自动获取 ES Pod IP）
5. 部署 Kibana（自动获取 ES Pod IP）
6. 部署 Jaeger（使用内存存储）
7. 构建并部署用户服务
8. 验证所有组件状态

### 特殊处理
- 自动检测和处理 DNS 解析问题
- 使用 Pod IP 替代服务名进行组件间通信
- 兼容 Elasticsearch 8.x 版本
- 自动构建和加载用户服务 Docker 镜像

## 2. 测试脚本 (test.sh)

### 功能描述
全面测试可观测性系统的各个组件和数据流：

### 测试项目
1. **基础连接测试**
   - Kubernetes 集群连接
   - 命名空间检查

2. **组件部署测试**
   - Elasticsearch 部署状态
   - Fluent Bit 部署状态
   - Kibana 部署状态
   - Jaeger 部署状态
   - 用户服务部署状态

3. **API 功能测试**
   - Elasticsearch API 响应
   - Kibana API 状态
   - Jaeger API 功能
   - 用户服务健康检查
   - 用户服务业务功能

4. **数据流测试**
   - Elasticsearch 数据存在性
   - 追踪数据生成
   - 负载生成测试
   - 端到端数据流验证

### 使用方法
```bash
cd scripts
./test.sh
```

### 输出示例
```
==========================================
🧪 云原生可观测性系统测试
==========================================

[INFO] 测试 1: Kubernetes 集群连接
[SUCCESS] ✅ Kubernetes 集群连接
...
==========================================
📊 测试结果汇总
==========================================
总测试数: 16
通过: 16
失败: 0
成功率: 100%

[SUCCESS] 🎉 所有测试通过！系统运行正常
```

## 3. 清理脚本 (cleanup.sh)

### 功能描述
完全清理部署的所有组件和资源：

### 清理内容
1. 应用服务（用户服务）
2. Jaeger 追踪系统
3. Kibana 可视化平台
4. Fluent Bit 日志收集器
5. Elasticsearch 集群
6. 相关命名空间
7. Docker 镜像（可选）
8. 端口转发进程

### 使用方法
```bash
cd scripts
./cleanup.sh
```

### 交互式选项
脚本会询问是否清理 Docker 镜像：
```
是否清理 Docker 镜像？(y/N):
```

### 安全特性
- 使用 `--ignore-not-found=true` 避免删除不存在资源时报错
- 等待资源删除完成后再删除命名空间
- 清理端口转发进程避免端口占用

## 使用场景

### 完整部署流程
```bash
# 1. 部署系统
cd scripts
./setup.sh

# 2. 验证部署
./test.sh

# 3. 使用系统...

# 4. 清理环境
./cleanup.sh
```

### 开发调试流程
```bash
# 快速测试当前状态
cd scripts
./test.sh

# 如果有问题，查看具体组件状态
kubectl get pods -n logging
kubectl get pods -n tracing
kubectl logs -n logging <pod-name>

# 重新部署特定组件
cd ..
kubectl delete -f manifests/elasticsearch/
kubectl apply -f manifests/elasticsearch/elasticsearch-simple.yaml
```

## 故障排查

### 常见问题

1. **存储提供程序问题**
   ```bash
   minikube addons enable storage-provisioner
   ```

2. **DNS 解析问题**
   - 脚本会自动使用 Pod IP 替代服务名

3. **镜像拉取问题**
   ```bash
   # 检查镜像是否存在
   minikube image ls | grep user-service
   
   # 重新构建和加载
   cd apps/user-service
   docker build -t user-service:latest .
   minikube image load user-service:latest
   ```

4. **端口冲突**
   ```bash
   # 清理端口转发进程
   pkill -f "kubectl port-forward"
   ```

### 日志查看
```bash
# 查看组件日志
kubectl logs -n logging -l app=elasticsearch
kubectl logs -n logging -l app=fluent-bit
kubectl logs -n logging -l app=kibana
kubectl logs -n tracing -l app=jaeger
kubectl logs -l app=user-service

# 查看事件
kubectl get events -n logging
kubectl get events -n tracing
```

## 访问地址

部署完成后，可通过以下方式访问各组件：

### 端口转发方式
```bash
# Elasticsearch
kubectl port-forward -n logging svc/elasticsearch 9200:9200

# Kibana
kubectl port-forward -n logging svc/kibana 5601:5601

# Jaeger
kubectl port-forward -n tracing svc/jaeger-query 16686:16686

# 用户服务
kubectl port-forward svc/user-service 8080:8080
```

### NodePort 方式（如果支持）
- Elasticsearch: http://\<node-ip\>:30920
- Kibana: http://\<node-ip\>:30561  
- Jaeger: http://\<node-ip\>:30686

## 注意事项

1. **资源要求**: 确保集群有足够的 CPU 和内存资源
2. **网络策略**: 某些集群可能有网络策略限制
3. **存储**: 使用 emptyDir 存储，重启后数据会丢失
4. **安全**: 所有组件都禁用了安全认证，仅用于学习环境

## 扩展功能

### 添加新的测试用例
在 `test.sh` 中添加新的测试函数：
```bash
test_new_feature() {
    # 测试逻辑
    return 0  # 成功
}

# 在 main 函数中调用
run_test "新功能测试" "test_new_feature"
```

### 自定义部署配置
修改 `manifests/` 目录下的 YAML 文件来自定义部署配置。
