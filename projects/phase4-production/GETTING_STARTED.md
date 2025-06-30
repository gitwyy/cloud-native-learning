# 🚀 第四阶段实践指南

> 欢迎来到云原生学习的最后阶段！这里您将学习生产级的CI/CD流水线、安全加固和综合项目实战。

## 📋 开始前的准备

### 环境要求
- ✅ Kubernetes集群（本地或云端）
- ✅ Docker环境
- ✅ Git仓库（GitHub/GitLab）
- ✅ kubectl命令行工具
- ✅ 前三阶段的学习基础

### 工具安装
```bash
# 安装ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# 安装Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 安装Trivy（安全扫描）
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

## 🎯 第一周学习计划：CI/CD流水线

### Day 1-2: 理解CI/CD基础概念

**学习目标**：
- 理解持续集成和持续部署的概念
- 掌握GitOps工作流原理
- 了解不同CI/CD工具的特点

**实践任务**：
1. 阅读CI/CD流水线项目文档
2. 分析示例应用的结构
3. 理解Dockerfile和K8s部署清单

### Day 3-4: GitLab CI/CD实践

**学习目标**：
- 配置GitLab CI/CD流水线
- 实现自动化测试和构建
- 掌握环境变量和密钥管理

**实践任务**：
1. 创建GitLab项目并推送代码
2. 配置`.gitlab-ci.yml`文件
3. 设置CI/CD变量和密钥
4. 运行流水线并观察结果

**关键配置**：
```bash
# 设置GitLab CI/CD变量
CI_REGISTRY_USER: your-username
CI_REGISTRY_PASSWORD: your-token
KUBECONFIG: base64-encoded-kubeconfig
```

### Day 5-6: GitHub Actions实践

**学习目标**：
- 配置GitHub Actions工作流
- 实现多环境部署策略
- 集成安全扫描工具

**实践任务**：
1. 创建GitHub仓库并配置Actions
2. 设置工作流文件
3. 配置Secrets和环境保护规则
4. 测试自动化部署流程

**关键配置**：
```bash
# GitHub Secrets设置
KUBECONFIG: base64-encoded-kubeconfig
SNYK_TOKEN: your-snyk-token
```

### Day 7: ArgoCD GitOps部署

**学习目标**：
- 安装和配置ArgoCD
- 创建GitOps应用定义
- 实现声明式部署管理

**实践任务**：
1. 在K8s集群中安装ArgoCD
2. 配置应用项目和权限
3. 创建应用定义并同步
4. 体验GitOps工作流

**安装ArgoCD**：
```bash
# 创建命名空间
kubectl create namespace argocd

# 安装ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 获取初始密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 端口转发访问UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## 🔧 实践步骤详解

### 步骤1：准备示例应用

```bash
# 进入项目目录
cd projects/phase4-production/cicd-pipeline/sample-app

# 安装依赖
npm install

# 运行测试
npm test

# 本地运行应用
npm start
```

### 步骤2：构建和测试容器

```bash
# 构建Docker镜像
docker build -t sample-app:local .

# 运行容器
docker run -p 3000:3000 sample-app:local

# 测试应用
curl http://localhost:3000/health
```

### 步骤3：部署到Kubernetes

```bash
# 应用K8s清单
kubectl apply -f k8s/deployment.yaml

# 检查部署状态
kubectl get pods
kubectl get services

# 测试服务
kubectl port-forward svc/sample-app-service 8080:80
curl http://localhost:8080
```

## 📊 学习成果验证

### 技能检查清单
- [ ] 能够独立配置CI/CD流水线
- [ ] 理解GitOps工作流原理
- [ ] 掌握多环境部署策略
- [ ] 能够集成安全扫描工具
- [ ] 熟悉ArgoCD的使用

### 实践验证
- [ ] 代码提交自动触发流水线
- [ ] 测试失败时阻止部署
- [ ] 镜像自动构建和推送
- [ ] 多环境自动化部署
- [ ] GitOps同步正常工作

## 🚨 常见问题解决

### 问题1：流水线权限错误
**解决方案**：检查CI/CD变量配置，确保KUBECONFIG正确编码

### 问题2：镜像推送失败
**解决方案**：验证容器仓库认证信息，检查网络连接

### 问题3：ArgoCD同步失败
**解决方案**：检查仓库权限，验证应用配置语法

## 📚 扩展学习资源

- [GitLab CI/CD官方文档](https://docs.gitlab.com/ee/ci/)
- [GitHub Actions文档](https://docs.github.com/en/actions)
- [ArgoCD官方指南](https://argo-cd.readthedocs.io/)
- [云原生CI/CD最佳实践](https://www.cncf.io/blog/2020/02/12/ci-cd-with-kubernetes/)

---

**准备好了吗？** 让我们开始第四阶段的学习之旅！🌟

下一步：完成CI/CD流水线实践后，继续学习[安全加固实践](./security-hardening/README.md)。
