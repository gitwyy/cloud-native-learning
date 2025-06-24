# 微服务运维手册

## 📋 概述

本手册为微服务Kubernetes平台的日常运维提供详细指导，包括监控、维护、扩容、备份等操作流程。

## 🎯 运维目标

- **可用性**: 99.9%以上服务可用性
- **性能**: API响应时间 < 200ms
- **扩展性**: 支持自动水平扩缩容
- **安全性**: 数据安全和访问控制
- **可观测性**: 完整的监控和日志体系

## 🔧 日常运维任务

### 每日检查清单

#### 系统健康检查
```bash
# 运行健康检查脚本
./scripts/health-check.sh

# 检查关键指标
kubectl top nodes
kubectl top pods -n ecommerce-k8s

# 查看最近事件
kubectl get events -n ecommerce-k8s --sort-by=.metadata.creationTimestamp | tail -20
```

#### 服务状态检查
```bash
# 检查所有Pod状态
kubectl get pods -n ecommerce-k8s -o wide

# 检查服务端点
kubectl get endpoints -n ecommerce-k8s

# 检查HPA状态
kubectl get hpa -n ecommerce-k8s
```

#### 存储检查
```bash
# 检查PVC状态
kubectl get pvc -n ecommerce-k8s

# 检查存储使用情况
kubectl exec -it deployment/postgres -n ecommerce-k8s -- df -h
```

### 每周维护任务

#### 日志清理
```bash
# 清理旧日志文件
find .taskmaster/logs -name "*.log" -mtime +7 -delete

# 轮转应用日志
kubectl exec -it deployment/postgres -n ecommerce-k8s -- logrotate /etc/logrotate.conf
```

#### 性能测试
```bash
# 运行负载测试
./tests/load-tests.sh -s basic

# 分析性能报告
cat .taskmaster/reports/load-test-report-*.json
```

#### 安全检查
```bash
# 检查网络策略
kubectl get networkpolicies -n ecommerce-k8s

# 检查RBAC配置
kubectl get rolebindings,clusterrolebindings -n ecommerce-k8s

# 扫描镜像漏洞（如果有工具）
# trivy image user-service:1.0
```

### 每月维护任务

#### 容量规划
```bash
# 分析资源使用趋势
kubectl top pods -n ecommerce-k8s --sort-by=cpu
kubectl top pods -n ecommerce-k8s --sort-by=memory

# 检查存储增长
kubectl get pvc -n ecommerce-k8s -o custom-columns=NAME:.metadata.name,SIZE:.spec.resources.requests.storage,USED:.status.capacity.storage
```

#### 备份验证
```bash
# 验证数据库备份
kubectl exec -it deployment/postgres -n ecommerce-k8s -- pg_dump -U postgres ecommerce > backup-test.sql

# 验证配置备份
kubectl get all,configmaps,secrets,pvc -n ecommerce-k8s -o yaml > config-backup.yaml
```

## 📊 监控和告警

### 关键监控指标

#### 应用层指标
- **API响应时间**: 平均 < 200ms，P95 < 500ms
- **错误率**: < 1%
- **请求量**: QPS监控
- **用户活跃度**: 在线用户数

#### 基础设施指标
- **CPU使用率**: < 70%
- **内存使用率**: < 80%
- **磁盘使用率**: < 85%
- **网络延迟**: < 10ms

#### 业务指标
- **订单成功率**: > 99%
- **支付成功率**: > 98%
- **用户注册转化率**: 监控趋势
- **商品浏览转化率**: 监控趋势

### 监控命令

#### 实时监控
```bash
# 监控Pod资源使用
watch kubectl top pods -n ecommerce-k8s

# 监控服务状态
watch kubectl get pods -n ecommerce-k8s

# 监控HPA状态
watch kubectl get hpa -n ecommerce-k8s
```

#### 日志监控
```bash
# 实时查看错误日志
./scripts/logs.sh -f all | grep -i error

# 监控特定服务日志
./scripts/logs.sh -f user

# 分析日志模式
./scripts/logs.sh user | grep -E "(error|warning|exception)" | tail -20
```

### 告警设置

#### 关键告警
- Pod重启次数 > 5次/小时
- 服务不可用 > 1分钟
- CPU使用率 > 80%持续5分钟
- 内存使用率 > 90%持续3分钟
- 磁盘使用率 > 90%
- API错误率 > 5%持续2分钟

#### 告警响应流程
1. **立即响应** (< 5分钟)
   - 确认告警真实性
   - 评估影响范围
   - 启动应急响应

2. **问题诊断** (< 15分钟)
   - 收集相关日志
   - 分析根本原因
   - 制定解决方案

3. **问题解决** (< 30分钟)
   - 实施修复措施
   - 验证修复效果
   - 更新告警状态

4. **事后总结** (< 24小时)
   - 编写事故报告
   - 分析预防措施
   - 更新运维文档

## 🔄 扩缩容管理

### 手动扩缩容

#### 扩容操作
```bash
# 扩容用户服务到5个副本
kubectl scale deployment user-service --replicas=5 -n ecommerce-k8s

# 扩容所有微服务
./scripts/scale.sh all 3

# 验证扩容结果
kubectl get pods -l tier=backend -n ecommerce-k8s
```

#### 缩容操作
```bash
# 缩容到最小副本数
./scripts/scale.sh user 2

# 验证缩容结果
kubectl get deployment user-service -n ecommerce-k8s
```

### 自动扩缩容 (HPA)

#### 启用HPA
```bash
# 为用户服务启用HPA
./scripts/scale.sh -a user --min 2 --max 10 --cpu 70

# 检查HPA状态
kubectl get hpa user-service-hpa -n ecommerce-k8s

# 查看HPA详情
kubectl describe hpa user-service-hpa -n ecommerce-k8s
```

#### HPA调优
```bash
# 调整CPU阈值
kubectl patch hpa user-service-hpa -n ecommerce-k8s -p '{"spec":{"metrics":[{"type":"Resource","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":60}}}]}}'

# 调整副本数范围
kubectl patch hpa user-service-hpa -n ecommerce-k8s -p '{"spec":{"minReplicas":3,"maxReplicas":15}}'
```

### 扩容决策指南

#### 何时扩容
- CPU使用率持续 > 70%
- 内存使用率持续 > 80%
- API响应时间 > 500ms
- 错误率 > 2%
- 队列积压严重

#### 扩容策略
- **预防性扩容**: 在流量高峰前扩容
- **响应式扩容**: 基于实时指标自动扩容
- **计划性扩容**: 基于业务增长预期扩容

## 💾 备份和恢复

### 数据备份

#### 数据库备份
```bash
# 创建数据库备份
kubectl exec -it deployment/postgres -n ecommerce-k8s -- pg_dump -U postgres -h localhost ecommerce > backup-$(date +%Y%m%d-%H%M%S).sql

# 自动化备份脚本
cat > backup-database.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/postgres"
DATE=$(date +%Y%m%d-%H%M%S)
kubectl exec -it deployment/postgres -n ecommerce-k8s -- pg_dump -U postgres ecommerce > "$BACKUP_DIR/ecommerce-$DATE.sql"
# 保留最近7天的备份
find "$BACKUP_DIR" -name "ecommerce-*.sql" -mtime +7 -delete
EOF

chmod +x backup-database.sh
```

#### 配置备份
```bash
# 备份Kubernetes配置
kubectl get all,configmaps,secrets,pvc -n ecommerce-k8s -o yaml > k8s-config-backup-$(date +%Y%m%d).yaml

# 备份应用配置
cp -r k8s/ backup/k8s-$(date +%Y%m%d)/
```

#### 文件备份
```bash
# 备份上传文件
kubectl exec -it deployment/api-gateway -n ecommerce-k8s -- tar -czf /tmp/uploads-backup.tar.gz /var/uploads
kubectl cp ecommerce-k8s/api-gateway-xxx:/tmp/uploads-backup.tar.gz ./uploads-backup-$(date +%Y%m%d).tar.gz
```

### 数据恢复

#### 数据库恢复
```bash
# 从备份恢复数据库
kubectl exec -i deployment/postgres -n ecommerce-k8s -- psql -U postgres -d ecommerce < backup-20240101-120000.sql

# 验证恢复结果
kubectl exec -it deployment/postgres -n ecommerce-k8s -- psql -U postgres -d ecommerce -c "SELECT COUNT(*) FROM users;"
```

#### 配置恢复
```bash
# 恢复Kubernetes配置
kubectl apply -f k8s-config-backup-20240101.yaml

# 重启相关服务
kubectl rollout restart deployment -l tier=backend -n ecommerce-k8s
```

### 灾难恢复

#### 完全重建流程
```bash
# 1. 删除现有环境
kubectl delete namespace ecommerce-k8s

# 2. 重新部署基础设施
./scripts/deploy.sh

# 3. 恢复数据
kubectl exec -i deployment/postgres -n ecommerce-k8s -- psql -U postgres -d ecommerce < latest-backup.sql

# 4. 验证服务
./scripts/health-check.sh
./tests/api-tests.sh
```

## 🔐 安全管理

### 访问控制

#### RBAC管理
```bash
# 查看当前权限
kubectl get rolebindings,clusterrolebindings -n ecommerce-k8s

# 创建只读用户
kubectl create serviceaccount readonly-user -n ecommerce-k8s
kubectl create rolebinding readonly-binding --clusterrole=view --serviceaccount=ecommerce-k8s:readonly-user -n ecommerce-k8s
```

#### 网络安全
```bash
# 检查网络策略
kubectl get networkpolicies -n ecommerce-k8s

# 测试网络连通性
kubectl exec -it deployment/user-service -n ecommerce-k8s -- nc -zv postgres 5432
```

### 密钥管理

#### 更新密钥
```bash
# 更新数据库密码
kubectl patch secret postgres-secret -n ecommerce-k8s -p '{"data":{"password":"bmV3LXBhc3N3b3Jk"}}'

# 重启相关服务
kubectl rollout restart deployment/postgres -n ecommerce-k8s
```

#### 证书管理
```bash
# 检查证书有效期
kubectl get secrets -n ecommerce-k8s -o json | jq -r '.items[] | select(.type=="kubernetes.io/tls") | .metadata.name'

# 更新TLS证书
kubectl create secret tls tls-secret --cert=cert.pem --key=key.pem -n ecommerce-k8s --dry-run=client -o yaml | kubectl apply -f -
```

## 🔄 版本更新

### 滚动更新

#### 更新应用镜像
```bash
# 更新用户服务镜像
kubectl set image deployment/user-service user-service=user-service:1.1 -n ecommerce-k8s

# 查看更新状态
kubectl rollout status deployment/user-service -n ecommerce-k8s

# 查看更新历史
kubectl rollout history deployment/user-service -n ecommerce-k8s
```

#### 回滚操作
```bash
# 回滚到上一个版本
kubectl rollout undo deployment/user-service -n ecommerce-k8s

# 回滚到指定版本
kubectl rollout undo deployment/user-service --to-revision=2 -n ecommerce-k8s
```

### 蓝绿部署

#### 准备新版本
```bash
# 创建新版本部署
kubectl apply -f k8s/microservices/user-service-v2.yaml

# 验证新版本
kubectl get pods -l app=user-service,version=v2 -n ecommerce-k8s
```

#### 切换流量
```bash
# 更新Service选择器
kubectl patch service user-service -n ecommerce-k8s -p '{"spec":{"selector":{"version":"v2"}}}'

# 验证切换结果
kubectl get endpoints user-service -n ecommerce-k8s
```

## 📈 性能优化

### 资源优化

#### CPU优化
```bash
# 分析CPU使用模式
kubectl top pods -n ecommerce-k8s --sort-by=cpu

# 调整CPU请求和限制
kubectl patch deployment user-service -n ecommerce-k8s -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","resources":{"requests":{"cpu":"200m"},"limits":{"cpu":"500m"}}}]}}}}'
```

#### 内存优化
```bash
# 分析内存使用模式
kubectl top pods -n ecommerce-k8s --sort-by=memory

# 调整内存请求和限制
kubectl patch deployment user-service -n ecommerce-k8s -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","resources":{"requests":{"memory":"256Mi"},"limits":{"memory":"512Mi"}}}]}}}}'
```

### 数据库优化

#### PostgreSQL优化
```bash
# 检查数据库连接数
kubectl exec -it deployment/postgres -n ecommerce-k8s -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# 分析慢查询
kubectl exec -it deployment/postgres -n ecommerce-k8s -- psql -U postgres -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# 优化数据库配置
kubectl patch configmap postgres-config -n ecommerce-k8s -p '{"data":{"postgresql.conf":"max_connections = 200\nshared_buffers = 256MB\n"}}'
```

#### Redis优化
```bash
# 检查Redis内存使用
kubectl exec -it deployment/redis -n ecommerce-k8s -- redis-cli -a redis123 info memory

# 分析Redis性能
kubectl exec -it deployment/redis -n ecommerce-k8s -- redis-cli -a redis123 info stats
```

## 📞 应急响应

### 紧急联系人

| 角色 | 姓名 | 电话 | 邮箱 | 职责 |
|------|------|------|------|------|
| 系统管理员 | 张三 | 138xxxx0001 | admin@company.com | 系统整体维护 |
| 数据库管理员 | 李四 | 138xxxx0002 | dba@company.com | 数据库相关问题 |
| 网络管理员 | 王五 | 138xxxx0003 | network@company.com | 网络相关问题 |
| 开发负责人 | 赵六 | 138xxxx0004 | dev@company.com | 应用相关问题 |

### 应急处理流程

#### 服务完全不可用
1. **立即响应** (0-5分钟)
   ```bash
   # 快速诊断
   ./scripts/health-check.sh
   kubectl get pods -n ecommerce-k8s
   ```

2. **紧急恢复** (5-15分钟)
   ```bash
   # 重启所有服务
   kubectl rollout restart deployment -l tier=backend -n ecommerce-k8s
   
   # 如果仍然失败，重新部署
   kubectl delete namespace ecommerce-k8s
   ./scripts/deploy.sh
   ```

3. **数据恢复** (15-30分钟)
   ```bash
   # 从最新备份恢复数据
   kubectl exec -i deployment/postgres -n ecommerce-k8s -- psql -U postgres -d ecommerce < latest-backup.sql
   ```

#### 数据库故障
```bash
# 检查数据库状态
kubectl get pods -l app=postgres -n ecommerce-k8s

# 重启数据库
kubectl rollout restart deployment/postgres -n ecommerce-k8s

# 如果数据损坏，从备份恢复
kubectl exec -i deployment/postgres -n ecommerce-k8s -- psql -U postgres -d ecommerce < backup.sql
```

#### 网络故障
```bash
# 检查网络策略
kubectl get networkpolicies -n ecommerce-k8s

# 临时禁用网络策略
kubectl delete networkpolicies --all -n ecommerce-k8s

# 检查DNS解析
kubectl exec -it deployment/user-service -n ecommerce-k8s -- nslookup postgres
```

## 📚 运维工具

### 自动化脚本
- `./scripts/health-check.sh` - 健康检查
- `./scripts/logs.sh` - 日志管理
- `./scripts/scale.sh` - 扩缩容管理
- `./scripts/deploy.sh` - 部署管理

### 测试工具
- `./tests/api-tests.sh` - API功能测试
- `./tests/load-tests.sh` - 负载测试

### 监控工具
- `kubectl top` - 资源使用监控
- `kubectl get events` - 事件监控
- `kubectl logs` - 日志查看

## 📋 运维检查表

### 日常检查 ✅
- [ ] 系统健康检查
- [ ] 服务状态检查
- [ ] 资源使用检查
- [ ] 错误日志检查
- [ ] 备份状态检查

### 周度检查 ✅
- [ ] 性能测试
- [ ] 安全检查
- [ ] 日志清理
- [ ] 容量分析
- [ ] 更新检查

### 月度检查 ✅
- [ ] 备份验证
- [ ] 灾难恢复演练
- [ ] 性能优化
- [ ] 安全审计
- [ ] 文档更新

---

**记住：预防胜于治疗，监控胜于猜测！🔍**
