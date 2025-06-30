#!/bin/bash

# =============================================================================
# CI/CD 流水线监控脚本
# 用于监控和验证 GitHub Actions 工作流的运行状态
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
REPO_OWNER="gitwyy"
REPO_NAME="cloud-native-learning"
WORKFLOW_NAME="sample-app-ci-cd.yml"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                    CI/CD 流水线监控工具${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# 检查必要的工具
check_dependencies() {
    echo -e "${YELLOW}检查依赖工具...${NC}"
    
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI (gh) 未安装${NC}"
        echo "请安装 GitHub CLI: https://cli.github.com/"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq 未安装${NC}"
        echo "请安装 jq: brew install jq (macOS) 或 apt-get install jq (Ubuntu)"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 依赖工具检查完成${NC}"
}

# 获取最新的工作流运行状态
get_latest_workflow_run() {
    echo -e "${YELLOW}获取最新的工作流运行状态...${NC}"
    
    # 获取最新的工作流运行
    local run_data=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/workflows/$WORKFLOW_NAME/runs \
        --jq '.workflow_runs[0] | {id: .id, status: .status, conclusion: .conclusion, created_at: .created_at, html_url: .html_url}')
    
    if [ -z "$run_data" ]; then
        echo -e "${RED}❌ 无法获取工作流运行数据${NC}"
        return 1
    fi
    
    echo "$run_data"
}

# 显示工作流运行详情
show_workflow_details() {
    local run_data="$1"
    
    local run_id=$(echo "$run_data" | jq -r '.id')
    local status=$(echo "$run_data" | jq -r '.status')
    local conclusion=$(echo "$run_data" | jq -r '.conclusion')
    local created_at=$(echo "$run_data" | jq -r '.created_at')
    local html_url=$(echo "$run_data" | jq -r '.html_url')
    
    echo -e "${BLUE}工作流运行详情:${NC}"
    echo "  运行ID: $run_id"
    echo "  状态: $status"
    echo "  结论: $conclusion"
    echo "  创建时间: $created_at"
    echo "  查看链接: $html_url"
    echo
    
    # 根据状态显示不同颜色
    case "$conclusion" in
        "success")
            echo -e "${GREEN}✅ 工作流运行成功！${NC}"
            ;;
        "failure")
            echo -e "${RED}❌ 工作流运行失败${NC}"
            ;;
        "cancelled")
            echo -e "${YELLOW}⚠️  工作流被取消${NC}"
            ;;
        "null")
            if [ "$status" = "in_progress" ]; then
                echo -e "${YELLOW}🔄 工作流正在运行中...${NC}"
            else
                echo -e "${YELLOW}⏳ 工作流状态: $status${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}❓ 未知状态: $conclusion${NC}"
            ;;
    esac
}

# 获取工作流作业详情
get_job_details() {
    local run_id="$1"
    
    echo -e "${YELLOW}获取作业详情...${NC}"
    
    local jobs=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id/jobs \
        --jq '.jobs[] | {name: .name, status: .status, conclusion: .conclusion, started_at: .started_at, completed_at: .completed_at}')
    
    echo -e "${BLUE}作业状态:${NC}"
    echo "$jobs" | jq -r '. | "  \(.name): \(.status) (\(.conclusion // "进行中"))"'
}

# 主函数
main() {
    echo -e "${GREEN}开始监控 CI/CD 流水线...${NC}"
    echo
    
    check_dependencies
    echo
    
    # 检查 GitHub CLI 认证状态
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI 未认证${NC}"
        echo "请运行: gh auth login"
        exit 1
    fi
    
    local run_data=$(get_latest_workflow_run)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    show_workflow_details "$run_data"
    echo
    
    local run_id=$(echo "$run_data" | jq -r '.id')
    get_job_details "$run_id"
    echo
    
    # 提供有用的命令
    echo -e "${BLUE}有用的命令:${NC}"
    echo "  查看工作流日志: gh run view $run_id --log"
    echo "  重新运行工作流: gh run rerun $run_id"
    echo "  查看所有运行: gh run list --workflow=$WORKFLOW_NAME"
    echo "  实时监控: watch -n 10 '$0'"
}

# 运行主函数
main "$@"
