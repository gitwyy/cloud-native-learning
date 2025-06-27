# 端口转发使用指南

## 🔗 端口转发脚本概述

`port-forward.sh` 脚本提供了一个便捷的方式来管理云原生可观测性系统的端口转发，让您可以轻松访问 Kubernetes 集群中的服务。

## 📋 支持的服务

| 服务名 | 本地端口 | 功能描述 |
|--------|----------|----------|
| kibana | 5601 | 日志分析和可视化平台 |
| jaeger | 16686 | 分布式链路追踪查询界面 |
| elasticsearch | 9200 | 日志数据存储和搜索 API |
| user-service | 8080 | 示例微服务应用 |

## 🚀 基本使用

### 启动所有端口转发
```bash
cd scripts
./port-forward.sh start
```

### 启动特定服务的端口转发
```bash
./port-forward.sh start kibana      # 只启动 Kibana
./port-forward.sh start jaeger      # 只启动 Jaeger
./port-forward.sh start elasticsearch  # 只启动 Elasticsearch
./port-forward.sh start user-service   # 只启动用户服务
```

### 查看端口转发状态
```bash
./port-forward.sh status
```

### 停止端口转发
```bash
./port-forward.sh stop              # 停止所有
./port-forward.sh stop kibana       # 停止特定服务
```

### 重启端口转发
```bash
./port-forward.sh restart           # 重启所有
./port-forward.sh restart jaeger    # 重启特定服务
```

## 🌐 服务访问地址

启动端口转发后，您可以通过以下地址访问服务：

### Web 界面
- **Kibana**: http://localhost:5601
  - 日志查询和分析
  - 创建可视化图表
  - 构建监控仪表板

- **Jaeger**: http://localhost:16686
  - 查看分布式追踪数据
  - 分析服务调用链
  - 性能瓶颈诊断

### API 接口
- **Elasticsearch**: http://localhost:9200
  - 集群健康状态: `GET /_cluster/health`
  - 索引列表: `GET /_cat/indices`
  - 搜索日志: `GET /fluentbit/_search`

- **用户服务**: http://localhost:8080
  - 健康检查: `GET /health`
  - 用户列表: `GET /api/users`
  - 单个用户: `GET /api/users/{id}`

## 📝 实用示例

### 检查系统健康状态
```bash
# Elasticsearch 集群健康
curl http://localhost:9200/_cluster/health

# 用户服务健康检查
curl http://localhost:8080/health

# Kibana 状态
curl http://localhost:5601/api/status
```

### 查询日志数据
```bash
# 查看所有索引
curl http://localhost:9200/_cat/indices

# 搜索用户服务相关日志
curl "http://localhost:9200/fluentbit/_search?q=user-service&size=10&pretty"

# 查看最新的日志条目
curl "http://localhost:9200/fluentbit/_search?sort=@timestamp:desc&size=5&pretty"
```

### 查看追踪数据
```bash
# 获取服务列表
curl http://localhost:16686/api/services

# 查看用户服务的追踪数据
curl "http://localhost:16686/api/traces?service=user-service&limit=10"
```

### 生成测试数据
```bash
# 生成用户服务请求（产生日志和追踪数据）
for i in {1..10}; do
  curl -s http://localhost:8080/api/users > /dev/null
  curl -s http://localhost:8080/api/users/$i > /dev/null
done
```

## 🔧 高级功能

### 自动重启机制
脚本会自动检测端口冲突并尝试清理：
```bash
# 如果端口被占用，脚本会自动终止冲突进程
./port-forward.sh start
```

### 进程管理
脚本使用 PID 文件管理端口转发进程：
```bash
# PID 文件位置
ls /tmp/k8s-port-forward/

# 手动检查进程状态
ps aux | grep "kubectl port-forward"
```

### 状态监控
```bash
# 详细状态信息
./port-forward.sh status

# 检查特定端口
lsof -i :5601
lsof -i :16686
```

## 🛠️ 故障排查

### 常见问题

1. **端口被占用**
   ```bash
   # 查看占用端口的进程
   lsof -i :5601
   
   # 强制停止所有端口转发
   ./port-forward.sh stop
   pkill -f "kubectl port-forward"
   ```

2. **服务无法访问**
   ```bash
   # 检查 Pod 状态
   kubectl get pods -n logging
   kubectl get pods -n tracing
   
   # 检查服务状态
   kubectl get svc -n logging
   kubectl get svc -n tracing
   ```

3. **端口转发进程异常退出**
   ```bash
   # 查看进程日志
   ./port-forward.sh status
   
   # 重启端口转发
   ./port-forward.sh restart
   ```

### 调试模式
```bash
# 手动启动端口转发查看详细输出
kubectl port-forward -n logging svc/kibana 5601:5601 -v=6
```

## 🔄 集成到工作流

### 与 setup.sh 集成
setup.sh 脚本部署完成后会提示使用端口转发：
```bash
./setup.sh
# 部署完成后
./port-forward.sh start
```

### 与 test.sh 集成
test.sh 脚本会检查端口转发脚本的可用性：
```bash
./test.sh
# 包含端口转发脚本可用性测试
```

### 开发工作流
```bash
# 1. 部署系统
./setup.sh

# 2. 启动端口转发
./port-forward.sh start

# 3. 验证功能
./test.sh

# 4. 开发和测试
# 访问 http://localhost:5601 和 http://localhost:16686

# 5. 清理环境
./port-forward.sh stop
./cleanup.sh
```

## 📊 性能考虑

### 资源使用
- 每个端口转发进程占用少量内存（~10MB）
- CPU 使用率很低，主要是网络转发
- 不会影响 Kubernetes 集群性能

### 网络延迟
- 本地访问延迟 < 1ms
- 适合开发和测试环境
- 生产环境建议使用 Ingress 或 LoadBalancer

## 🔒 安全注意事项

1. **仅限本地访问**: 端口转发只绑定到 localhost
2. **开发环境使用**: 不建议在生产环境使用
3. **进程管理**: 脚本会自动清理进程，避免资源泄露
4. **权限控制**: 需要 kubectl 访问权限

## 💡 最佳实践

1. **使用脚本管理**: 避免手动启动端口转发
2. **定期检查状态**: 使用 `status` 命令监控
3. **及时清理**: 不使用时停止端口转发
4. **批量操作**: 使用 `start` 和 `stop` 管理所有服务
5. **集成测试**: 结合 test.sh 验证功能

---

通过这个端口转发脚本，您可以轻松管理云原生可观测性系统的访问，提高开发和学习效率！
