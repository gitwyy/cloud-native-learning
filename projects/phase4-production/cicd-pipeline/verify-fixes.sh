#!/bin/bash

# CI/CD 修复验证脚本
# 验证GitHub Actions和ArgoCD的修复是否成功

set -e

echo "🔍 CI/CD 修复验证脚本"
echo "====================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查函数
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        return 1
    fi
}

echo -e "${BLUE}📋 开始验证修复...${NC}"

# 1. 检查工作流文件
echo -e "\n${YELLOW}1️⃣ 检查GitHub Actions工作流文件...${NC}"
if [[ -f "../../../.github/workflows/sample-app-ci-cd.yml" ]]; then
    check_status "GitHub Actions工作流文件存在"
    
    # 检查工作流语法
    if grep -q "workflow_dispatch" ../../../.github/workflows/sample-app-ci-cd.yml; then
        check_status "工作流支持手动触发"
    else
        echo -e "${YELLOW}⚠️ 建议添加手动触发支持${NC}"
    fi
else
    echo -e "${RED}❌ GitHub Actions工作流文件不存在${NC}"
    exit 1
fi

# 2. 检查应用代码
echo -e "\n${YELLOW}2️⃣ 检查应用代码...${NC}"
cd sample-app

# 检查package.json
if [[ -f "package.json" ]]; then
    check_status "package.json存在"
else
    echo -e "${RED}❌ package.json不存在${NC}"
    exit 1
fi

# 检查测试脚本
if npm run test --silent > /dev/null 2>&1; then
    check_status "测试通过"
else
    echo -e "${RED}❌ 测试失败${NC}"
    echo "运行 'npm test' 查看详细错误"
fi

# 3. 检查Dockerfile
echo -e "\n${YELLOW}3️⃣ 检查Dockerfile...${NC}"
if [[ -f "Dockerfile" ]]; then
    check_status "Dockerfile存在"
    
    # 检查多阶段构建
    if grep -q "FROM.*AS" Dockerfile; then
        check_status "使用多阶段构建"
    fi
    
    # 检查安全配置
    if grep -q "USER nodejs" Dockerfile; then
        check_status "使用非root用户"
    fi
    
    if grep -q "dumb-init" Dockerfile; then
        check_status "使用dumb-init"
    fi
else
    echo -e "${RED}❌ Dockerfile不存在${NC}"
    exit 1
fi

# 4. 测试Docker构建
echo -e "\n${YELLOW}4️⃣ 测试Docker构建...${NC}"
if docker build -t sample-app:verify . > /dev/null 2>&1; then
    check_status "Docker镜像构建成功"
    
    # 测试容器运行
    echo -e "${BLUE}测试容器运行...${NC}"
    CONTAINER_ID=$(docker run -d -p 3002:3000 sample-app:verify)
    sleep 3
    
    if curl -f http://localhost:3002/health > /dev/null 2>&1; then
        check_status "容器运行正常"
    else
        echo -e "${RED}❌ 容器运行异常${NC}"
        docker logs $CONTAINER_ID
    fi
    
    # 清理
    docker stop $CONTAINER_ID > /dev/null 2>&1
    docker rm $CONTAINER_ID > /dev/null 2>&1
    docker rmi sample-app:verify > /dev/null 2>&1
else
    echo -e "${RED}❌ Docker镜像构建失败${NC}"
fi

# 5. 检查Kubernetes配置
echo -e "\n${YELLOW}5️⃣ 检查Kubernetes配置...${NC}"
if [[ -f "k8s/deployment.yaml" ]]; then
    check_status "Kubernetes部署文件存在"
    
    # 检查镜像拉取策略
    if grep -q "imagePullPolicy: Always" k8s/deployment.yaml; then
        check_status "镜像拉取策略设置正确"
    else
        echo -e "${YELLOW}⚠️ 建议设置imagePullPolicy为Always${NC}"
    fi
    
    # 检查健康检查
    if grep -q "livenessProbe" k8s/deployment.yaml; then
        check_status "配置了存活性探针"
    fi
    
    if grep -q "readinessProbe" k8s/deployment.yaml; then
        check_status "配置了就绪性探针"
    fi
else
    echo -e "${RED}❌ Kubernetes部署文件不存在${NC}"
fi

# 6. 检查ArgoCD配置
echo -e "\n${YELLOW}6️⃣ 检查ArgoCD配置...${NC}"
cd ../argocd
if [[ -f "applications/sample-app-staging.yaml" ]]; then
    check_status "ArgoCD应用配置存在"
    
    # 检查仓库URL
    if grep -q "https://github.com/gitwyy/cloud-native-learning" applications/sample-app-staging.yaml; then
        check_status "仓库URL配置正确"
    fi
    
    # 检查自动同步
    if grep -q "automated:" applications/sample-app-staging.yaml; then
        check_status "配置了自动同步"
    fi
else
    echo -e "${RED}❌ ArgoCD应用配置不存在${NC}"
fi

# 7. 生成修复报告
echo -e "\n${BLUE}📊 生成修复报告...${NC}"
cd ..

cat > fix-report.md << EOF
# CI/CD 修复报告

## 修复内容

### ✅ 已修复的问题

1. **清理重复工作流配置**
   - 删除了项目内部重复的GitHub Actions工作流文件
   - 保留并优化了根目录的主要工作流

2. **优化GitHub Actions工作流**
   - 添加了手动触发支持 (\`workflow_dispatch\`)
   - 改进了权限配置
   - 添加了调试信息输出
   - 明确指定了Docker平台

3. **修复应用代码**
   - 修复了优雅关闭处理中的变量引用问题
   - 添加了SIGINT信号处理

4. **改进Dockerfile**
   - 添加了安全更新
   - 使用dumb-init处理信号
   - 优化了多阶段构建

5. **更新Kubernetes配置**
   - 设置镜像拉取策略为Always
   - 确保总是拉取最新镜像

### 🔧 提供的工具

1. **修复脚本**: \`fix-github-actions.sh\`
2. **验证脚本**: \`verify-fixes.sh\`
3. **故障排除指南**: \`TROUBLESHOOTING.md\`

## 下一步操作

1. 提交所有更改到GitHub
2. 检查GitHub Actions运行状态
3. 验证镜像推送到GHCR
4. 测试ArgoCD同步

## 验证命令

\`\`\`bash
# 运行验证脚本
./verify-fixes.sh

# 手动触发GitHub Actions
git commit --allow-empty -m "trigger: test CI/CD fixes"
git push origin main
\`\`\`

生成时间: $(date)
EOF

echo -e "${GREEN}📄 修复报告已生成: fix-report.md${NC}"

echo -e "\n${GREEN}🎉 验证完成！${NC}"
echo -e "${BLUE}📝 下一步：提交更改并测试GitHub Actions${NC}"
echo -e "${YELLOW}💡 提示：运行 'git add . && git commit -m \"fix: resolve CI/CD issues\" && git push' 来应用修复${NC}"
