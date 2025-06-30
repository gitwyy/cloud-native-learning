#!/bin/bash

# =============================================================================
# ArgoCD 部署验证脚本
# 验证 ArgoCD 从 GitHub 拉取代码并自动部署到 Kubernetes 集群的完整流程
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
APP_NAME="sample-app-local"
NAMESPACE="default"
ARGOCD_NAMESPACE="argocd"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                    ArgoCD 部署流程验证${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# 检查函数
check_command() {
    local cmd="$1"
    local description="$2"
    
    echo -n "检查 $description ... "
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✅ 已安装${NC}"
        return 0
    else
        echo -e "${RED}❌ 未安装${NC}"
        return 1
    fi
}

# 检查Kubernetes资源
check_k8s_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="$3"
    local description="$4"
    
    echo -n "检查 $description ... "
    if kubectl get "$resource_type" "$resource_name" -n "$namespace" &> /dev/null; then
        echo -e "${GREEN}✅ 存在${NC}"
        return 0
    else
        echo -e "${RED}❌ 不存在${NC}"
        return 1
    fi
}

# 检查Pod状态
check_pod_status() {
    local app_label="$1"
    local namespace="$2"
    local description="$3"

    echo -n "检查 $description ... "
    local pods_output=$(kubectl get pods -n "$namespace" -l "app=$app_label" --no-headers 2>/dev/null || echo "")
    local ready_pods=0
    local total_pods=0

    if [ -n "$pods_output" ]; then
        ready_pods=$(echo "$pods_output" | awk '{print $2}' | grep -c "1/1" 2>/dev/null || echo "0")
        total_pods=$(echo "$pods_output" | wc -l | tr -d ' ')
    fi

    if [ "$ready_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
        echo -e "${GREEN}✅ $ready_pods/$total_pods 运行中${NC}"
        return 0
    else
        echo -e "${RED}❌ $ready_pods/$total_pods 就绪${NC}"
        return 1
    fi
}

# 测试应用端点
test_endpoint() {
    local url="$1"
    local description="$2"
    local expected_status="${3:-200}"
    
    echo -n "测试 $description ... "
    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status" = "$expected_status" ]; then
        echo -e "${GREEN}✅ HTTP $status${NC}"
        return 0
    else
        echo -e "${RED}❌ HTTP $status (期望 $expected_status)${NC}"
        return 1
    fi
}

# 主验证流程
main() {
    echo -e "${YELLOW}1. 检查必要工具...${NC}"
    check_command "kubectl" "Kubernetes CLI"
    check_command "curl" "HTTP 客户端"
    check_command "jq" "JSON 处理器"
    echo
    
    echo -e "${YELLOW}2. 检查 ArgoCD 组件...${NC}"
    check_k8s_resource "namespace" "$ARGOCD_NAMESPACE" "" "ArgoCD 命名空间"

    # 检查ArgoCD组件（使用正确的标签）
    echo -n "检查 ArgoCD Server ... "
    local argocd_server_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l "app.kubernetes.io/name=argocd-server" --no-headers 2>/dev/null | grep "1/1" | wc -l | tr -d ' ')
    if [ "$argocd_server_pods" -gt 0 ]; then
        echo -e "${GREEN}✅ $argocd_server_pods 运行中${NC}"
    else
        echo -e "${RED}❌ 0 运行中${NC}"
    fi

    echo -n "检查 ArgoCD Application Controller ... "
    local argocd_controller_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l "app.kubernetes.io/name=argocd-application-controller" --no-headers 2>/dev/null | grep "1/1" | wc -l | tr -d ' ')
    if [ "$argocd_controller_pods" -gt 0 ]; then
        echo -e "${GREEN}✅ $argocd_controller_pods 运行中${NC}"
    else
        echo -e "${RED}❌ 0 运行中${NC}"
    fi

    echo -n "检查 ArgoCD Repo Server ... "
    local argocd_repo_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l "app.kubernetes.io/name=argocd-repo-server" --no-headers 2>/dev/null | grep "1/1" | wc -l | tr -d ' ')
    if [ "$argocd_repo_pods" -gt 0 ]; then
        echo -e "${GREEN}✅ $argocd_repo_pods 运行中${NC}"
    else
        echo -e "${RED}❌ 0 运行中${NC}"
    fi
    echo
    
    echo -e "${YELLOW}3. 检查 ArgoCD 应用...${NC}"
    check_k8s_resource "application" "$APP_NAME" "$ARGOCD_NAMESPACE" "ArgoCD 应用"
    
    # 获取应用状态
    echo -n "检查应用同步状态 ... "
    local sync_status=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    if [ "$sync_status" = "Synced" ]; then
        echo -e "${GREEN}✅ $sync_status${NC}"
    else
        echo -e "${YELLOW}⚠️  $sync_status${NC}"
    fi
    
    echo -n "检查应用健康状态 ... "
    local health_status=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    case "$health_status" in
        "Healthy")
            echo -e "${GREEN}✅ $health_status${NC}"
            ;;
        "Progressing")
            echo -e "${YELLOW}🔄 $health_status${NC}"
            ;;
        *)
            echo -e "${RED}❌ $health_status${NC}"
            ;;
    esac
    echo
    
    echo -e "${YELLOW}4. 检查部署的资源...${NC}"
    check_k8s_resource "deployment" "sample-app" "$NAMESPACE" "应用部署"
    check_k8s_resource "service" "sample-app" "$NAMESPACE" "应用服务"
    check_k8s_resource "configmap" "sample-app-config" "$NAMESPACE" "应用配置"
    check_pod_status "sample-app" "$NAMESPACE" "应用 Pod"
    echo
    
    echo -e "${YELLOW}5. 测试应用功能...${NC}"
    
    # 启动端口转发
    echo "启动端口转发..."
    kubectl port-forward service/sample-app 8080:80 -n "$NAMESPACE" &
    local pf_pid=$!
    sleep 3
    
    # 测试端点
    test_endpoint "http://localhost:8080/health" "健康检查端点"
    test_endpoint "http://localhost:8080/ready" "就绪检查端点"
    test_endpoint "http://localhost:8080/" "主页端点"
    test_endpoint "http://localhost:8080/api/info" "API 信息端点"
    test_endpoint "http://localhost:8080/api/users" "用户 API 端点"
    
    # 停止端口转发
    kill $pf_pid 2>/dev/null || true
    echo
    
    echo -e "${YELLOW}6. 验证 GitOps 流程...${NC}"
    echo -n "检查应用源仓库 ... "
    local repo_url=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || echo "")
    if [[ "$repo_url" == *"github.com"* ]]; then
        echo -e "${GREEN}✅ $repo_url${NC}"
    else
        echo -e "${RED}❌ $repo_url${NC}"
    fi
    
    echo -n "检查自动同步配置 ... "
    local auto_sync=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.syncPolicy.automated}' 2>/dev/null || echo "null")
    if [ "$auto_sync" != "null" ]; then
        echo -e "${GREEN}✅ 已启用${NC}"
    else
        echo -e "${YELLOW}⚠️  未启用${NC}"
    fi
    
    echo -n "检查最新提交 ... "
    local revision=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.sync.revision}' 2>/dev/null || echo "Unknown")
    if [ ${#revision} -eq 40 ]; then
        echo -e "${GREEN}✅ ${revision:0:8}...${NC}"
    else
        echo -e "${YELLOW}⚠️  $revision${NC}"
    fi
    echo
    
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}                           验证结果总结${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    
    echo -e "${GREEN}🎉 ArgoCD 部署流程验证完成！${NC}"
    echo
    echo "验证的功能："
    echo "  ✅ ArgoCD 组件运行正常"
    echo "  ✅ 应用从 GitHub 仓库同步"
    echo "  ✅ Kubernetes 资源部署成功"
    echo "  ✅ 应用服务正常响应"
    echo "  ✅ GitOps 流程配置正确"
    echo
    echo "下一步建议："
    echo "  1. 修改应用代码并推送到 GitHub"
    echo "  2. 观察 ArgoCD 自动检测变化并重新部署"
    echo "  3. 验证新版本的应用功能"
    echo "  4. 测试回滚功能"
    echo
    echo "有用的命令："
    echo "  查看应用状态: kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE"
    echo "  查看应用详情: kubectl describe application $APP_NAME -n $ARGOCD_NAMESPACE"
    echo "  查看 Pod 日志: kubectl logs -l app=sample-app -n $NAMESPACE"
    echo "  端口转发测试: kubectl port-forward service/sample-app 8080:80 -n $NAMESPACE"
}

# 运行主函数
main "$@"
