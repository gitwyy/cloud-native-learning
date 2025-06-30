# 🔧 GitHub Actions & ArgoCD 故障排除指南

## 🎯 常见问题及解决方案

### 1. GitHub Actions 构建失败

#### 问题症状
- GitHub Actions工作流显示红色❌
- 镜像构建失败
- 测试不通过

#### 解决步骤

**检查工作流触发条件**
```bash
# 确保修改了正确的文件路径
git status
git add projects/phase4-production/cicd-pipeline/sample-app/
git commit -m "fix: update sample app"
git push origin main
```

**检查权限设置**
1. 进入GitHub仓库设置
2. Settings → Actions → General
3. 确保"Workflow permissions"设置为"Read and write permissions"
4. 勾选"Allow GitHub Actions to create and approve pull requests"

**检查GHCR权限**
1. Settings → Developer settings → Personal access tokens
2. 创建新token，权限包括：
   - `write:packages`
   - `read:packages`
   - `delete:packages`

### 2. 镜像推送失败

#### 问题症状
- Docker login失败
- 推送到GHCR失败
- 权限被拒绝

#### 解决步骤

**检查镜像名称格式**
```yaml
# 正确格式
REGISTRY: ghcr.io
IMAGE_NAME: ${{ github.repository }}/sample-app
# 结果: ghcr.io/gitwyy/cloud-native-learning/sample-app
```

**手动测试推送**
```bash
# 本地测试
echo $GITHUB_TOKEN | docker login ghcr.io -u gitwyy --password-stdin
docker tag sample-app:test ghcr.io/gitwyy/cloud-native-learning/sample-app:test
docker push ghcr.io/gitwyy/cloud-native-learning/sample-app:test
```

### 3. ArgoCD 拉取镜像失败

#### 问题症状
- ArgoCD应用显示"ImagePullBackOff"
- Pod无法启动
- 镜像拉取超时

#### 解决步骤

**检查镜像可见性**
1. 进入GitHub包页面
2. 确保包设置为Public或配置了正确的访问权限

**检查镜像标签**
```bash
# 验证镜像是否存在
docker pull ghcr.io/gitwyy/cloud-native-learning/sample-app:latest
```

**更新ArgoCD应用**
```bash
# 强制同步
kubectl patch app sample-app-staging -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

### 4. 测试失败

#### 问题症状
- Jest测试超时
- 测试覆盖率不足
- 依赖安装失败

#### 解决步骤

**修复测试超时**
```javascript
// 在测试文件中添加
afterAll(async () => {
  await new Promise(resolve => setTimeout(() => resolve(), 500));
});
```

**检查依赖**
```bash
cd projects/phase4-production/cicd-pipeline/sample-app
npm ci
npm test
```

## 🚀 快速修复命令

### 重新触发GitHub Actions
```bash
# 创建空提交触发构建
git commit --allow-empty -m "trigger: rebuild CI/CD pipeline"
git push origin main
```

### 清理Docker缓存
```bash
docker system prune -f
docker builder prune -f
```

### 重启ArgoCD同步
```bash
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## 📊 监控和验证

### 检查GitHub Actions状态
```bash
# 使用GitHub CLI
gh run list --limit 5
gh run view --log
```

### 检查镜像状态
```bash
# 列出所有标签
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/user/packages/container/cloud-native-learning%2Fsample-app/versions
```

### 检查ArgoCD状态
```bash
kubectl get applications -n argocd
kubectl describe application sample-app-staging -n argocd
```

## 🔗 有用的链接

- [GitHub Actions文档](https://docs.github.com/en/actions)
- [GHCR文档](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [ArgoCD文档](https://argo-cd.readthedocs.io/)
- [Docker最佳实践](https://docs.docker.com/develop/dev-best-practices/)
