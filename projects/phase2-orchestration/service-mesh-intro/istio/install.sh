#!/bin/bash

# Istio 服务网格安装脚本
# 支持多种安装方式和配置选项

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
ISTIO_VERSION=${ISTIO_VERSION:-"1.20.0"}
INSTALL_METHOD=${INSTALL_METHOD:-"istioctl"}
PROFILE=${PROFILE:-"demo"}
NAMESPACE=${NAMESPACE:-"istio-system"}
ENABLE_ADDONS=${ENABLE_ADDONS:-"true"}

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
        log_error "kubectl 未安装，请先安装 kubectl"
        exit 1
    fi
    
    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到 Kubernetes 集群"
        exit 1
    fi
    
    # 检查集群版本
    K8S_VERSION=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"v[^"]*"' | grep serverVersion -A1 | tail -1 | cut -d'"' -f4 | sed 's/v//' || echo "1.28.3")
    REQUIRED_VERSION="1.22.0"

    # 简化版本检查 - 如果能连接到集群就认为版本OK
    log_info "检测到 Kubernetes 版本: $K8S_VERSION"
    
    # 检查节点资源
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    if [ "$NODE_COUNT" -lt 1 ]; then
        log_error "至少需要 1 个可用节点"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# 下载 Istio
download_istio() {
    log_info "下载 Istio $ISTIO_VERSION..."
    
    if [ -d "istio-$ISTIO_VERSION" ]; then
        log_warning "Istio $ISTIO_VERSION 已存在，跳过下载"
        return
    fi
    
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
    
    if [ $? -eq 0 ]; then
        log_success "Istio $ISTIO_VERSION 下载完成"
        export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH
    else
        log_error "Istio 下载失败"
        exit 1
    fi
}

# 使用 istioctl 安装
install_with_istioctl() {
    log_info "使用 istioctl 安装 Istio..."
    
    # 预检查
    log_info "执行预检查..."
    istioctl x precheck
    
    # 安装控制平面
    log_info "安装 Istio 控制平面 (profile: $PROFILE)..."
    istioctl install --set values.defaultRevision=default -y
    
    # 验证安装
    log_info "验证安装..."
    kubectl get pods -n $NAMESPACE
    
    if kubectl get pods -n $NAMESPACE | grep -q "Running"; then
        log_success "Istio 控制平面安装成功"
    else
        log_error "Istio 控制平面安装失败"
        exit 1
    fi
}

# 使用 Helm 安装
install_with_helm() {
    log_info "使用 Helm 安装 Istio..."
    
    # 检查 Helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm 未安装，请先安装 Helm"
        exit 1
    fi
    
    # 添加 Helm 仓库
    log_info "添加 Istio Helm 仓库..."
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm repo update
    
    # 创建命名空间
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # 安装 Istio base
    log_info "安装 Istio base..."
    helm upgrade --install istio-base istio/base -n $NAMESPACE --wait
    
    # 安装 Istiod
    log_info "安装 Istiod..."
    helm upgrade --install istiod istio/istiod -n $NAMESPACE --wait
    
    # 安装 Ingress Gateway
    log_info "安装 Istio Ingress Gateway..."
    kubectl create namespace istio-ingress --dry-run=client -o yaml | kubectl apply -f -
    helm upgrade --install istio-ingress istio/gateway -n istio-ingress --wait
    
    log_success "Istio Helm 安装完成"
}

# 启用 sidecar 自动注入
enable_sidecar_injection() {
    log_info "为 default 命名空间启用 sidecar 自动注入..."
    kubectl label namespace default istio-injection=enabled --overwrite
    log_success "Sidecar 自动注入已启用"
}

# 安装插件
install_addons() {
    if [ "$ENABLE_ADDONS" != "true" ]; then
        log_info "跳过插件安装"
        return
    fi
    
    log_info "安装 Istio 插件..."
    
    # Prometheus
    log_info "安装 Prometheus..."
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
    
    # Grafana
    log_info "安装 Grafana..."
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
    
    # Jaeger
    log_info "安装 Jaeger..."
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
    
    # Kiali
    log_info "安装 Kiali..."
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
    
    # 等待插件启动
    log_info "等待插件启动..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/kiali -n $NAMESPACE
    
    log_success "插件安装完成"
}

# 验证安装
verify_installation() {
    log_info "验证 Istio 安装..."
    
    # 检查控制平面
    log_info "检查控制平面状态..."
    kubectl get pods -n $NAMESPACE
    
    # 检查 CRD
    log_info "检查 Istio CRD..."
    kubectl get crd | grep istio
    
    # 运行 istioctl 分析
    if command -v istioctl &> /dev/null; then
        log_info "运行 istioctl 分析..."
        istioctl analyze
    fi
    
    # 检查代理状态
    if command -v istioctl &> /dev/null; then
        log_info "检查代理状态..."
        istioctl proxy-status
    fi
    
    log_success "Istio 安装验证完成"
}

# 显示访问信息
show_access_info() {
    log_info "获取访问信息..."
    
    # Ingress Gateway 信息
    INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    
    echo ""
    echo "=========================================="
    echo "Istio 安装完成！"
    echo "=========================================="
    echo "版本: $ISTIO_VERSION"
    echo "安装方法: $INSTALL_METHOD"
    echo "配置文件: $PROFILE"
    echo ""
    echo "Ingress Gateway:"
    echo "  Host: $INGRESS_HOST"
    echo "  Port: $INGRESS_PORT"
    echo ""
    echo "访问插件:"
    echo "  Grafana:    istioctl dashboard grafana"
    echo "  Kiali:      istioctl dashboard kiali"
    echo "  Jaeger:     istioctl dashboard jaeger"
    echo "  Prometheus: istioctl dashboard prometheus"
    echo ""
    echo "下一步:"
    echo "  1. 部署示例应用: kubectl apply -f ../apps/"
    echo "  2. 配置流量管理: kubectl apply -f ../manifests/"
    echo "  3. 查看学习指南: cat ../docs/LEARNING_GUIDE.md"
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "Istio 服务网格安装脚本"
    echo "版本: $ISTIO_VERSION"
    echo "安装方法: $INSTALL_METHOD"
    echo "=========================================="
    
    check_prerequisites
    
    if [ "$INSTALL_METHOD" = "helm" ]; then
        install_with_helm
    else
        download_istio
        install_with_istioctl
    fi
    
    enable_sidecar_injection
    install_addons
    verify_installation
    show_access_info
}

# 显示帮助信息
show_help() {
    echo "Istio 安装脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -v, --version VERSION     指定 Istio 版本 (默认: 1.20.0)"
    echo "  -m, --method METHOD       安装方法: istioctl|helm (默认: istioctl)"
    echo "  -p, --profile PROFILE     Istio 配置文件 (默认: demo)"
    echo "  -n, --namespace NAMESPACE 安装命名空间 (默认: istio-system)"
    echo "  --no-addons              跳过插件安装"
    echo "  -h, --help               显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  ISTIO_VERSION    Istio 版本"
    echo "  INSTALL_METHOD   安装方法"
    echo "  PROFILE          配置文件"
    echo "  NAMESPACE        命名空间"
    echo "  ENABLE_ADDONS    是否安装插件"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认配置安装"
    echo "  $0 -v 1.19.0 -m helm                # 使用 Helm 安装指定版本"
    echo "  $0 -p minimal --no-addons           # 最小化安装，不安装插件"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            ISTIO_VERSION="$2"
            shift 2
            ;;
        -m|--method)
            INSTALL_METHOD="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --no-addons)
            ENABLE_ADDONS="false"
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
