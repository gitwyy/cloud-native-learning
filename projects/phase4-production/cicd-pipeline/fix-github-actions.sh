#!/bin/bash

# GitHub Actions 修复脚本
# 用于解决CI/CD流水线中的常见问题

set -e

echo "🔧 GitHub Actions CI/CD 修复脚本"
echo "================================"

# 检查当前目录
if [[ ! -f "package.json" ]]; then
    echo "❌ 错误：请在sample-app目录中运行此脚本"
    exit 1
fi

echo "📋 检查项目状态..."

# 1. 检查依赖
echo "1️⃣ 检查Node.js依赖..."
if npm audit --audit-level=high; then
    echo "✅ 依赖安全检查通过"
else
    echo "⚠️ 发现安全漏洞，尝试修复..."
    npm audit fix --force || echo "⚠️ 部分漏洞无法自动修复"
fi

# 2. 运行测试
echo "2️⃣ 运行测试..."
if npm test; then
    echo "✅ 测试通过"
else
    echo "❌ 测试失败，请检查代码"
    exit 1
fi

# 3. 构建Docker镜像
echo "3️⃣ 测试Docker构建..."
if docker build -t sample-app:test .; then
    echo "✅ Docker镜像构建成功"
else
    echo "❌ Docker镜像构建失败"
    exit 1
fi

# 4. 测试容器运行
echo "4️⃣ 测试容器运行..."
CONTAINER_ID=$(docker run -d -p 3001:3000 sample-app:test)
sleep 3

if curl -f http://localhost:3001/health > /dev/null 2>&1; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器运行异常"
    docker logs $CONTAINER_ID
fi

# 清理测试容器
docker stop $CONTAINER_ID > /dev/null 2>&1
docker rm $CONTAINER_ID > /dev/null 2>&1

# 5. 检查GitHub Actions工作流
echo "5️⃣ 检查GitHub Actions配置..."
if [[ -f "../../.github/workflows/sample-app-ci-cd.yml" ]]; then
    echo "✅ GitHub Actions工作流文件存在"
else
    echo "❌ GitHub Actions工作流文件不存在"
    exit 1
fi

echo ""
echo "🎉 所有检查完成！"
echo ""
echo "📝 下一步操作："
echo "1. 提交代码更改到GitHub"
echo "2. 检查GitHub Actions运行状态"
echo "3. 验证镜像是否成功推送到GHCR"
echo "4. 检查ArgoCD是否能拉取新镜像"
echo ""
echo "🔗 有用的链接："
echo "- GitHub Actions: https://github.com/gitwyy/cloud-native-learning/actions"
echo "- GHCR包: https://github.com/gitwyy/cloud-native-learning/pkgs/container/cloud-native-learning%2Fsample-app"
echo ""
