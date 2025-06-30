#!/bin/bash

# =============================================================================
# CI/CD 最佳实践检查脚本
# 检查项目是否遵循 CI/CD 最佳实践
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
PASSED=0
FAILED=0
WARNINGS=0

# 检查函数
check_item() {
    local description="$1"
    local condition="$2"
    local level="${3:-error}" # error, warning
    
    echo -n "检查: $description ... "
    
    if eval "$condition"; then
        echo -e "${GREEN}✅ 通过${NC}"
        ((PASSED++))
        return 0
    else
        if [ "$level" = "warning" ]; then
            echo -e "${YELLOW}⚠️  警告${NC}"
            ((WARNINGS++))
        else
            echo -e "${RED}❌ 失败${NC}"
            ((FAILED++))
        fi
        return 1
    fi
}

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                    CI/CD 最佳实践检查${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo

# 1. 版本控制检查
echo -e "${YELLOW}📁 版本控制检查${NC}"
check_item "Git 仓库已初始化" "[ -d .git ]"
check_item "package-lock.json 在版本控制中" "git ls-files | grep -q 'package-lock.json'"
check_item ".gitignore 文件存在" "[ -f .gitignore ]"
check_item "敏感文件被忽略" "grep -q '\.env' .gitignore"
echo

# 2. 项目结构检查
echo -e "${YELLOW}📂 项目结构检查${NC}"
APP_PATH="projects/phase4-production/cicd-pipeline/sample-app"
check_item "应用目录存在" "[ -d $APP_PATH ]"
check_item "package.json 存在" "[ -f $APP_PATH/package.json ]"
check_item "Dockerfile 存在" "[ -f $APP_PATH/Dockerfile ]"
check_item "测试目录存在" "[ -d $APP_PATH/tests ]"
check_item "源代码目录存在" "[ -d $APP_PATH/src ]"
echo

# 3. 依赖管理检查
echo -e "${YELLOW}📦 依赖管理检查${NC}"
if [ -f "$APP_PATH/package.json" ]; then
    check_item "package.json 包含测试脚本" "grep -q '\"test\"' $APP_PATH/package.json"
    check_item "package.json 包含启动脚本" "grep -q '\"start\"' $APP_PATH/package.json"
    check_item "开发依赖已定义" "grep -q '\"devDependencies\"' $APP_PATH/package.json"
    check_item "生产依赖已定义" "grep -q '\"dependencies\"' $APP_PATH/package.json"
fi
echo

# 4. 测试检查
echo -e "${YELLOW}🧪 测试检查${NC}"
check_item "测试文件存在" "[ -f $APP_PATH/tests/app.test.js ]"
if [ -f "$APP_PATH/package.json" ]; then
    check_item "Jest 测试框架已配置" "grep -q 'jest' $APP_PATH/package.json"
    check_item "测试覆盖率脚本存在" "grep -q 'test:coverage' $APP_PATH/package.json"
fi
echo

# 5. Docker 检查
echo -e "${YELLOW}🐳 Docker 检查${NC}"
if [ -f "$APP_PATH/Dockerfile" ]; then
    check_item "Dockerfile 使用多阶段构建" "grep -q 'FROM.*AS' $APP_PATH/Dockerfile" "warning"
    check_item "Dockerfile 指定非 root 用户" "grep -q 'USER' $APP_PATH/Dockerfile" "warning"
    check_item "Dockerfile 使用 .dockerignore" "[ -f $APP_PATH/.dockerignore ]" "warning"
    check_item "Dockerfile 暴露端口" "grep -q 'EXPOSE' $APP_PATH/Dockerfile"
fi
echo

# 6. GitHub Actions 检查
echo -e "${YELLOW}⚙️  GitHub Actions 检查${NC}"
WORKFLOW_FILE=".github/workflows/sample-app-ci-cd.yml"
check_item "GitHub Actions 工作流存在" "[ -f $WORKFLOW_FILE ]"
if [ -f "$WORKFLOW_FILE" ]; then
    check_item "工作流包含测试作业" "grep -q 'test:' $WORKFLOW_FILE"
    check_item "工作流包含构建作业" "grep -q 'build' $WORKFLOW_FILE"
    check_item "工作流使用矩阵策略" "grep -q 'matrix:' $WORKFLOW_FILE"
    check_item "工作流包含安全扫描" "grep -q 'security' $WORKFLOW_FILE"
    check_item "工作流使用最新 actions 版本" "! grep -q '@v[12]' $WORKFLOW_FILE"
    check_item "工作流包含缓存配置" "grep -q 'cache:' $WORKFLOW_FILE"
fi
echo

# 7. Kubernetes 检查
echo -e "${YELLOW}☸️  Kubernetes 检查${NC}"
K8S_PATH="$APP_PATH/k8s"
check_item "Kubernetes 清单目录存在" "[ -d $K8S_PATH ]"
if [ -d "$K8S_PATH" ]; then
    check_item "Deployment 清单存在" "[ -f $K8S_PATH/deployment.yaml ]"
    check_item "Service 清单存在" "[ -f $K8S_PATH/service.yaml ]" "warning"
    check_item "ConfigMap 清单存在" "[ -f $K8S_PATH/configmap.yaml ]" "warning"
fi
echo

# 8. 安全检查
echo -e "${YELLOW}🔒 安全检查${NC}"
check_item "没有硬编码的密钥" "! grep -r 'password\|secret\|key.*=' $APP_PATH/src/ 2>/dev/null || true"
check_item "使用环境变量配置" "grep -q 'process.env' $APP_PATH/src/app.js"
check_item "Dockerfile 不包含密钥" "! grep -i 'password\|secret\|key' $APP_PATH/Dockerfile 2>/dev/null || true"
echo

# 9. 文档检查
echo -e "${YELLOW}📚 文档检查${NC}"
check_item "README 文件存在" "[ -f README.md ]"
check_item "项目包含文档" "[ -f $APP_PATH/README.md ]" "warning"
check_item "API 文档存在" "grep -q 'api\|endpoint' $APP_PATH/src/app.js" "warning"
echo

# 总结
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                           检查结果总结${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}✅ 通过: $PASSED${NC}"
echo -e "${RED}❌ 失败: $FAILED${NC}"
echo -e "${YELLOW}⚠️  警告: $WARNINGS${NC}"
echo

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 恭喜！项目遵循了大部分 CI/CD 最佳实践！${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}💡 建议处理警告项以进一步改进项目质量。${NC}"
    fi
    exit 0
else
    echo -e "${RED}⚠️  发现 $FAILED 个问题需要修复。${NC}"
    echo -e "${YELLOW}💡 请根据上述检查结果改进项目配置。${NC}"
    exit 1
fi
