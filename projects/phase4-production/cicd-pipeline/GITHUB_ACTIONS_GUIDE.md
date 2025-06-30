# 🐙 GitHub Actions CI/CD 实践指南

> 完整的GitHub Actions工作流配置和实践总结

## 🎯 实践目标

通过本次实践，您将掌握：
- GitHub Actions工作流的配置和使用
- 自动化测试、构建、部署流程
- 容器镜像的自动构建和推送
- 安全扫描和代码质量检查
- 多环境部署策略

## ✅ 已完成的配置

### 1. 工作流文件结构
```
.github/workflows/
└── sample-app-ci-cd.yml    # 主要的CI/CD工作流
```

### 2. 工作流阶段
我们的GitHub Actions工作流包含以下阶段：

#### 🧪 测试阶段 (test)
- **多版本测试**: Node.js 18 和 20
- **依赖安装**: 使用npm ci进行快速安装
- **代码检查**: 运行linting（如果可用）
- **单元测试**: 执行所有测试用例
- **覆盖率报告**: 生成并上传代码覆盖率

#### 🔒 安全扫描 (security)
- **依赖审计**: npm audit检查已知漏洞
- **安全扫描**: 检查依赖包的安全问题

#### 🐳 构建推送 (build-and-push)
- **Docker构建**: 多阶段构建优化镜像
- **镜像推送**: 推送到GitHub Container Registry (GHCR)
- **容器扫描**: 使用Trivy扫描容器漏洞
- **安全报告**: 上传扫描结果到GitHub Security

#### 🚀 部署阶段 (deploy)
- **测试环境**: 自动部署到测试环境
- **生产环境**: 手动审批后部署到生产环境

## 📊 工作流特性

### 🎯 触发条件
```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'projects/phase4-production/cicd-pipeline/sample-app/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'projects/phase4-production/cicd-pipeline/sample-app/**'
```

### 🔧 环境变量
```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/sample-app
  NODE_VERSION: '18'
  APP_PATH: projects/phase4-production/cicd-pipeline/sample-app
```

### 🏗️ 构建优化
- **缓存策略**: npm缓存和Docker层缓存
- **并行执行**: 测试矩阵并行运行
- **条件执行**: 只在main分支执行构建和部署

## 🔍 如何查看工作流运行

1. **访问Actions页面**:
   ```
   https://github.com/gitwyy/cloud-native-learning/actions
   ```

2. **查看具体运行**:
   - 点击任意工作流运行
   - 查看各个作业的详细日志
   - 检查测试结果和构建状态

3. **查看构建的镜像**:
   ```
   https://github.com/gitwyy/cloud-native-learning/pkgs/container/sample-app
   ```

## 🛠️ 本地测试工作流

您可以使用act工具在本地测试GitHub Actions：

```bash
# 安装act (macOS)
brew install act

# 运行测试作业
act -j test

# 运行所有作业
act
```

## 📈 监控和优化

### 查看工作流性能
- **运行时间**: 监控各阶段执行时间
- **成功率**: 跟踪构建成功率
- **资源使用**: 优化缓存和并行度

### 常见优化策略
1. **缓存优化**: 合理使用npm和Docker缓存
2. **并行执行**: 利用矩阵策略并行测试
3. **条件执行**: 避免不必要的作业运行
4. **资源限制**: 合理配置超时时间

## 🔧 故障排查

### 常见问题
1. **测试失败**: 检查测试代码和依赖
2. **构建失败**: 验证Dockerfile和构建上下文
3. **推送失败**: 检查GITHUB_TOKEN权限
4. **部署失败**: 验证Kubernetes配置

### 调试技巧
```yaml
# 添加调试步骤
- name: Debug info
  run: |
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "SHA: ${{ github.sha }}"
    ls -la
```

## 🚀 下一步扩展

### 1. 添加更多测试
- 集成测试
- 端到端测试
- 性能测试

### 2. 增强安全性
- 代码签名
- 漏洞扫描
- 合规检查

### 3. 部署策略
- 蓝绿部署
- 金丝雀发布
- 滚动更新

### 4. 监控集成
- 部署通知
- 性能监控
- 错误追踪

## 📚 学习资源

- [GitHub Actions官方文档](https://docs.github.com/en/actions)
- [工作流语法参考](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [安全最佳实践](https://docs.github.com/en/actions/security-guides)

---

**恭喜！** 🎉 您已经成功配置了完整的GitHub Actions CI/CD流水线！

现在可以继续学习其他CI/CD平台或进入安全加固阶段。
