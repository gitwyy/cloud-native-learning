# 微服务Kubernetes故障排查指南

## 📋 概述

本文档提供微服务Kubernetes部署中常见问题的诊断和解决方案。按照问题类型分类，提供系统化的排查方法。

## 🔍 故障排查流程

### 基本排查步骤

1. **确认问题范围** - 是单个服务还是整体系统问题
2. **收集基础信息** - Pod状态、日志、事件
3. **分析根本原因** - 配置、资源、网络、存储
4. **实施解决方案** - 修复配置、重启服务、扩容资源
5. **验证修复效果** - 确认问题已解决

### 快速诊断命令

```bash
# 健康检查脚本
./scripts/health-check.sh

# 查看所有资源状态
kubectl get all -n ecommerce-k8s

# 查看最近事件
kubectl get events -n ecommerce-k8s --sort-by=.metadata.creationTimestamp

# 查看Pod详细状态
kubectl get pods -n ecommerce-k8s -o wide
```

## 🚨 Pod相关问题

### Pod无法启动

#### 症状
- Pod状态为 `Pending`、`CrashLoopBackOff`、`ImagePullBackOff`
- 应用无法访问

#### 诊断命令
```bash
# 查看Pod状态
kubectl get pods -n ecommerce-k8s

# 查看Pod详细信息
kubectl describe pod <pod-name> -n ecommerce-k8s

# 查看Pod日志
kubectl logs <pod-name> -n ecommerce-k8s

# 查看之前容器的日志
kubectl logs <pod-name> -n ecommerce-k8s --previous
```

#### 常见原因及解决方案

**1. 镜像拉取失败 (ImagePullBackOff)**
```bash
# 问题：镜像不存在或无权限访问
# 解决方案：
# 检查镜像名称和标签
kubectl describe pod <pod-name> -n ecommerce-k8s | grep -A5 "Events:"

# 重新构建镜像（Minikube环境）
eval $(minikube docker-env)
cd ../../phase1-containerization/ecommerce-basic
make build

# 检查镜像是否存在
docker images | grep user-service
```

**2. 资源不足 (Pending)**
```bash
# 问题：节点资源不足
# 解决方案：
# 检查节点资源
kubectl top nodes
kubectl describe nodes

# 调整资源请求
kubectl patch deployment user-service -n ecommerce-k8s -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","resources":{"requests":{"memory":"64Mi","cpu":"50m"}}}]}}}}'

# 或添加更多节点（云环境）
```

**3. 配置错误 (CrashLoopBackOff)**
```bash
# 问题：应用配置错误导致启动失败
# 解决方案：
# 检查ConfigMap配置
kubectl get configmap app-config -n ecommerce-k8s -o yaml

# 检查Secret配置
kubectl get secret app-secrets -n ecommerce-k8s -o yaml

# 修复配置后重启
kubectl rollout restart deployment/user-service -n ecommerce-k8s
```

**4. 健康检查失败**
```bash
# 问题：健康检查端点不可用
# 解决方案：
# 检查健康检查配置
kubectl describe deployment user-service -n ecommerce-k8s | grep -A10 "Liveness\|Readiness"

# 临时禁用健康检查进行调试
kubectl patch deployment user-service -n ecommerce-k8s -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","livenessProbe":null,"readinessProbe":null}]}}}}'

# 手动测试健康端点
kubectl exec -it deployment/user-service -n ecommerce-k8s -- curl localhost:5001/health
```

### Pod频繁重启

#### 症状
- Pod重启次数不断增加
- 应用间歇性不可用

#### 诊断方法
```bash
# 查看重启次数
kubectl get pods -n ecommerce-k8s

# 查看重启原因
kubectl describe pod <pod-name> -n ecommerce-k8s

# 监控Pod状态变化
kubectl get pods -n ecommerce-k8s -w
```

#### 解决方案
```bash
# 1. 内存泄漏导致OOMKilled
# 增加内存限制
kubectl patch deployment user-service -n ecommerce-k8s -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","resources":{"limits":{"memory":"512Mi"}}}]}}}}'

# 2. 应用异常退出
# 查看应用日志分析原因
kubectl logs -f deployment/user-service -n ecommerce-k8s

# 3. 健康检查过于严格
# 调整健康检查参数
kubectl patch deployment user-service -n ecommerce-k8s -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","livenessProbe":{"initialDelaySeconds":60,"periodSeconds":30}}]}}}}'
```

## 🌐 网络相关问题

### Service无法访问

#### 症状
- 服务间调用失败
- API网关无法路由到后端服务

#### 诊断命令
```bash
# 检查Service状态
kubectl get services -n ecommerce-k8s

# 检查Endpoints
kubectl get endpoints -n ecommerce-k8s

# 测试服务连通性
kubectl exec -it deployment/api-gateway -n ecommerce-k8s -- curl http://user-service/health

# 检查DNS解析
kubectl exec -it deployment/api-gateway -n ecommerce-k8s -- nslookup user-service
```

#### 常见问题及解决方案

**1. 标签选择器不匹配**
```bash
# 检查Service选择器
kubectl get service user-service -n ecommerce-k8s -o yaml | grep -A5 selector

# 检查Pod标签
kubectl get pods -l app=user-service -n ecommerce-k8s --show-labels

# 修复标签不匹配
kubectl label pods -l app=user-service app=user-service -n ecommerce-k8s --overwrite
```

**2. 端口配置错误**
```bash
# 检查Service端口配置
kubectl describe service user-service -n ecommerce-k8s

# 检查Pod端口配置
kubectl describe pod <pod-name> -n ecommerce-k8s | grep -A5 "Ports:"

# 修复端口配置
kubectl patch service user-service -n ecommerce-k8s -p '{"spec":{"ports":[{"port":80,"targetPort":5001}]}}'
```

**3. 网络策略阻止**
```bash
# 检查网络策略
kubectl get networkpolicies -n ecommerce-k8s

# 临时删除网络策略进行测试
kubectl delete networkpolicy user-service-netpol -n ecommerce-k8s

# 修复网络策略配置
kubectl apply -f k8s/microservices/user-service.yaml
```

### Ingress访问问题

#### 症状
- 外部无法访问应用
- Ingress返回404或502错误

#### 诊断方法
```bash
# 检查Ingress状态
kubectl get ingress -n ecommerce-k8s

# 检查Ingress控制器
kubectl get pods -n ingress-nginx

# 查看Ingress控制器日志
kubectl logs -f deployment/nginx-ingress-controller -n ingress-nginx
```

#### 解决方案
```bash
# 1. Ingress控制器未安装
# 安装Nginx Ingress控制器
kubectl apply -f k8s/ingress/install-ingress-controller.yaml

# 2. 域名解析问题
# 配置本地hosts文件
echo "$(minikube ip) ecommerce.local" | sudo tee -a /etc/hosts

# 3. 后端服务不可用
# 检查后端服务状态
kubectl get service api-gateway -n ecommerce-k8s
kubectl get endpoints api-gateway -n ecommerce-k8s
```

## 💾 存储相关问题

### PVC无法绑定

#### 症状
- PVC状态为 `Pending`
- Pod无法挂载存储卷

#### 诊断命令
```bash
# 检查PVC状态
kubectl get pvc -n ecommerce-k8s

# 查看PVC详细信息
kubectl describe pvc postgres-pvc -n ecommerce-k8s

# 检查存储类
kubectl get storageclass
```

#### 解决方案
```bash
# 1. 存储类不存在
# 创建默认存储类（Minikube）
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 2. 存储容量不足
# 检查节点存储空间
kubectl describe nodes | grep -A5 "Allocated resources"

# 3. 访问模式不支持
# 修改PVC访问模式
kubectl patch pvc postgres-pvc -n ecommerce-k8s -p '{"spec":{"accessModes":["ReadWriteOnce"]}}'
```

### 数据持久化问题

#### 症状
- 数据库数据丢失
- 文件上传失败

#### 诊断方法
```bash
# 检查挂载点
kubectl exec -it deployment/postgres -n ecommerce-k8s -- df -h

# 检查文件权限
kubectl exec -it deployment/postgres -n ecommerce-k8s -- ls -la /var/lib/postgresql/data

# 测试写入权限
kubectl exec -it deployment/postgres -n ecommerce-k8s -- touch /var/lib/postgresql/data/test.txt
```

## 🗄️ 数据库相关问题

### PostgreSQL连接失败

#### 症状
- 微服务无法连接数据库
- 数据库操作超时

#### 诊断命令
```bash
# 检查PostgreSQL状态
kubectl get pods -l app=postgres -n ecommerce-k8s

# 测试数据库连接
kubectl exec -it deployment/postgres -n ecommerce-k8s -- psql -U postgres -c "SELECT version();"

# 检查数据库配置
kubectl describe configmap app-config -n ecommerce-k8s | grep database
```

#### 解决方案
```bash
# 1. 数据库未就绪
# 等待数据库启动完成
kubectl wait --for=condition=ready pod -l app=postgres -n ecommerce-k8s --timeout=300s

# 2. 连接配置错误
# 检查连接字符串
kubectl get configmap app-config -n ecommerce-k8s -o yaml | grep database_url

# 3. 密码错误
# 检查数据库密码
kubectl get secret postgres-secret -n ecommerce-k8s -o yaml

# 重置数据库密码
kubectl delete pod -l app=postgres -n ecommerce-k8s
```

### Redis连接问题

#### 症状
- 缓存功能不可用
- 会话数据丢失

#### 诊断方法
```bash
# 检查Redis状态
kubectl get pods -l app=redis -n ecommerce-k8s

# 测试Redis连接
kubectl exec -it deployment/redis -n ecommerce-k8s -- redis-cli -a redis123 ping

# 检查Redis配置
kubectl describe configmap app-config -n ecommerce-k8s | grep redis
```

## 📊 性能相关问题

### 应用响应慢

#### 症状
- API响应时间长
- 页面加载缓慢

#### 诊断方法
```bash
# 检查资源使用情况
kubectl top pods -n ecommerce-k8s
kubectl top nodes

# 运行性能测试
./tests/load-tests.sh -c 10 -n 100

# 检查HPA状态
kubectl get hpa -n ecommerce-k8s
```

#### 优化方案
```bash
# 1. 增加副本数
kubectl scale deployment user-service --replicas=5 -n ecommerce-k8s

# 2. 调整资源限制
kubectl patch deployment user-service -n ecommerce-k8s -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","resources":{"requests":{"memory":"256Mi","cpu":"200m"},"limits":{"memory":"512Mi","cpu":"500m"}}}]}}}}'

# 3. 启用HPA
kubectl autoscale deployment user-service --cpu-percent=70 --min=2 --max=10 -n ecommerce-k8s
```

### 内存泄漏

#### 症状
- Pod内存使用持续增长
- 频繁出现OOMKilled

#### 诊断方法
```bash
# 监控内存使用
kubectl top pods -n ecommerce-k8s --sort-by=memory

# 查看Pod资源限制
kubectl describe pod <pod-name> -n ecommerce-k8s | grep -A10 "Limits\|Requests"

# 分析应用日志
kubectl logs -f deployment/user-service -n ecommerce-k8s | grep -i "memory\|oom"
```

## 🔧 调试工具和技巧

### 创建调试环境

```bash
# 创建调试Pod
kubectl run debug --image=busybox --rm -it --restart=Never -n ecommerce-k8s -- sh

# 网络调试工具
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -n ecommerce-k8s -- bash

# 进入现有Pod调试
kubectl exec -it deployment/user-service -n ecommerce-k8s -- /bin/bash
```

### 端口转发调试

```bash
# 转发数据库端口
kubectl port-forward service/postgres 5432:5432 -n ecommerce-k8s

# 转发Redis端口
kubectl port-forward service/redis 6379:6379 -n ecommerce-k8s

# 转发应用端口
kubectl port-forward deployment/user-service 5001:5001 -n ecommerce-k8s
```

### 日志分析

```bash
# 实时查看日志
kubectl logs -f deployment/user-service -n ecommerce-k8s

# 查看多个服务日志
kubectl logs -f -l tier=backend -n ecommerce-k8s --max-log-requests=10

# 导出日志到文件
kubectl logs deployment/user-service -n ecommerce-k8s > user-service.log

# 使用日志脚本
./scripts/logs.sh user
./scripts/logs.sh -f all
```

## 🚨 紧急恢复程序

### 服务完全不可用

```bash
# 1. 快速重启所有服务
kubectl rollout restart deployment -l tier=backend -n ecommerce-k8s

# 2. 检查基础设施
kubectl get pods -l tier=infrastructure -n ecommerce-k8s

# 3. 重新部署（最后手段）
kubectl delete namespace ecommerce-k8s
./scripts/deploy.sh
```

### 数据恢复

```bash
# 1. 检查数据备份
kubectl get pvc -n ecommerce-k8s

# 2. 从备份恢复（如果有）
kubectl exec -it deployment/postgres -n ecommerce-k8s -- pg_restore -U postgres -d ecommerce /backup/dump.sql

# 3. 重新初始化数据库
kubectl delete pod -l app=postgres -n ecommerce-k8s
```

## 📞 获取帮助

### 收集诊断信息

```bash
# 生成诊断报告
./scripts/health-check.sh > diagnosis-report.txt

# 收集所有日志
./scripts/logs.sh export all

# 导出配置信息
kubectl get all,configmaps,secrets,pvc -n ecommerce-k8s -o yaml > cluster-state.yaml
```

### 联系支持

当遇到无法解决的问题时：

1. **收集完整的错误信息**
2. **提供诊断报告和日志**
3. **描述问题复现步骤**
4. **说明环境配置信息**

---

## 📚 参考资源

- [Kubernetes故障排查官方指南](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [kubectl调试命令参考](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [容器运行时故障排查](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-running-pod/)

**记住：系统化的排查方法比随机尝试更有效！🔍**
