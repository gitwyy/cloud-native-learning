#!/bin/bash

# ==============================================================================
# 微服务扩缩容脚本
# 管理微服务的水平扩缩容操作
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

# 默认参数
SERVICE=""
REPLICAS=""
AUTO_SCALE=false
MIN_REPLICAS=""
MAX_REPLICAS=""
CPU_THRESHOLD=""
MEMORY_THRESHOLD=""
DRY_RUN=false

# 帮助信息
show_help() {
    echo "微服务扩缩容管理工具"
    echo ""
    echo "用法: $0 [选项] <服务名> <副本数>"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  -a, --auto              启用自动扩缩容 (HPA)"
    echo "  --min N                 最小副本数 (用于HPA)"
    echo "  --max N                 最大副本数 (用于HPA)"
    echo "  --cpu N                 CPU使用率阈值 (用于HPA, 默认70%)"
    echo "  --memory N              内存使用率阈值 (用于HPA, 默认80%)"
    echo "  --dry-run               预览模式，不执行实际操作"
    echo ""
    echo "服务名:"
    echo "  user                    用户服务"
    echo "  product                 商品服务"
    echo "  order                   订单服务"
    echo "  notification            通知服务"
    echo "  api-gateway             API网关"
    echo "  all                     所有微服务"
    echo ""
    echo "示例:"
    echo "  $0 user 3               将用户服务扩容到3个副本"
    echo "  $0 all 2                将所有微服务扩容到2个副本"
    echo "  $0 -a user --min 2 --max 10  为用户服务启用自动扩缩容"
    echo "  $0 --dry-run user 5     预览用户服务扩容到5个副本的操作"
}

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

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--auto)
                AUTO_SCALE=true
                shift
                ;;
            --min)
                MIN_REPLICAS="$2"
                shift 2
                ;;
            --max)
                MAX_REPLICAS="$2"
                shift 2
                ;;
            --cpu)
                CPU_THRESHOLD="$2"
                shift 2
                ;;
            --memory)
                MEMORY_THRESHOLD="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$SERVICE" ]; then
                    SERVICE="$1"
                elif [ -z "$REPLICAS" ]; then
                    REPLICAS="$1"
                else
                    log_error "过多的参数: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 参数验证
    if [ -z "$SERVICE" ]; then
        log_error "请指定服务名"
        show_help
        exit 1
    fi
    
    if [ "$AUTO_SCALE" = false ] && [ -z "$REPLICAS" ]; then
        log_error "请指定副本数或使用 --auto 选项"
        show_help
        exit 1
    fi
    
    # 设置默认值
    if [ "$AUTO_SCALE" = true ]; then
        MIN_REPLICAS=${MIN_REPLICAS:-2}
        MAX_REPLICAS=${MAX_REPLICAS:-10}
        CPU_THRESHOLD=${CPU_THRESHOLD:-70}
        MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-80}
    fi
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
}

# 获取部署名称
get_deployment_name() {
    local service=$1
    
    case $service in
        user)
            echo "user-service"
            ;;
        product)
            echo "product-service"
            ;;
        order)
            echo "order-service"
            ;;
        notification)
            echo "notification-service"
            ;;
        api-gateway|gateway)
            echo "api-gateway"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
}

# 检查部署是否存在
check_deployment() {
    local deployment=$1
    
    if ! kubectl get deployment "$deployment" -n "$NAMESPACE" &> /dev/null; then
        log_error "部署 $deployment 不存在"
        return 1
    fi
    
    return 0
}

# 获取当前副本数
get_current_replicas() {
    local deployment=$1
    kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0"
}

# 获取就绪副本数
get_ready_replicas() {
    local deployment=$1
    kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"
}

# 手动扩缩容
manual_scale() {
    local service=$1
    local replicas=$2
    
    local deployment=$(get_deployment_name "$service")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    if ! check_deployment "$deployment"; then
        return 1
    fi
    
    local current_replicas=$(get_current_replicas "$deployment")
    
    log_info "服务: $service"
    log_info "部署: $deployment"
    log_info "当前副本数: $current_replicas"
    log_info "目标副本数: $replicas"
    
    if [ "$current_replicas" -eq "$replicas" ]; then
        log_warning "副本数已经是 $replicas，无需调整"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[预览] 将执行: kubectl scale deployment $deployment --replicas=$replicas -n $NAMESPACE"
        return 0
    fi
    
    log_info "开始扩缩容操作..."
    
    if kubectl scale deployment "$deployment" --replicas="$replicas" -n "$NAMESPACE"; then
        log_success "扩缩容命令执行成功"
        
        # 等待扩缩容完成
        log_info "等待扩缩容完成..."
        local timeout=300  # 5分钟超时
        local elapsed=0
        
        while [ $elapsed -lt $timeout ]; do
            local ready_replicas=$(get_ready_replicas "$deployment")
            
            if [ "$ready_replicas" -eq "$replicas" ]; then
                log_success "扩缩容完成！当前就绪副本数: $ready_replicas"
                return 0
            fi
            
            log_info "等待中... 就绪副本数: $ready_replicas/$replicas"
            sleep 10
            elapsed=$((elapsed + 10))
        done
        
        log_warning "扩缩容超时，请手动检查状态"
        return 1
    else
        log_error "扩缩容命令执行失败"
        return 1
    fi
}

# 自动扩缩容 (HPA)
auto_scale() {
    local service=$1
    
    local deployment=$(get_deployment_name "$service")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    if ! check_deployment "$deployment"; then
        return 1
    fi
    
    local hpa_name="${deployment}-hpa"
    
    log_info "服务: $service"
    log_info "部署: $deployment"
    log_info "HPA名称: $hpa_name"
    log_info "最小副本数: $MIN_REPLICAS"
    log_info "最大副本数: $MAX_REPLICAS"
    log_info "CPU阈值: $CPU_THRESHOLD%"
    log_info "内存阈值: $MEMORY_THRESHOLD%"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[预览] 将创建或更新HPA配置"
        return 0
    fi
    
    # 检查HPA是否已存在
    if kubectl get hpa "$hpa_name" -n "$NAMESPACE" &> /dev/null; then
        log_info "更新现有HPA配置..."
        
        # 更新HPA
        kubectl patch hpa "$hpa_name" -n "$NAMESPACE" --type='merge' -p="{
            \"spec\": {
                \"minReplicas\": $MIN_REPLICAS,
                \"maxReplicas\": $MAX_REPLICAS,
                \"metrics\": [
                    {
                        \"type\": \"Resource\",
                        \"resource\": {
                            \"name\": \"cpu\",
                            \"target\": {
                                \"type\": \"Utilization\",
                                \"averageUtilization\": $CPU_THRESHOLD
                            }
                        }
                    },
                    {
                        \"type\": \"Resource\",
                        \"resource\": {
                            \"name\": \"memory\",
                            \"target\": {
                                \"type\": \"Utilization\",
                                \"averageUtilization\": $MEMORY_THRESHOLD
                            }
                        }
                    }
                ]
            }
        }"
        
        if [ $? -eq 0 ]; then
            log_success "HPA配置更新成功"
        else
            log_error "HPA配置更新失败"
            return 1
        fi
    else
        log_info "创建新的HPA配置..."
        
        # 创建HPA
        kubectl autoscale deployment "$deployment" \
            --cpu-percent="$CPU_THRESHOLD" \
            --min="$MIN_REPLICAS" \
            --max="$MAX_REPLICAS" \
            -n "$NAMESPACE"
        
        if [ $? -eq 0 ]; then
            log_success "HPA配置创建成功"
        else
            log_error "HPA配置创建失败"
            return 1
        fi
    fi
    
    # 显示HPA状态
    log_info "HPA状态:"
    kubectl get hpa "$hpa_name" -n "$NAMESPACE"
}

# 扩缩容所有服务
scale_all_services() {
    local replicas=$1
    local services=("user" "product" "order" "notification" "api-gateway")
    
    log_header "扩缩容所有微服务"
    
    local success_count=0
    local total_count=${#services[@]}
    
    for service in "${services[@]}"; do
        echo
        log_info "处理服务: $service"
        
        if [ "$AUTO_SCALE" = true ]; then
            if auto_scale "$service"; then
                success_count=$((success_count + 1))
            fi
        else
            if manual_scale "$service" "$replicas"; then
                success_count=$((success_count + 1))
            fi
        fi
    done
    
    echo
    log_header "扩缩容总结"
    echo "  总服务数: $total_count"
    echo -e "  成功: ${GREEN}$success_count${NC}"
    echo -e "  失败: ${RED}$((total_count - success_count))${NC}"
    
    if [ $success_count -eq $total_count ]; then
        log_success "所有服务扩缩容完成"
        return 0
    else
        log_warning "部分服务扩缩容失败"
        return 1
    fi
}

# 显示当前状态
show_current_status() {
    log_header "当前扩缩容状态"
    
    echo -e "${BLUE}部署状态:${NC}"
    kubectl get deployments -n "$NAMESPACE" -o wide
    
    echo
    echo -e "${BLUE}HPA状态:${NC}"
    kubectl get hpa -n "$NAMESPACE" 2>/dev/null || echo "没有配置HPA"
    
    echo
    echo -e "${BLUE}Pod状态:${NC}"
    kubectl get pods -n "$NAMESPACE" -o wide
}

# 主函数
main() {
    parse_args "$@"
    check_kubectl
    
    # 如果没有指定操作，显示当前状态
    if [ -z "$SERVICE" ]; then
        show_current_status
        return 0
    fi
    
    # 执行扩缩容操作
    if [ "$SERVICE" = "all" ]; then
        scale_all_services "$REPLICAS"
    else
        if [ "$AUTO_SCALE" = true ]; then
            auto_scale "$SERVICE"
        else
            manual_scale "$SERVICE" "$REPLICAS"
        fi
    fi
    
    # 显示最终状态
    echo
    show_current_status
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
