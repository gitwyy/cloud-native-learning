#!/bin/bash

# ==============================================================================
# 微服务健康检查脚本
# 检查所有微服务和基础设施组件的健康状态
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

# 检查kubectl连接
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl未安装"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "命名空间 $NAMESPACE 不存在"
        exit 1
    fi
    
    log_success "kubectl连接正常"
}

# 检查Pod状态
check_pods() {
    log_header "Pod健康检查"
    
    local total_pods=0
    local running_pods=0
    local failed_pods=0
    
    # 获取所有Pod状态
    local pods_info=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pods_info" ]; then
        log_warning "命名空间中没有Pod"
        return 1
    fi
    
    echo -e "${BLUE}Pod状态详情:${NC}"
    printf "%-30s %-15s %-10s %-15s\n" "NAME" "STATUS" "RESTARTS" "AGE"
    echo "--------------------------------------------------------------------------------"
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local name=$(echo "$line" | awk '{print $1}')
            local ready=$(echo "$line" | awk '{print $2}')
            local status=$(echo "$line" | awk '{print $3}')
            local restarts=$(echo "$line" | awk '{print $4}')
            local age=$(echo "$line" | awk '{print $5}')
            
            total_pods=$((total_pods + 1))
            
            if [[ "$status" == "Running" && "$ready" =~ ^[0-9]+/[0-9]+$ ]]; then
                local ready_count=$(echo "$ready" | cut -d'/' -f1)
                local total_count=$(echo "$ready" | cut -d'/' -f2)
                
                if [ "$ready_count" -eq "$total_count" ]; then
                    running_pods=$((running_pods + 1))
                    printf "%-30s ${GREEN}%-15s${NC} %-10s %-15s\n" "$name" "$status" "$restarts" "$age"
                else
                    failed_pods=$((failed_pods + 1))
                    printf "%-30s ${YELLOW}%-15s${NC} %-10s %-15s\n" "$name" "$status" "$restarts" "$age"
                fi
            else
                failed_pods=$((failed_pods + 1))
                printf "%-30s ${RED}%-15s${NC} %-10s %-15s\n" "$name" "$status" "$restarts" "$age"
            fi
        fi
    done <<< "$pods_info"
    
    echo
    echo -e "${BLUE}Pod统计:${NC}"
    echo "  总数: $total_pods"
    echo -e "  运行中: ${GREEN}$running_pods${NC}"
    echo -e "  异常: ${RED}$failed_pods${NC}"
    
    if [ $failed_pods -gt 0 ]; then
        log_warning "发现 $failed_pods 个异常Pod"
        return 1
    else
        log_success "所有Pod运行正常"
        return 0
    fi
}

# 检查服务状态
check_services() {
    log_header "服务健康检查"
    
    local services_info=$(kubectl get services -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$services_info" ]; then
        log_warning "命名空间中没有服务"
        return 1
    fi
    
    echo -e "${BLUE}服务状态详情:${NC}"
    printf "%-25s %-15s %-20s %-10s\n" "NAME" "TYPE" "CLUSTER-IP" "PORT(S)"
    echo "--------------------------------------------------------------------------------"
    
    local total_services=0
    local healthy_services=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local name=$(echo "$line" | awk '{print $1}')
            local type=$(echo "$line" | awk '{print $2}')
            local cluster_ip=$(echo "$line" | awk '{print $3}')
            local ports=$(echo "$line" | awk '{print $5}')
            
            total_services=$((total_services + 1))
            
            # 检查服务是否有端点
            local endpoints=$(kubectl get endpoints "$name" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}')
            
            if [[ -n "$endpoints" && "$endpoints" != "<none>" ]]; then
                healthy_services=$((healthy_services + 1))
                printf "%-25s %-15s %-20s ${GREEN}%-10s${NC}\n" "$name" "$type" "$cluster_ip" "$ports"
            else
                printf "%-25s %-15s %-20s ${RED}%-10s${NC}\n" "$name" "$type" "$cluster_ip" "$ports"
            fi
        fi
    done <<< "$services_info"
    
    echo
    echo -e "${BLUE}服务统计:${NC}"
    echo "  总数: $total_services"
    echo -e "  健康: ${GREEN}$healthy_services${NC}"
    echo -e "  异常: ${RED}$((total_services - healthy_services))${NC}"
    
    if [ $healthy_services -eq $total_services ]; then
        log_success "所有服务运行正常"
        return 0
    else
        log_warning "发现 $((total_services - healthy_services)) 个异常服务"
        return 1
    fi
}

# 检查存储状态
check_storage() {
    log_header "存储健康检查"
    
    local pvc_info=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pvc_info" ]; then
        log_info "命名空间中没有PVC"
        return 0
    fi
    
    echo -e "${BLUE}PVC状态详情:${NC}"
    printf "%-25s %-10s %-15s %-10s\n" "NAME" "STATUS" "VOLUME" "CAPACITY"
    echo "--------------------------------------------------------------------------------"
    
    local total_pvcs=0
    local bound_pvcs=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local name=$(echo "$line" | awk '{print $1}')
            local status=$(echo "$line" | awk '{print $2}')
            local volume=$(echo "$line" | awk '{print $3}')
            local capacity=$(echo "$line" | awk '{print $4}')
            
            total_pvcs=$((total_pvcs + 1))
            
            if [ "$status" == "Bound" ]; then
                bound_pvcs=$((bound_pvcs + 1))
                printf "%-25s ${GREEN}%-10s${NC} %-15s %-10s\n" "$name" "$status" "$volume" "$capacity"
            else
                printf "%-25s ${RED}%-10s${NC} %-15s %-10s\n" "$name" "$status" "$volume" "$capacity"
            fi
        fi
    done <<< "$pvc_info"
    
    echo
    echo -e "${BLUE}PVC统计:${NC}"
    echo "  总数: $total_pvcs"
    echo -e "  已绑定: ${GREEN}$bound_pvcs${NC}"
    echo -e "  未绑定: ${RED}$((total_pvcs - bound_pvcs))${NC}"
    
    if [ $bound_pvcs -eq $total_pvcs ]; then
        log_success "所有PVC绑定正常"
        return 0
    else
        log_warning "发现 $((total_pvcs - bound_pvcs)) 个未绑定的PVC"
        return 1
    fi
}

# 检查应用健康端点
check_app_health() {
    log_header "应用健康端点检查"
    
    # 检查API网关是否可访问
    local gateway_pod=$(kubectl get pods -n "$NAMESPACE" -l app=api-gateway --no-headers | head -1 | awk '{print $1}')
    
    if [ -z "$gateway_pod" ]; then
        log_error "找不到API网关Pod"
        return 1
    fi
    
    echo -e "${BLUE}健康端点检查:${NC}"
    
    # 检查各服务健康端点
    local services=("user" "product" "order" "notification")
    local healthy_endpoints=0
    local total_endpoints=${#services[@]}
    
    for service in "${services[@]}"; do
        local health_check=$(kubectl exec -n "$NAMESPACE" "$gateway_pod" -- curl -s -o /dev/null -w "%{http_code}" "http://${service}-service/health" 2>/dev/null || echo "000")
        
        if [ "$health_check" == "200" ]; then
            echo -e "  ${service}-service: ${GREEN}✓ 健康${NC}"
            healthy_endpoints=$((healthy_endpoints + 1))
        else
            echo -e "  ${service}-service: ${RED}✗ 异常 (HTTP $health_check)${NC}"
        fi
    done
    
    echo
    echo -e "${BLUE}健康端点统计:${NC}"
    echo "  总数: $total_endpoints"
    echo -e "  健康: ${GREEN}$healthy_endpoints${NC}"
    echo -e "  异常: ${RED}$((total_endpoints - healthy_endpoints))${NC}"
    
    if [ $healthy_endpoints -eq $total_endpoints ]; then
        log_success "所有健康端点正常"
        return 0
    else
        log_warning "发现 $((total_endpoints - healthy_endpoints)) 个异常健康端点"
        return 1
    fi
}

# 生成健康报告
generate_health_report() {
    log_header "生成健康报告"
    
    local report_file="$PROJECT_DIR/.taskmaster/reports/health-report-$(date +%Y%m%d-%H%M%S).json"
    local report_dir=$(dirname "$report_file")
    
    # 创建报告目录
    mkdir -p "$report_dir"
    
    # 收集系统信息
    local cluster_info=$(kubectl cluster-info --short 2>/dev/null || echo "Unknown")
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    local namespace_count=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    # 生成JSON报告
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cluster": {
    "info": "$cluster_info",
    "nodes": $node_count,
    "namespaces": $namespace_count
  },
  "namespace": "$NAMESPACE",
  "pods": $(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null | jq '.items | length' || echo "0"),
  "services": $(kubectl get services -n "$NAMESPACE" -o json 2>/dev/null | jq '.items | length' || echo "0"),
  "pvcs": $(kubectl get pvc -n "$NAMESPACE" -o json 2>/dev/null | jq '.items | length' || echo "0"),
  "health_status": "$([ $overall_status -eq 0 ] && echo "healthy" || echo "unhealthy")"
}
EOF
    
    log_success "健康报告已生成: $report_file"
}

# 主函数
main() {
    log_header "微服务健康检查开始"
    
    local overall_status=0
    
    # 执行各项检查
    check_kubectl || overall_status=1
    check_pods || overall_status=1
    check_services || overall_status=1
    check_storage || overall_status=1
    check_app_health || overall_status=1
    
    # 生成报告
    generate_health_report
    
    # 输出总结
    log_header "健康检查总结"
    
    if [ $overall_status -eq 0 ]; then
        log_success "🎉 所有组件健康状态良好！"
        echo -e "${GREEN}系统运行正常，可以正常提供服务${NC}"
    else
        log_warning "⚠️  发现部分组件异常"
        echo -e "${YELLOW}请检查上述异常项目并进行修复${NC}"
        echo
        echo -e "${BLUE}故障排查建议:${NC}"
        echo "1. 查看Pod日志: kubectl logs <pod-name> -n $NAMESPACE"
        echo "2. 查看Pod详情: kubectl describe pod <pod-name> -n $NAMESPACE"
        echo "3. 查看事件: kubectl get events -n $NAMESPACE --sort-by=.metadata.creationTimestamp"
        echo "4. 重启异常服务: kubectl rollout restart deployment/<service-name> -n $NAMESPACE"
    fi
    
    exit $overall_status
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
