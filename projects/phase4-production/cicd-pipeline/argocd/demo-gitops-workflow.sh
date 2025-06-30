#!/bin/bash

# ArgoCD GitOps工作流演示脚本
# 演示完整的GitOps部署流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 打印函数
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_title() {
    echo
    print_message $BLUE "=================================="
    print_message $BLUE "$1"
    print_message $BLUE "=================================="
    echo
}

print_step() {
    print_message $PURPLE "🔄 $1"
}

print_success() {
    print_message $GREEN "✅ $1"
}

print_warning() {
    print_message $YELLOW "⚠️  $1"
}

print_error() {
    print_message $RED "❌ $1"
}

# 等待用户确认
wait_for_user() {
    local message=${1:-"按Enter键继续..."}
    print_message $YELLOW "$message"
    read -r
}

# 检查前置条件
check_prerequisites() {
    print_title "检查前置条件"
    
    # 检查kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装"
        exit 1
    fi
    print_success "kubectl 已安装"
    
    # 检查ArgoCD CLI
    if ! command -v argocd &> /dev/null; then
        print_warning "ArgoCD CLI 未安装，某些功能可能不可用"
    else
        print_success "ArgoCD CLI 已安装"
    fi
    
    # 检查ArgoCD是否运行
    if ! kubectl get namespace argocd &> /dev/null; then
        print_error "ArgoCD 未安装，请先运行 install-argocd.sh"
        exit 1
    fi
    print_success "ArgoCD 已安装"
    
    # 检查ArgoCD Pod状态
    if ! kubectl get pods -n argocd | grep -q "Running"; then
        print_error "ArgoCD Pod 未正常运行"
        exit 1
    fi
    print_success "ArgoCD 运行正常"
}

# 显示当前状态
show_current_status() {
    print_title "当前状态概览"
    
    print_step "ArgoCD Pod状态:"
    kubectl get pods -n argocd
    echo
    
    print_step "ArgoCD应用状态:"
    kubectl get applications -n argocd 2>/dev/null || print_warning "暂无应用"
    echo
    
    print_step "目标命名空间状态:"
    kubectl get namespaces | grep -E "(staging|production)" || print_warning "暂无目标命名空间"
    echo
}

# 部署ArgoCD项目和应用
deploy_argocd_resources() {
    print_title "部署ArgoCD项目和应用"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 部署项目
    print_step "部署ArgoCD项目..."
    if [[ -f "$script_dir/projects/sample-app-project.yaml" ]]; then
        kubectl apply -f "$script_dir/projects/sample-app-project.yaml"
        print_success "项目部署完成"
    else
        print_error "项目配置文件不存在: $script_dir/projects/sample-app-project.yaml"
        exit 1
    fi
    
    wait_for_user "项目已部署，按Enter键继续部署应用..."
    
    # 部署应用
    print_step "部署示例应用..."
    if [[ -f "$script_dir/applications/sample-app-staging.yaml" ]]; then
        kubectl apply -f "$script_dir/applications/sample-app-staging.yaml"
        print_success "应用部署完成"
    else
        print_error "应用配置文件不存在: $script_dir/applications/sample-app-staging.yaml"
        exit 1
    fi
    
    # 等待应用创建
    print_step "等待应用创建..."
    sleep 5
    
    # 显示应用状态
    print_step "应用状态:"
    kubectl get applications -n argocd
}

# 演示同步过程
demonstrate_sync() {
    print_title "演示GitOps同步过程"
    
    print_step "当前应用状态:"
    kubectl describe application sample-app-staging -n argocd | grep -A 5 "Status:"
    echo
    
    wait_for_user "观察应用状态，按Enter键继续..."
    
    # 检查是否需要同步
    local sync_status=$(kubectl get application sample-app-staging -n argocd -o jsonpath='{.status.sync.status}')
    print_step "同步状态: $sync_status"
    
    if [[ "$sync_status" == "OutOfSync" ]]; then
        print_step "应用需要同步，开始同步..."
        
        if command -v argocd &> /dev/null; then
            # 使用ArgoCD CLI同步
            print_step "使用ArgoCD CLI同步应用..."
            argocd app sync sample-app-staging --grpc-web
        else
            # 使用kubectl同步
            print_step "使用kubectl同步应用..."
            kubectl patch application sample-app-staging -n argocd --type='merge' -p='{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
        fi
    else
        print_success "应用已同步"
    fi
    
    # 监控同步进度
    print_step "监控同步进度..."
    for i in {1..30}; do
        local health=$(kubectl get application sample-app-staging -n argocd -o jsonpath='{.status.health.status}')
        local sync=$(kubectl get application sample-app-staging -n argocd -o jsonpath='{.status.sync.status}')
        
        print_message $BLUE "第${i}次检查 - 健康状态: $health, 同步状态: $sync"
        
        if [[ "$health" == "Healthy" && "$sync" == "Synced" ]]; then
            print_success "应用同步完成且健康"
            break
        fi
        
        sleep 10
    done
}

# 查看部署结果
show_deployment_results() {
    print_title "查看部署结果"
    
    # 检查命名空间
    print_step "检查staging命名空间:"
    kubectl get namespace staging 2>/dev/null || print_warning "staging命名空间不存在"
    echo
    
    # 检查Pod
    print_step "检查应用Pod:"
    kubectl get pods -n staging 2>/dev/null || print_warning "staging命名空间中无Pod"
    echo
    
    # 检查服务
    print_step "检查应用服务:"
    kubectl get services -n staging 2>/dev/null || print_warning "staging命名空间中无服务"
    echo
    
    # 检查Ingress
    print_step "检查Ingress:"
    kubectl get ingress -n staging 2>/dev/null || print_warning "staging命名空间中无Ingress"
    echo
}

# 演示应用访问
demonstrate_app_access() {
    print_title "演示应用访问"
    
    # 检查服务是否存在
    if ! kubectl get service sample-app-service -n staging &> /dev/null; then
        print_warning "应用服务不存在，跳过访问演示"
        return
    fi
    
    print_step "配置端口转发以访问应用..."
    print_message $YELLOW "在新终端中运行以下命令:"
    print_message $YELLOW "kubectl port-forward svc/sample-app-service -n staging 3000:80"
    print_message $YELLOW "然后访问: http://localhost:3000"
    
    wait_for_user "配置完端口转发后，按Enter键继续..."
    
    # 测试应用健康检查
    print_step "测试应用健康检查..."
    if kubectl exec -n staging deployment/sample-app -- curl -s http://localhost:3000/health &> /dev/null; then
        print_success "应用健康检查通过"
    else
        print_warning "无法访问应用健康检查端点"
    fi
}

# 演示配置更新
demonstrate_config_update() {
    print_title "演示配置更新流程"
    
    print_message $YELLOW "GitOps工作流演示:"
    print_message $YELLOW "1. 修改Git仓库中的Kubernetes配置"
    print_message $YELLOW "2. ArgoCD检测到配置变更"
    print_message $YELLOW "3. ArgoCD自动或手动同步变更"
    print_message $YELLOW "4. 应用更新完成"
    echo
    
    print_message $BLUE "要演示配置更新，您可以:"
    print_message $BLUE "1. 修改 projects/phase4-production/cicd-pipeline/sample-app/k8s/deployment.yaml"
    print_message $BLUE "2. 提交并推送到Git仓库"
    print_message $BLUE "3. 观察ArgoCD检测并同步变更"
    
    wait_for_user "了解配置更新流程后，按Enter键继续..."
}

# 显示有用的命令
show_useful_commands() {
    print_title "有用的ArgoCD命令"
    
    print_message $BLUE "ArgoCD CLI命令:"
    echo "  argocd app list                    # 列出所有应用"
    echo "  argocd app get sample-app-staging  # 查看应用详情"
    echo "  argocd app sync sample-app-staging # 同步应用"
    echo "  argocd app logs sample-app-staging # 查看应用日志"
    echo "  argocd app history sample-app-staging # 查看同步历史"
    echo
    
    print_message $BLUE "kubectl命令:"
    echo "  kubectl get applications -n argocd # 查看ArgoCD应用"
    echo "  kubectl describe application sample-app-staging -n argocd # 应用详情"
    echo "  kubectl get pods -n staging        # 查看应用Pod"
    echo "  kubectl logs -f deployment/sample-app -n staging # 查看应用日志"
    echo
    
    print_message $BLUE "访问ArgoCD Web UI:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  然后访问: https://localhost:8080"
    echo "  用户名: admin"
    echo "  密码: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
}

# 清理资源
cleanup_resources() {
    print_title "清理演示资源"
    
    print_message $YELLOW "确认要清理演示资源吗？这将删除示例应用。"
    read -p "输入 'yes' 确认清理: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_message $BLUE "取消清理"
        return
    fi
    
    print_step "删除ArgoCD应用..."
    kubectl delete application sample-app-staging -n argocd 2>/dev/null || true
    
    print_step "删除应用资源..."
    kubectl delete namespace staging 2>/dev/null || true
    
    print_step "删除ArgoCD项目..."
    kubectl delete appproject sample-app-project -n argocd 2>/dev/null || true
    
    print_success "清理完成"
}

# 显示帮助信息
show_help() {
    echo "ArgoCD GitOps工作流演示脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  --help, -h          显示帮助信息"
    echo "  --cleanup           清理演示资源"
    echo "  --status            只显示当前状态"
    echo
    echo "演示流程:"
    echo "1. 检查前置条件"
    echo "2. 显示当前状态"
    echo "3. 部署ArgoCD项目和应用"
    echo "4. 演示同步过程"
    echo "5. 查看部署结果"
    echo "6. 演示应用访问"
    echo "7. 演示配置更新流程"
    echo "8. 显示有用命令"
}

# 主函数
main() {
    local cleanup=false
    local status_only=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --cleanup)
                cleanup=true
                shift
                ;;
            --status)
                status_only=true
                shift
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 执行清理
    if [[ "$cleanup" == true ]]; then
        cleanup_resources
        exit 0
    fi
    
    # 检查前置条件
    check_prerequisites
    
    # 只显示状态
    if [[ "$status_only" == true ]]; then
        show_current_status
        exit 0
    fi
    
    # 完整演示流程
    print_title "ArgoCD GitOps工作流演示"
    print_message $GREEN "欢迎使用ArgoCD GitOps工作流演示！"
    print_message $BLUE "本演示将展示完整的GitOps部署流程"
    
    wait_for_user "准备开始演示，按Enter键继续..."
    
    show_current_status
    wait_for_user
    
    deploy_argocd_resources
    wait_for_user
    
    demonstrate_sync
    wait_for_user
    
    show_deployment_results
    wait_for_user
    
    demonstrate_app_access
    wait_for_user
    
    demonstrate_config_update
    wait_for_user
    
    show_useful_commands
    
    print_title "演示完成"
    print_message $GREEN "🎉 ArgoCD GitOps工作流演示完成！"
    print_message $BLUE "您现在可以继续探索ArgoCD的其他功能"
    print_message $YELLOW "运行 '$0 --cleanup' 来清理演示资源"
}

# 运行主函数
main "$@"
