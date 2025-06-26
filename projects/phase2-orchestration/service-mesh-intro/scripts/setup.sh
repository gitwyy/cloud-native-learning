#!/bin/bash

# 服务网格环境设置脚本
# 一键部署完整的服务网格学习环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISTIO_VERSION=${ISTIO_VERSION:-"1.20.0"}
DEPLOY_APPS=${DEPLOY_APPS:-"true"}
DEPLOY_ADDONS=${DEPLOY_ADDONS:-"true"}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查 kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装"
        exit 1
    fi
    
    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到 Kubernetes 集群"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# 安装 Istio
install_istio() {
    log_info "安装 Istio..."
    
    cd "$PROJECT_ROOT"
    chmod +x istio/install.sh
    ./istio/install.sh
    
    log_success "Istio 安装完成"
}

# 部署示例应用
deploy_apps() {
    if [ "$DEPLOY_APPS" != "true" ]; then
        log_info "跳过应用部署"
        return
    fi
    
    log_info "部署示例应用..."
    
    # 部署 Bookinfo
    log_info "部署 Bookinfo 应用..."
    kubectl apply -f "$PROJECT_ROOT/apps/bookinfo/bookinfo.yaml"
    kubectl apply -f "$PROJECT_ROOT/apps/bookinfo/gateway.yaml"
    
    # 部署 HTTPBin
    log_info "部署 HTTPBin 服务..."
    kubectl apply -f "$PROJECT_ROOT/apps/httpbin/httpbin.yaml"
    
    # 部署 Sleep
    log_info "部署 Sleep 客户端..."
    kubectl apply -f "$PROJECT_ROOT/apps/sleep/sleep.yaml"
    
    # 等待应用启动
    log_info "等待应用启动..."
    kubectl wait --for=condition=available --timeout=300s deployment/productpage-v1
    kubectl wait --for=condition=available --timeout=300s deployment/details-v1
    kubectl wait --for=condition=available --timeout=300s deployment/reviews-v1
    kubectl wait --for=condition=available --timeout=300s deployment/reviews-v2
    kubectl wait --for=condition=available --timeout=300s deployment/reviews-v3
    kubectl wait --for=condition=available --timeout=300s deployment/ratings-v1
    kubectl wait --for=condition=available --timeout=300s deployment/httpbin
    kubectl wait --for=condition=available --timeout=300s deployment/sleep
    
    log_success "示例应用部署完成"
}

# 配置基础流量管理
setup_traffic_management() {
    log_info "配置基础流量管理..."
    
    # 应用所有流量到 v1 的规则
    kubectl apply -f "$PROJECT_ROOT/manifests/traffic-management/virtual-service-all-v1.yaml"
    
    log_success "基础流量管理配置完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查 Pod 状态
    log_info "检查 Pod 状态..."
    kubectl get pods
    
    # 检查服务状态
    log_info "检查服务状态..."
    kubectl get services
    
    # 检查 Istio 配置
    log_info "检查 Istio 配置..."
    kubectl get virtualservices
    kubectl get destinationrules
    kubectl get gateways
    
    # 获取访问地址
    INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    
    echo ""
    echo "=========================================="
    echo "部署验证完成！"
    echo "=========================================="
    echo "Bookinfo 应用访问地址:"
    echo "  http://$INGRESS_HOST:$INGRESS_PORT/productpage"
    echo ""
    echo "测试命令:"
    echo "  # 测试 Bookinfo 应用"
    echo "  curl -s http://$INGRESS_HOST:$INGRESS_PORT/productpage | grep -o '<title>.*</title>'"
    echo ""
    echo "  # 从 sleep pod 测试 httpbin"
    echo "  kubectl exec -it \$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl httpbin:8000/ip"
    echo ""
    echo "访问监控面板:"
    echo "  istioctl dashboard grafana"
    echo "  istioctl dashboard kiali"
    echo "  istioctl dashboard jaeger"
    echo "=========================================="
}

# 显示下一步指导
show_next_steps() {
    echo ""
    echo "🎉 服务网格环境设置完成！"
    echo ""
    echo "📚 下一步学习建议："
    echo "1. 阅读学习指南: cat docs/LEARNING_GUIDE.md"
    echo "2. 尝试流量管理练习: ls exercises/basic/"
    echo "3. 配置安全策略: kubectl apply -f manifests/security/"
    echo "4. 查看可观测性功能: kubectl apply -f manifests/observability/"
    echo ""
    echo "🔧 常用命令："
    echo "  # 查看代理状态"
    echo "  istioctl proxy-status"
    echo ""
    echo "  # 分析配置"
    echo "  istioctl analyze"
    echo ""
    echo "  # 查看代理配置"
    echo "  istioctl proxy-config cluster \$POD_NAME"
    echo ""
    echo "  # 生成测试流量"
    echo "  ./scripts/test.sh"
    echo ""
}

# 主函数
main() {
    echo "=========================================="
    echo "服务网格环境设置脚本"
    echo "=========================================="
    
    check_prerequisites
    install_istio
    deploy_apps
    setup_traffic_management
    verify_deployment
    show_next_steps
}

# 显示帮助信息
show_help() {
    echo "服务网格环境设置脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --no-apps        跳过示例应用部署"
    echo "  --no-addons      跳过插件安装"
    echo "  -h, --help       显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  ISTIO_VERSION    Istio 版本 (默认: 1.20.0)"
    echo "  DEPLOY_APPS      是否部署应用 (默认: true)"
    echo "  DEPLOY_ADDONS    是否部署插件 (默认: true)"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-apps)
            DEPLOY_APPS="false"
            shift
            ;;
        --no-addons)
            DEPLOY_ADDONS="false"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 执行主函数
main
