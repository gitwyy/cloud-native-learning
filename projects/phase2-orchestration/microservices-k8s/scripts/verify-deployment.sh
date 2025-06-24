#!/bin/bash

# ==============================================================================
# 微服务部署验证脚本
# 验证整个微服务平台的部署状态和功能
# ==============================================================================

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="ecommerce-k8s"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 验证统计
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

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

log_header() {
    echo
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

# 验证结果记录
record_check() {
    local status=$1
    local check_name=$2
    local details=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "PASS")
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            echo -e "${GREEN}✓ PASS${NC} $check_name"
            ;;
        "FAIL")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            echo -e "${RED}✗ FAIL${NC} $check_name"
            ;;
        "WARN")
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo -e "${YELLOW}⚠ WARN${NC} $check_name"
            ;;
    esac
    
    if [ -n "$details" ]; then
        echo "       $details"
    fi
}

# 检查kubectl连接
check_kubectl_connection() {
    log_header "检查Kubernetes连接"
    
    if ! command -v kubectl &> /dev/null; then
        record_check "FAIL" "kubectl工具检查" "kubectl未安装"
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        record_check "FAIL" "集群连接检查" "无法连接到Kubernetes集群"
        return 1
    fi
    
    record_check "PASS" "kubectl工具检查" "kubectl已安装且可用"
    record_check "PASS" "集群连接检查" "成功连接到Kubernetes集群"
    
    # 检查命名空间
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        record_check "PASS" "命名空间检查" "命名空间 $NAMESPACE 存在"
    else
        record_check "FAIL" "命名空间检查" "命名空间 $NAMESPACE 不存在"
        return 1
    fi
    
    return 0
}

# 检查基础设施组件
check_infrastructure() {
    log_header "检查基础设施组件"
    
    local infrastructure_components=("postgres" "redis" "rabbitmq")
    
    for component in "${infrastructure_components[@]}"; do
        local pod_status=$(kubectl get pods -l app="$component" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        local ready_status=$(kubectl get pods -l app="$component" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' | head -1)
        
        if [ "$pod_status" = "Running" ] && [[ "$ready_status" =~ ^[0-9]+/[0-9]+$ ]]; then
            local ready_count=$(echo "$ready_status" | cut -d'/' -f1)
            local total_count=$(echo "$ready_status" | cut -d'/' -f2)
            
            if [ "$ready_count" -eq "$total_count" ]; then
                record_check "PASS" "$component 组件检查" "Pod运行正常 ($ready_status)"
            else
                record_check "WARN" "$component 组件检查" "Pod未完全就绪 ($ready_status)"
            fi
        else
            record_check "FAIL" "$component 组件检查" "Pod状态异常: $pod_status"
        fi
        
        # 检查服务
        if kubectl get service "$component" -n "$NAMESPACE" &> /dev/null; then
            record_check "PASS" "$component 服务检查" "Service已创建"
        else
            record_check "FAIL" "$component 服务检查" "Service不存在"
        fi
    done
}

# 检查微服务组件
check_microservices() {
    log_header "检查微服务组件"
    
    local microservices=("user-service" "product-service" "order-service" "notification-service" "api-gateway")
    
    for service in "${microservices[@]}"; do
        local pod_status=$(kubectl get pods -l app="$service" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        local ready_status=$(kubectl get pods -l app="$service" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' | head -1)
        
        if [ "$pod_status" = "Running" ] && [[ "$ready_status" =~ ^[0-9]+/[0-9]+$ ]]; then
            local ready_count=$(echo "$ready_status" | cut -d'/' -f1)
            local total_count=$(echo "$ready_status" | cut -d'/' -f2)
            
            if [ "$ready_count" -eq "$total_count" ]; then
                record_check "PASS" "$service 检查" "Pod运行正常 ($ready_status)"
            else
                record_check "WARN" "$service 检查" "Pod未完全就绪 ($ready_status)"
            fi
        else
            record_check "FAIL" "$service 检查" "Pod状态异常: $pod_status"
        fi
        
        # 检查服务
        if kubectl get service "$service" -n "$NAMESPACE" &> /dev/null; then
            record_check "PASS" "$service 服务检查" "Service已创建"
        else
            record_check "FAIL" "$service 服务检查" "Service不存在"
        fi
    done
}

# 检查存储组件
check_storage() {
    log_header "检查存储组件"
    
    # 检查PVC状态
    local pvc_list=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pvc_list" ]; then
        record_check "WARN" "PVC检查" "没有找到PVC"
        return 0
    fi
    
    local total_pvcs=0
    local bound_pvcs=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local pvc_name=$(echo "$line" | awk '{print $1}')
            local pvc_status=$(echo "$line" | awk '{print $2}')
            
            total_pvcs=$((total_pvcs + 1))
            
            if [ "$pvc_status" = "Bound" ]; then
                bound_pvcs=$((bound_pvcs + 1))
                record_check "PASS" "PVC $pvc_name" "状态: $pvc_status"
            else
                record_check "FAIL" "PVC $pvc_name" "状态: $pvc_status"
            fi
        fi
    done <<< "$pvc_list"
    
    if [ $bound_pvcs -eq $total_pvcs ]; then
        record_check "PASS" "存储总体检查" "所有PVC ($total_pvcs) 都已绑定"
    else
        record_check "FAIL" "存储总体检查" "$((total_pvcs - bound_pvcs)) 个PVC未绑定"
    fi
}

# 检查网络连通性
check_network_connectivity() {
    log_header "检查网络连通性"
    
    # 获取API网关Pod
    local gateway_pod=$(kubectl get pods -l app=api-gateway -n "$NAMESPACE" --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -z "$gateway_pod" ]; then
        record_check "FAIL" "网络连通性检查" "找不到API网关Pod"
        return 1
    fi
    
    # 测试服务间连通性
    local services=("postgres" "redis" "rabbitmq" "user-service" "product-service" "order-service" "notification-service")
    
    for service in "${services[@]}"; do
        local connectivity_test=$(kubectl exec -n "$NAMESPACE" "$gateway_pod" -- nc -zv "$service" 80 2>&1 || echo "failed")
        
        if echo "$connectivity_test" | grep -q "succeeded\|open"; then
            record_check "PASS" "$service 连通性" "网络连接正常"
        else
            # 对于数据库服务，尝试其默认端口
            if [ "$service" = "postgres" ]; then
                local db_test=$(kubectl exec -n "$NAMESPACE" "$gateway_pod" -- nc -zv "$service" 5432 2>&1 || echo "failed")
                if echo "$db_test" | grep -q "succeeded\|open"; then
                    record_check "PASS" "$service 连通性" "数据库端口连接正常"
                else
                    record_check "FAIL" "$service 连通性" "无法连接到服务"
                fi
            elif [ "$service" = "redis" ]; then
                local redis_test=$(kubectl exec -n "$NAMESPACE" "$gateway_pod" -- nc -zv "$service" 6379 2>&1 || echo "failed")
                if echo "$redis_test" | grep -q "succeeded\|open"; then
                    record_check "PASS" "$service 连通性" "Redis端口连接正常"
                else
                    record_check "FAIL" "$service 连通性" "无法连接到服务"
                fi
            elif [ "$service" = "rabbitmq" ]; then
                local rabbitmq_test=$(kubectl exec -n "$NAMESPACE" "$gateway_pod" -- nc -zv "$service" 5672 2>&1 || echo "failed")
                if echo "$rabbitmq_test" | grep -q "succeeded\|open"; then
                    record_check "PASS" "$service 连通性" "RabbitMQ端口连接正常"
                else
                    record_check "FAIL" "$service 连通性" "无法连接到服务"
                fi
            else
                record_check "FAIL" "$service 连通性" "无法连接到服务"
            fi
        fi
    done
}

# 检查健康端点
check_health_endpoints() {
    log_header "检查健康端点"
    
    # 获取API网关Pod
    local gateway_pod=$(kubectl get pods -l app=api-gateway -n "$NAMESPACE" --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -z "$gateway_pod" ]; then
        record_check "FAIL" "健康端点检查" "找不到API网关Pod"
        return 1
    fi
    
    # 检查API网关健康端点
    local gateway_health=$(kubectl exec -n "$NAMESPACE" "$gateway_pod" -- curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/health" 2>/dev/null || echo "000")
    
    if [ "$gateway_health" = "200" ]; then
        record_check "PASS" "API网关健康检查" "健康端点响应正常"
    else
        record_check "FAIL" "API网关健康检查" "健康端点响应异常 (HTTP $gateway_health)"
    fi
    
    # 检查各微服务健康端点
    local services=("user-service" "product-service" "order-service" "notification-service")
    
    for service in "${services[@]}"; do
        local service_pod=$(kubectl get pods -l app="$service" -n "$NAMESPACE" --no-headers 2>/dev/null | head -1 | awk '{print $1}')
        
        if [ -n "$service_pod" ]; then
            local health_check=$(kubectl exec -n "$NAMESPACE" "$service_pod" -- curl -s -o /dev/null -w "%{http_code}" "http://localhost:5001/health" 2>/dev/null || echo "000")
            
            if [ "$health_check" = "200" ]; then
                record_check "PASS" "$service 健康检查" "健康端点响应正常"
            else
                record_check "WARN" "$service 健康检查" "健康端点响应异常 (HTTP $health_check)"
            fi
        else
            record_check "FAIL" "$service 健康检查" "找不到服务Pod"
        fi
    done
}

# 检查HPA配置
check_hpa() {
    log_header "检查自动扩缩容配置"
    
    local hpa_list=$(kubectl get hpa -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$hpa_list" ]; then
        record_check "WARN" "HPA检查" "没有配置自动扩缩容"
        return 0
    fi
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local hpa_name=$(echo "$line" | awk '{print $1}')
            local targets=$(echo "$line" | awk '{print $4}')
            local min_pods=$(echo "$line" | awk '{print $5}')
            local max_pods=$(echo "$line" | awk '{print $6}')
            
            record_check "PASS" "HPA $hpa_name" "配置正常 (副本: $min_pods-$max_pods, 目标: $targets)"
        fi
    done <<< "$hpa_list"
}

# 运行基础功能测试
run_basic_tests() {
    log_header "运行基础功能测试"
    
    # 检查测试脚本是否存在
    if [ ! -f "$PROJECT_DIR/tests/api-tests.sh" ]; then
        record_check "WARN" "API测试" "测试脚本不存在"
        return 0
    fi
    
    # 运行API测试（简化版）
    log_info "运行API功能测试..."
    
    if "$PROJECT_DIR/tests/api-tests.sh" &> /tmp/api-test-output.log; then
        record_check "PASS" "API功能测试" "所有API测试通过"
    else
        local failed_tests=$(grep -c "FAIL" /tmp/api-test-output.log 2>/dev/null || echo "未知")
        record_check "FAIL" "API功能测试" "发现 $failed_tests 个失败的测试"
    fi
    
    # 清理临时文件
    rm -f /tmp/api-test-output.log
}

# 生成验证报告
generate_verification_report() {
    log_header "生成验证报告"
    
    local report_dir="$PROJECT_DIR/.taskmaster/reports"
    local report_file="$report_dir/deployment-verification-$(date +%Y%m%d-%H%M%S).json"
    
    mkdir -p "$report_dir"
    
    # 计算成功率
    local success_rate=0
    if [ $TOTAL_CHECKS -gt 0 ]; then
        success_rate=$(echo "scale=1; $PASSED_CHECKS * 100 / $TOTAL_CHECKS" | bc -l 2>/dev/null || echo "0")
    fi
    
    # 生成JSON报告
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "verification_summary": {
    "total_checks": $TOTAL_CHECKS,
    "passed": $PASSED_CHECKS,
    "failed": $FAILED_CHECKS,
    "warnings": $WARNING_CHECKS,
    "success_rate": "${success_rate}%"
  },
  "environment": {
    "namespace": "$NAMESPACE",
    "cluster_info": "$(kubectl cluster-info --short 2>/dev/null | head -1 || echo 'Unknown')",
    "node_count": $(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0"),
    "kubectl_version": "$(kubectl version --client --short 2>/dev/null || echo 'Unknown')"
  },
  "deployment_status": "$([ $FAILED_CHECKS -eq 0 ] && echo "healthy" || echo "issues_detected")"
}
EOF
    
    log_success "验证报告已生成: $report_file"
}

# 主函数
main() {
    log_header "微服务部署验证开始"
    
    # 执行各项检查
    check_kubectl_connection || exit 1
    check_infrastructure
    check_microservices
    check_storage
    check_network_connectivity
    check_health_endpoints
    check_hpa
    run_basic_tests
    
    # 生成报告
    generate_verification_report
    
    # 输出验证总结
    log_header "验证总结"
    
    echo -e "${BLUE}验证统计:${NC}"
    echo "  总检查项: $TOTAL_CHECKS"
    echo -e "  通过: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "  失败: ${RED}$FAILED_CHECKS${NC}"
    echo -e "  警告: ${YELLOW}$WARNING_CHECKS${NC}"
    
    if [ $TOTAL_CHECKS -gt 0 ]; then
        local success_rate=$(echo "scale=1; $PASSED_CHECKS * 100 / $TOTAL_CHECKS" | bc -l 2>/dev/null || echo "0")
        echo -e "  成功率: ${CYAN}$success_rate%${NC}"
    fi
    
    echo
    if [ $FAILED_CHECKS -eq 0 ]; then
        log_success "🎉 部署验证通过！系统运行正常"
        echo -e "${GREEN}所有关键组件都已正确部署并运行${NC}"
        
        if [ $WARNING_CHECKS -gt 0 ]; then
            echo -e "${YELLOW}注意: 发现 $WARNING_CHECKS 个警告项目，建议检查${NC}"
        fi
        
        exit 0
    else
        log_error "❌ 部署验证失败！发现 $FAILED_CHECKS 个问题"
        echo -e "${RED}请检查失败的项目并进行修复${NC}"
        echo
        echo -e "${BLUE}建议操作:${NC}"
        echo "1. 查看详细日志: kubectl get events -n $NAMESPACE"
        echo "2. 检查Pod状态: kubectl get pods -n $NAMESPACE"
        echo "3. 查看服务日志: ./scripts/logs.sh <service-name>"
        echo "4. 运行健康检查: ./scripts/health-check.sh"
        echo "5. 参考故障排查文档: TROUBLESHOOTING.md"
        
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
