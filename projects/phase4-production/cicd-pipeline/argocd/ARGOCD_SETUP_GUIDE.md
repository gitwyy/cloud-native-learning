# 🚀 ArgoCD 安装和配置指南

> 完整的ArgoCD GitOps平台安装、配置和使用指南

## 🎯 学习目标

通过本指南，您将掌握：
- ArgoCD的核心概念和架构
- 在Kubernetes集群中安装ArgoCD
- 配置ArgoCD项目和应用
- 实现完整的GitOps工作流
- ArgoCD的安全配置和最佳实践

## 📚 ArgoCD 核心概念

### 什么是ArgoCD？
ArgoCD是一个声明式的GitOps持续部署工具，专为Kubernetes设计。它遵循GitOps模式，将Git仓库作为应用配置和部署状态的唯一真实来源。

### 核心组件
- **Application Controller**: 监控应用状态并执行同步
- **Repository Server**: 管理Git仓库连接和配置获取
- **API Server**: 提供gRPC/REST API和Web UI
- **Dex**: 身份认证和RBAC管理

### 关键概念
- **Application**: ArgoCD中的部署单元，定义了源代码仓库和目标集群
- **Project**: 应用的逻辑分组，提供多租户和RBAC功能
- **Sync**: 将Git仓库中的配置应用到Kubernetes集群的过程
- **Health**: 应用在Kubernetes中的运行状态
- **Sync Status**: Git仓库配置与集群实际状态的比较结果

## 🛠️ 安装ArgoCD

### 方法一：使用官方YAML清单（推荐用于学习）

```bash
# 创建ArgoCD命名空间
kubectl create namespace argocd

# 安装ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待所有Pod启动
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### 方法二：使用Helm Chart

```bash
# 添加ArgoCD Helm仓库
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 安装ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer
```

### 验证安装

```bash
# 检查Pod状态
kubectl get pods -n argocd

# 检查服务状态
kubectl get svc -n argocd

# 查看ArgoCD版本
kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## 🔐 访问ArgoCD

### 获取初始密码

```bash
# 获取admin用户的初始密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 配置访问方式

#### 方法一：端口转发（开发环境）
```bash
# 转发ArgoCD服务端口
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 访问 https://localhost:8080
# 用户名: admin
# 密码: 使用上面获取的密码
```

#### 方法二：LoadBalancer（生产环境）
```bash
# 修改服务类型为LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 获取外部IP
kubectl get svc argocd-server -n argocd
```

#### 方法三：Ingress（推荐）
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  rules:
  - host: argocd.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
```

## 📋 配置ArgoCD项目和应用

### 1. 创建ArgoCD项目

我们已经准备了项目配置文件：

```bash
# 应用项目配置
kubectl apply -f projects/phase4-production/cicd-pipeline/argocd/projects/sample-app-project.yaml
```

### 2. 创建ArgoCD应用

```bash
# 应用staging环境配置
kubectl apply -f projects/phase4-production/cicd-pipeline/argocd/applications/sample-app-staging.yaml
```

### 3. 验证配置

```bash
# 查看项目
kubectl get appproject -n argocd

# 查看应用
kubectl get application -n argocd

# 查看应用详情
kubectl describe application sample-app-staging -n argocd
```

## 🔄 GitOps工作流演示

### 1. 初始部署

1. **推送代码到Git仓库**
   ```bash
   git add .
   git commit -m "feat: update sample app configuration"
   git push origin main
   ```

2. **ArgoCD自动检测变更**
   - ArgoCD每3分钟检查一次Git仓库
   - 检测到配置变更后，显示"OutOfSync"状态

3. **同步应用**
   ```bash
   # 手动同步（或等待自动同步）
   argocd app sync sample-app-staging
   ```

### 2. 监控部署状态

```bash
# 使用kubectl监控
kubectl get pods -n staging -w

# 使用ArgoCD CLI
argocd app get sample-app-staging

# 查看同步历史
argocd app history sample-app-staging
```

## 🎛️ ArgoCD CLI工具

### 安装ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Windows
choco install argocd-cli
```

### 登录ArgoCD

```bash
# 登录ArgoCD服务器
argocd login localhost:8080

# 或使用外部地址
argocd login argocd.local
```

### 常用CLI命令

```bash
# 列出所有应用
argocd app list

# 查看应用详情
argocd app get sample-app-staging

# 同步应用
argocd app sync sample-app-staging

# 查看应用日志
argocd app logs sample-app-staging

# 删除应用
argocd app delete sample-app-staging
```

## 🔧 故障排查

### 常见问题

1. **应用无法同步**
   ```bash
   # 检查仓库连接
   argocd repo list
   
   # 检查应用状态
   argocd app get sample-app-staging
   
   # 查看详细错误
   kubectl describe application sample-app-staging -n argocd
   ```

2. **权限问题**
   ```bash
   # 检查RBAC配置
   kubectl get clusterrole argocd-server
   
   # 检查服务账户
   kubectl get sa -n argocd
   ```

3. **网络连接问题**
   ```bash
   # 测试Git仓库连接
   kubectl exec -it deployment/argocd-repo-server -n argocd -- git ls-remote https://github.com/gitwyy/cloud-native-learning.git
   ```

### 调试技巧

```bash
# 查看ArgoCD服务器日志
kubectl logs deployment/argocd-server -n argocd

# 查看应用控制器日志
kubectl logs deployment/argocd-application-controller -n argocd

# 查看仓库服务器日志
kubectl logs deployment/argocd-repo-server -n argocd
```

## 📈 监控和可观测性

### 内置监控

ArgoCD提供了丰富的监控指标：

```bash
# 查看Prometheus指标
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082
curl http://localhost:8082/metrics
```

### 集成外部监控

```yaml
# Grafana Dashboard配置示例
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-dashboard
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "ArgoCD Dashboard",
        "panels": [
          {
            "title": "Application Sync Status",
            "type": "stat",
            "targets": [
              {
                "expr": "argocd_app_info"
              }
            ]
          }
        ]
      }
    }
```

## 🎯 实践练习

### 练习1: 快速安装ArgoCD

使用我们提供的安装脚本：

```bash
# 运行安装脚本
./install-argocd.sh

# 或者跳过CLI安装
./install-argocd.sh --skip-cli

# 查看帮助
./install-argocd.sh --help
```

### 练习2: 体验GitOps工作流

使用演示脚本体验完整的GitOps流程：

```bash
# 运行GitOps演示
./demo-gitops-workflow.sh

# 只查看当前状态
./demo-gitops-workflow.sh --status

# 清理演示资源
./demo-gitops-workflow.sh --cleanup
```

### 练习3: 手动配置应用

1. **创建自定义应用配置**
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-app
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/your-username/your-repo
       targetRevision: HEAD
       path: k8s
     destination:
       server: https://kubernetes.default.svc
       namespace: my-namespace
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

2. **应用配置**
   ```bash
   kubectl apply -f my-app.yaml
   ```

3. **监控同步状态**
   ```bash
   argocd app get my-app
   argocd app sync my-app
   ```

### 练习4: 多环境管理

创建开发、测试、生产三个环境的应用配置，体验多环境部署策略。

## 🔧 故障排查指南

### 常见问题解决方案

1. **应用一直处于Progressing状态**
   ```bash
   # 检查应用事件
   kubectl describe application <app-name> -n argocd

   # 检查目标资源状态
   kubectl get pods -n <target-namespace>

   # 强制刷新应用
   argocd app get <app-name> --refresh
   ```

2. **Git仓库连接失败**
   ```bash
   # 测试仓库连接
   argocd repo add https://github.com/your-repo.git

   # 检查仓库状态
   argocd repo list
   ```

3. **权限问题**
   ```bash
   # 检查服务账户权限
   kubectl auth can-i create deployments --as=system:serviceaccount:argocd:argocd-application-controller

   # 检查RBAC配置
   kubectl get clusterrolebinding | grep argocd
   ```

## 🚀 下一步

完成ArgoCD配置后，您可以：

1. **集成CI/CD流水线**: 将GitHub Actions与ArgoCD结合
2. **多环境管理**: 配置开发、测试、生产环境
3. **高级功能**: 探索蓝绿部署、金丝雀发布
4. **安全加固**: 配置RBAC、网络策略、镜像扫描

## 📚 学习资源

- [ArgoCD官方文档](https://argo-cd.readthedocs.io/)
- [GitOps最佳实践](https://www.gitops.tech/)
- [Kubernetes部署策略](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

**恭喜！** 🎉 您已经成功配置了ArgoCD GitOps平台！

现在可以体验完整的GitOps工作流，实现声明式的应用部署和管理。
