#!/bin/bash

# 服务网格环境清理脚本
# 完全清理 Istio 和相关资源

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
FORCE_CLEANUP=${FORCE_CLEANUP:-"false"}
KEEP_NAMESPACE=${KEEP_NAMESPACE:-"false"}

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

# 确认清理操作
confirm_cleanup() {
    if [ "$FORCE_CLEANUP" = "true" ]; then
        return 0
    fi
    
    echo "=========================================="
    echo "⚠️  服务网格环境清理确认"
    echo "=========================================="
    echo "此操作将删除以下内容:"
    echo "  • 所有示例应用 (Bookinfo, HTTPBin, Sleep)"
    echo "  • Istio 服务网格组件"
    echo "  • 相关的配置和资源"
    echo ""
    read -p "确认继续清理? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "清理操作已取消"
        exit 0
    fi
}

# 清理示例应用
cleanup_apps() {
    log_info "清理示例应用..."
    
    # 清理 Bookinfo 应用
    if kubectl get deployment productpage-v1 &> /dev/null; then
        log_info "清理 Bookinfo 应用..."
        kubectl delete -f apps/bookinfo/bookinfo.yaml --ignore-not-found=true
        kubectl delete -f apps/bookinfo/gateway.yaml --ignore-not-found=true
    fi
    
    # 清理 HTTPBin
    if kubectl get deployment httpbin &> /dev/null; then
        log_info "清理 HTTPBin 服务..."
        kubectl delete -f apps/httpbin/httpbin.yaml --ignore-not-found=true
    fi
    
    # 清理 Sleep
    if kubectl get deployment sleep &> /dev/null; then
        log_info "清理 Sleep 客户端..."
        kubectl delete -f apps/sleep/sleep.yaml --ignore-not-found=true
    fi
    
    log_success "示例应用清理完成"
}

# 清理流量管理配置
cleanup_traffic_config() {
    log_info "清理流量管理配置..."
    
    # 删除 VirtualService
    kubectl delete virtualservice --all --ignore-not-found=true
    
    # 删除 DestinationRule
    kubectl delete destinationrule --all --ignore-not-found=true
    
    # 删除 Gateway
    kubectl delete gateway --all --ignore-not-found=true
    
    log_success "流量管理配置清理完成"
}

# 清理安全策略
cleanup_security_config() {
    log_info "清理安全策略..."
    
    # 删除 AuthorizationPolicy
    kubectl delete authorizationpolicy --all --ignore-not-found=true
    
    # 删除 PeerAuthentication
    kubectl delete peerauthentication --all --ignore-not-found=true
    
    # 删除 RequestAuthentication
    kubectl delete requestauthentication --all --ignore-not-found=true
    
    log_success "安全策略清理完成"
}

# 清理可观测性配置
cleanup_observability_config() {
    log_info "清理可观测性配置..."
    
    # 删除 Telemetry
    kubectl delete telemetry --all --ignore-not-found=true
    
    # 删除 ServiceMonitor
    kubectl delete servicemonitor --all -n istio-system --ignore-not-found=true
    
    log_success "可观测性配置清理完成"
}

# 清理 Istio 插件
cleanup_addons() {
    log_info "清理 Istio 插件..."
    
    # 清理监控组件
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml --ignore-not-found=true
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml --ignore-not-found=true
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml --ignore-not-found=true
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml --ignore-not-found=true
    
    log_success "Istio 插件清理完成"
}

# 卸载 Istio
uninstall_istio() {
    log_info "卸载 Istio..."
    
    # 使用 istioctl 卸载
    if command -v istioctl &> /dev/null; then
        log_info "使用 istioctl 卸载 Istio..."
        istioctl uninstall --purge -y
    else
        log_warning "istioctl 未找到，手动删除 Istio 资源..."
        
        # 手动删除 Istio 资源
        kubectl delete namespace istio-system --ignore-not-found=true
        kubectl delete namespace istio-ingress --ignore-not-found=true
        
        # 删除 CRD
        kubectl get crd | grep istio | awk '{print $1}' | xargs kubectl delete crd --ignore-not-found=true
        
        # 删除 ClusterRole 和 ClusterRoleBinding
        kubectl delete clusterrole --selector=app=istiod --ignore-not-found=true
        kubectl delete clusterrolebinding --selector=app=istiod --ignore-not-found=true
    fi
    
    log_success "Istio 卸载完成"
}

# 清理命名空间标签
cleanup_namespace_labels() {
    log_info "清理命名空间标签..."
    
    # 移除 istio-injection 标签
    kubectl label namespace default istio-injection- --ignore-not-found=true
    
    log_success "命名空间标签清理完成"
}

# 清理残留资源
cleanup_remaining_resources() {
    log_info "清理残留资源..."
    
    # 删除可能残留的 Pod
    kubectl delete pods --field-selector=status.phase=Failed --ignore-not-found=true
    kubectl delete pods --field-selector=status.phase=Succeeded --ignore-not-found=true
    
    # 清理 PVC（如果有）
    kubectl delete pvc --all --ignore-not-found=true
    
    # 清理 ConfigMap（Istio 相关）
    kubectl delete configmap --selector=app=istio --ignore-not-found=true
    
    # 清理 Secret（Istio 相关）
    kubectl delete secret --selector=istio.io/config=true --ignore-not-found=true
    
    log_success "残留资源清理完成"
}

# 验证清理结果
verify_cleanup() {
    log_info "验证清理结果..."
    
    # 检查 Pod
    REMAINING_PODS=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
    if [ "$REMAINING_PODS" -eq 0 ]; then
        log_success "所有 Pod 已清理"
    else
        log_warning "仍有 $REMAINING_PODS 个 Pod 存在"
        kubectl get pods
    fi
    
    # 检查 Istio CRD
    ISTIO_CRDS=$(kubectl get crd | grep istio | wc -l)
    if [ "$ISTIO_CRDS" -eq 0 ]; then
        log_success "所有 Istio CRD 已清理"
    else
        log_warning "仍有 $ISTIO_CRDS 个 Istio CRD 存在"
        kubectl get crd | grep istio
    fi
    
    # 检查命名空间
    if ! kubectl get namespace istio-system &> /dev/null; then
        log_success "istio-system 命名空间已删除"
    else
        log_warning "istio-system 命名空间仍然存在"
    fi
}

# 显示清理报告
show_cleanup_report() {
    echo ""
    echo "=========================================="
    echo "清理操作完成报告"
    echo "=========================================="
    echo "已清理的内容:"
    echo "  ✓ 示例应用 (Bookinfo, HTTPBin, Sleep)"
    echo "  ✓ 流量管理配置"
    echo "  ✓ 安全策略配置"
    echo "  ✓ 可观测性配置"
    echo "  ✓ Istio 插件"
    echo "  ✓ Istio 服务网格"
    echo "  ✓ 命名空间标签"
    echo "  ✓ 残留资源"
    echo ""
    echo "集群状态:"
    echo "  Pod 数量: $(kubectl get pods --no-headers 2>/dev/null | wc -l)"
    echo "  Service 数量: $(kubectl get svc --no-headers 2>/dev/null | wc -l)"
    echo "  Istio CRD 数量: $(kubectl get crd 2>/dev/null | grep istio | wc -l)"
    echo ""
    echo "如需重新部署，请运行:"
    echo "  ./scripts/setup.sh"
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "服务网格环境清理脚本"
    echo "=========================================="
    
    confirm_cleanup
    
    cleanup_apps
    cleanup_traffic_config
    cleanup_security_config
    cleanup_observability_config
    cleanup_addons
    uninstall_istio
    cleanup_namespace_labels
    cleanup_remaining_resources
    
    verify_cleanup
    show_cleanup_report
}

# 显示帮助信息
show_help() {
    echo "服务网格环境清理脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --force              强制清理，跳过确认"
    echo "  --keep-namespace     保留命名空间"
    echo "  -h, --help           显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  FORCE_CLEANUP        强制清理 (true/false)"
    echo "  KEEP_NAMESPACE       保留命名空间 (true/false)"
    echo ""
    echo "示例:"
    echo "  $0                   # 交互式清理"
    echo "  $0 --force           # 强制清理"
    echo "  $0 --keep-namespace  # 保留命名空间"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_CLEANUP="true"
            shift
            ;;
        --keep-namespace)
            KEEP_NAMESPACE="true"
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
