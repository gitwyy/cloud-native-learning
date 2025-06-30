# 🔄 CI/CD流水线实践

> 构建企业级的持续集成和持续部署流水线，实现GitOps工作流

## 📋 项目目标

- 掌握现代CI/CD工具的使用
- 实现代码到生产的自动化流程
- 学习不同部署策略的应用场景
- 建立完整的GitOps工作流

## 🛠️ 技术栈

- **GitLab CI/CD**: 企业级CI/CD平台
- **GitHub Actions**: 云原生工作流引擎  
- **ArgoCD**: GitOps持续部署工具
- **Docker**: 容器化平台
- **Kubernetes**: 容器编排平台
- **Helm**: K8s包管理器

## 📁 项目结构

```
cicd-pipeline/
├── sample-app/              # 示例应用代码
│   ├── src/                # 应用源码
│   ├── tests/              # 测试代码
│   ├── Dockerfile          # 容器化配置
│   └── k8s/               # K8s部署清单
├── gitlab-ci/              # GitLab CI/CD配置
│   ├── .gitlab-ci.yml     # CI/CD流水线配置
│   ├── scripts/           # 构建脚本
│   └── templates/         # 模板文件
├── github-actions/         # GitHub Actions配置
│   ├── .github/workflows/ # 工作流定义
│   └── scripts/           # 自动化脚本
├── argocd/                # ArgoCD GitOps配置
│   ├── applications/      # 应用定义
│   ├── projects/          # 项目配置
│   └── repositories/      # 仓库配置
└── deployment-strategies/  # 部署策略实践
    ├── blue-green/        # 蓝绿部署
    ├── canary/           # 金丝雀部署
    └── rolling/          # 滚动更新
```

## 🎯 实践步骤

### 第1步：准备示例应用

创建一个简单的Web应用作为CI/CD实践的基础：

```bash
# 创建示例应用目录
mkdir -p sample-app/{src,tests,k8s}

# 创建简单的Node.js应用
cat > sample-app/src/app.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from CI/CD Pipeline!',
    version: process.env.APP_VERSION || '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});
EOF
```

### 第2步：GitLab CI/CD配置

配置GitLab CI/CD流水线：

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy-staging
  - deploy-production

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  IMAGE_NAME: $CI_PROJECT_PATH
  KUBECONFIG_FILE: $KUBECONFIG

# 测试阶段
test:
  stage: test
  image: node:16
  script:
    - cd sample-app
    - npm install
    - npm test
  only:
    - merge_requests
    - main

# 构建阶段
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA
  only:
    - main
```

### 第3步：GitHub Actions配置

设置GitHub Actions工作流：

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '16'
    - name: Install dependencies
      run: |
        cd sample-app
        npm install
    - name: Run tests
      run: |
        cd sample-app
        npm test

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - name: Log in to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    - name: Build and push Docker image
      uses: docker/build-push-action@v3
      with:
        context: ./sample-app
        push: true
        tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
```

### 第4步：ArgoCD GitOps配置

设置ArgoCD应用定义：

```yaml
# argocd/applications/sample-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: sample-app/k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## 🚀 部署策略实践

### 蓝绿部署

```yaml
# deployment-strategies/blue-green/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-app
spec:
  selector:
    app: sample-app
    version: blue  # 切换到green进行部署
  ports:
  - port: 80
    targetPort: 3000
```

### 金丝雀部署

```yaml
# deployment-strategies/canary/istio-virtual-service.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: sample-app
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: sample-app
        subset: canary
  - route:
    - destination:
        host: sample-app
        subset: stable
      weight: 90
    - destination:
        host: sample-app
        subset: canary
      weight: 10
```

## ✅ 验证清单

- [ ] 代码提交触发自动化测试
- [ ] 测试通过后自动构建容器镜像
- [ ] 镜像推送到容器仓库
- [ ] ArgoCD自动同步部署到K8s
- [ ] 健康检查和回滚机制正常
- [ ] 不同部署策略验证成功

## 📝 学习要点

1. **流水线设计**: 理解CI/CD各阶段的职责
2. **安全实践**: 密钥管理和权限控制
3. **部署策略**: 选择合适的部署方式
4. **监控集成**: 集成监控和告警
5. **故障恢复**: 自动回滚和手动干预

---

**下一步**: 完成CI/CD流水线后，继续学习 [`../security-hardening/`](../security-hardening/) 安全加固实践！
