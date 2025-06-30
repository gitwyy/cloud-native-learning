#!/bin/bash

# ArgoCD 快速安装脚本
# 用于在Kubernetes集群中快速安装和配置ArgoCD

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_success() {
    print_message $GREEN "✅ $1"
}

print_warning() {
    print_message $YELLOW "⚠️  $1"
}

print_error() {
    print_message $RED "❌ $1"
}

# 检查依赖
check_dependencies() {
    print_title "检查依赖项"
    
    # 检查kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装，请先安装kubectl"
        exit 1
    fi
    print_success "kubectl 已安装"
    
    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到Kubernetes集群，请检查kubeconfig配置"
        exit 1
    fi
    print_success "Kubernetes集群连接正常"
    
    # 检查集群版本
    local k8s_version=$(kubectl version --short | grep "Server Version" | cut -d' ' -f3)
    print_success "Kubernetes版本: $k8s_version"
}

# 安装ArgoCD
install_argocd() {
    print_title "安装ArgoCD"
    
    # 创建命名空间
    print_message $BLUE "创建argocd命名空间..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    print_success "命名空间创建完成"
    
    # 安装ArgoCD
    print_message $BLUE "下载并安装ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    print_success "ArgoCD安装完成"
    
    # 等待Pod启动
    print_message $BLUE "等待ArgoCD Pod启动..."
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
    print_success "所有Pod已启动"
}

# 配置访问
setup_access() {
    print_title "配置ArgoCD访问"
    
    # 获取初始密码
    print_message $BLUE "获取admin初始密码..."
    local admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # 配置端口转发
    print_message $BLUE "配置端口转发..."
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    
    print_success "ArgoCD访问配置完成"
    echo
    print_message $GREEN "🎉 ArgoCD安装成功！"
    echo
    print_message $YELLOW "访问信息："
    print_message $YELLOW "用户名: admin"
    print_message $YELLOW "密码: $admin_password"
    echo
    print_message $YELLOW "访问方式："
    print_message $YELLOW "1. 端口转发: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    print_message $YELLOW "   然后访问: https://localhost:8080"
    echo
    print_message $YELLOW "2. 获取LoadBalancer IP:"
    print_message $YELLOW "   kubectl get svc argocd-server -n argocd"
    echo
}

# 安装ArgoCD CLI
install_argocd_cli() {
    print_title "安装ArgoCD CLI"
    
    if command -v argocd &> /dev/null; then
        print_warning "ArgoCD CLI已安装，跳过安装"
        return
    fi
    
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case $arch in
        x86_64) arch="amd64" ;;
        arm64) arch="arm64" ;;
        *) print_error "不支持的架构: $arch"; exit 1 ;;
    esac
    
    local download_url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-${os}-${arch}"
    
    print_message $BLUE "下载ArgoCD CLI..."
    if command -v curl &> /dev/null; then
        curl -sSL -o /tmp/argocd "$download_url"
    elif command -v wget &> /dev/null; then
        wget -q -O /tmp/argocd "$download_url"
    else
        print_error "需要curl或wget来下载ArgoCD CLI"
        exit 1
    fi
    
    chmod +x /tmp/argocd
    
    # 尝试移动到系统路径
    if sudo mv /tmp/argocd /usr/local/bin/argocd 2>/dev/null; then
        print_success "ArgoCD CLI安装到 /usr/local/bin/argocd"
    else
        print_warning "无法安装到系统路径，请手动移动 /tmp/argocd 到PATH中的目录"
    fi
}

# 部署示例应用
deploy_sample_app() {
    print_title "部署示例应用"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 检查配置文件是否存在
    if [[ ! -f "$script_dir/projects/sample-app-project.yaml" ]]; then
        print_warning "项目配置文件不存在，跳过示例应用部署"
        return
    fi
    
    print_message $BLUE "部署ArgoCD项目..."
    kubectl apply -f "$script_dir/projects/sample-app-project.yaml"
    print_success "项目部署完成"
    
    if [[ -f "$script_dir/applications/sample-app-staging.yaml" ]]; then
        print_message $BLUE "部署示例应用..."
        kubectl apply -f "$script_dir/applications/sample-app-staging.yaml"
        print_success "示例应用部署完成"
    fi
}

# 验证安装
verify_installation() {
    print_title "验证安装"
    
    # 检查Pod状态
    print_message $BLUE "检查Pod状态..."
    kubectl get pods -n argocd
    
    # 检查服务状态
    print_message $BLUE "检查服务状态..."
    kubectl get svc -n argocd
    
    # 检查应用状态
    if kubectl get application -n argocd &> /dev/null; then
        print_message $BLUE "检查应用状态..."
        kubectl get application -n argocd
    fi
    
    print_success "安装验证完成"
}

# 显示帮助信息
show_help() {
    echo "ArgoCD 快速安装脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  --help, -h          显示帮助信息"
    echo "  --skip-cli          跳过ArgoCD CLI安装"
    echo "  --skip-sample       跳过示例应用部署"
    echo "  --uninstall         卸载ArgoCD"
    echo
    echo "示例:"
    echo "  $0                  完整安装ArgoCD"
    echo "  $0 --skip-cli       安装ArgoCD但跳过CLI"
    echo "  $0 --uninstall      卸载ArgoCD"
}

# 卸载ArgoCD
uninstall_argocd() {
    print_title "卸载ArgoCD"
    
    print_message $YELLOW "确认要卸载ArgoCD吗？这将删除所有ArgoCD资源。"
    read -p "输入 'yes' 确认卸载: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_message $BLUE "取消卸载"
        exit 0
    fi
    
    print_message $BLUE "删除ArgoCD应用..."
    kubectl delete applications --all -n argocd 2>/dev/null || true
    
    print_message $BLUE "删除ArgoCD项目..."
    kubectl delete appprojects --all -n argocd 2>/dev/null || true
    
    print_message $BLUE "删除ArgoCD..."
    kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>/dev/null || true
    
    print_message $BLUE "删除命名空间..."
    kubectl delete namespace argocd 2>/dev/null || true
    
    print_success "ArgoCD卸载完成"
}

# 主函数
main() {
    local skip_cli=false
    local skip_sample=false
    local uninstall=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --skip-cli)
                skip_cli=true
                shift
                ;;
            --skip-sample)
                skip_sample=true
                shift
                ;;
            --uninstall)
                uninstall=true
                shift
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 执行卸载
    if [[ "$uninstall" == true ]]; then
        uninstall_argocd
        exit 0
    fi
    
    # 执行安装
    check_dependencies
    install_argocd
    setup_access
    
    if [[ "$skip_cli" != true ]]; then
        install_argocd_cli
    fi
    
    if [[ "$skip_sample" != true ]]; then
        deploy_sample_app
    fi
    
    verify_installation
    
    print_title "安装完成"
    print_message $GREEN "🎉 ArgoCD安装和配置完成！"
    print_message $BLUE "请查看上面的访问信息来访问ArgoCD Web UI"
    print_message $BLUE "更多信息请参考: ARGOCD_SETUP_GUIDE.md"
}

# 运行主函数
main "$@"
