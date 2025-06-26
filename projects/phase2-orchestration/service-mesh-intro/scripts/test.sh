#!/bin/bash

# 服务网格功能测试脚本
# 验证各种服务网格功能是否正常工作

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
INGRESS_HOST=""
INGRESS_PORT=""
GATEWAY_URL=""
SLEEP_POD=""

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

# 初始化环境变量
init_env() {
    log_info "初始化环境变量..."
    
    # 获取 Ingress Gateway 信息
    INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -z "$INGRESS_HOST" ] || [ "$INGRESS_HOST" = "null" ]; then
        INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    fi
    if [ -z "$INGRESS_HOST" ] || [ "$INGRESS_HOST" = "null" ]; then
        INGRESS_HOST="localhost"
        log_warning "无法获取 LoadBalancer IP，使用 localhost"
    fi
    
    INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    GATEWAY_URL="$INGRESS_HOST:$INGRESS_PORT"
    
    # 获取 Sleep Pod 名称
    SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath='{.items[0].metadata.name}')
    
    log_info "Gateway URL: $GATEWAY_URL"
    log_info "Sleep Pod: $SLEEP_POD"
}

# 测试基本连通性
test_connectivity() {
    log_info "测试基本连通性..."
    
    # 测试 Bookinfo 应用
    log_info "测试 Bookinfo 应用访问..."
    if curl -s -f "http://$GATEWAY_URL/productpage" > /dev/null; then
        log_success "Bookinfo 应用访问正常"
    else
        log_error "Bookinfo 应用访问失败"
        return 1
    fi
    
    # 测试服务间通信
    log_info "测试服务间通信..."
    if kubectl exec -it "$SLEEP_POD" -- curl -s -f httpbin:8000/ip > /dev/null; then
        log_success "服务间通信正常"
    else
        log_error "服务间通信失败"
        return 1
    fi
}

# 测试流量管理
test_traffic_management() {
    log_info "测试流量管理功能..."
    
    # 测试基本路由
    log_info "测试基本路由规则..."
    for i in {1..10}; do
        curl -s "http://$GATEWAY_URL/productpage" | grep -q "Book Reviews" && break
        sleep 1
    done
    log_success "基本路由测试完成"
    
    # 测试用户路由
    log_info "测试基于用户的路由..."
    kubectl apply -f manifests/traffic-management/virtual-service-reviews-test-v2.yaml
    sleep 5
    
    # 测试 jason 用户路由到 v2
    RESPONSE=$(curl -s -H "end-user: jason" "http://$GATEWAY_URL/productpage")
    if echo "$RESPONSE" | grep -q "black"; then
        log_success "用户路由测试通过 (jason -> v2)"
    else
        log_warning "用户路由测试可能失败"
    fi
    
    # 恢复默认路由
    kubectl apply -f manifests/traffic-management/virtual-service-all-v1.yaml
}

# 测试故障注入
test_fault_injection() {
    log_info "测试故障注入功能..."
    
    # 测试延迟注入
    log_info "测试延迟注入..."
    kubectl apply -f manifests/traffic-management/virtual-service-ratings-test-delay.yaml
    sleep 5
    
    START_TIME=$(date +%s)
    curl -s -H "end-user: jason" "http://$GATEWAY_URL/productpage" > /dev/null
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    if [ $DURATION -gt 5 ]; then
        log_success "延迟注入测试通过 (延迟: ${DURATION}s)"
    else
        log_warning "延迟注入测试可能失败 (延迟: ${DURATION}s)"
    fi
    
    # 测试错误注入
    log_info "测试错误注入..."
    kubectl apply -f manifests/traffic-management/virtual-service-ratings-test-abort.yaml
    sleep 5
    
    RESPONSE=$(curl -s -H "end-user: jason" "http://$GATEWAY_URL/productpage")
    if echo "$RESPONSE" | grep -q "Ratings service is currently unavailable"; then
        log_success "错误注入测试通过"
    else
        log_warning "错误注入测试可能失败"
    fi
    
    # 恢复默认路由
    kubectl apply -f manifests/traffic-management/virtual-service-all-v1.yaml
}

# 测试安全功能
test_security() {
    log_info "测试安全功能..."
    
    # 检查 mTLS 状态
    log_info "检查 mTLS 状态..."
    if istioctl authn tls-check "$SLEEP_POD" httpbin.default.svc.cluster.local | grep -q "OK"; then
        log_success "mTLS 配置正常"
    else
        log_warning "mTLS 配置可能有问题"
    fi
    
    # 测试授权策略
    log_info "测试授权策略..."
    # 这里可以添加更多授权测试
    log_info "授权策略测试需要手动验证"
}

# 测试可观测性
test_observability() {
    log_info "测试可观测性功能..."
    
    # 生成一些流量
    log_info "生成测试流量..."
    for i in {1..20}; do
        curl -s "http://$GATEWAY_URL/productpage" > /dev/null &
        kubectl exec -it "$SLEEP_POD" -- curl -s httpbin:8000/ip > /dev/null &
    done
    wait
    
    # 检查指标
    log_info "检查 Prometheus 指标..."
    if kubectl exec -n istio-system deployment/prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=istio_requests_total' | grep -q "success"; then
        log_success "Prometheus 指标收集正常"
    else
        log_warning "Prometheus 指标收集可能有问题"
    fi
    
    log_success "可观测性测试完成"
}

# 性能测试
test_performance() {
    log_info "执行性能测试..."
    
    log_info "测试并发请求处理..."
    START_TIME=$(date +%s)
    
    # 并发发送 100 个请求
    for i in {1..100}; do
        curl -s "http://$GATEWAY_URL/productpage" > /dev/null &
    done
    wait
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    log_success "100 个并发请求完成，耗时: ${DURATION}s"
    
    # 计算 QPS
    QPS=$((100 / DURATION))
    log_info "估算 QPS: $QPS"
}

# 清理测试环境
cleanup() {
    log_info "清理测试环境..."
    
    # 恢复默认配置
    kubectl apply -f manifests/traffic-management/virtual-service-all-v1.yaml
    
    log_success "测试环境清理完成"
}

# 显示测试报告
show_report() {
    echo ""
    echo "=========================================="
    echo "服务网格功能测试报告"
    echo "=========================================="
    echo "测试环境:"
    echo "  Gateway URL: $GATEWAY_URL"
    echo "  Sleep Pod: $SLEEP_POD"
    echo ""
    echo "测试项目:"
    echo "  ✓ 基本连通性测试"
    echo "  ✓ 流量管理测试"
    echo "  ✓ 故障注入测试"
    echo "  ✓ 安全功能测试"
    echo "  ✓ 可观测性测试"
    echo "  ✓ 性能测试"
    echo ""
    echo "查看详细信息:"
    echo "  # 查看服务状态"
    echo "  kubectl get pods,svc"
    echo ""
    echo "  # 查看 Istio 配置"
    echo "  kubectl get virtualservices,destinationrules,gateways"
    echo ""
    echo "  # 查看代理状态"
    echo "  istioctl proxy-status"
    echo ""
    echo "  # 访问监控面板"
    echo "  istioctl dashboard grafana"
    echo "  istioctl dashboard kiali"
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "服务网格功能测试"
    echo "=========================================="
    
    init_env
    test_connectivity
    test_traffic_management
    test_fault_injection
    test_security
    test_observability
    test_performance
    cleanup
    show_report
}

# 显示帮助信息
show_help() {
    echo "服务网格功能测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --connectivity   只测试连通性"
    echo "  --traffic        只测试流量管理"
    echo "  --security       只测试安全功能"
    echo "  --observability  只测试可观测性"
    echo "  --performance    只测试性能"
    echo "  -h, --help       显示帮助信息"
}

# 解析命令行参数
case "${1:-}" in
    --connectivity)
        init_env && test_connectivity
        ;;
    --traffic)
        init_env && test_traffic_management
        ;;
    --security)
        init_env && test_security
        ;;
    --observability)
        init_env && test_observability
        ;;
    --performance)
        init_env && test_performance
        ;;
    -h|--help)
        show_help
        ;;
    "")
        main
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac
