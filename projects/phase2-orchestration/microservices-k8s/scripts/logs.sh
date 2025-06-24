#!/bin/bash

# ==============================================================================
# 微服务日志查看脚本
# 查看和分析微服务应用日志
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
LINES=50
FOLLOW=false
SINCE=""
CONTAINER=""
ALL_CONTAINERS=false
PREVIOUS=false
TAIL_MODE=false

# 帮助信息
show_help() {
    echo "微服务日志查看工具"
    echo ""
    echo "用法: $0 [选项] [服务名]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  -f, --follow            实时跟踪日志"
    echo "  -l, --lines N           显示最后N行日志 (默认: 50)"
    echo "  -s, --since TIME        显示指定时间之后的日志 (如: 1h, 30m, 2006-01-02T15:04:05Z)"
    echo "  -c, --container NAME    指定容器名称"
    echo "  -a, --all-containers    显示Pod中所有容器的日志"
    echo "  -p, --previous          显示之前容器实例的日志"
    echo "  -t, --tail              持续监控模式"
    echo ""
    echo "服务名:"
    echo "  user                    用户服务"
    echo "  product                 商品服务"
    echo "  order                   订单服务"
    echo "  notification            通知服务"
    echo "  api-gateway             API网关"
    echo "  postgres                PostgreSQL数据库"
    echo "  redis                   Redis缓存"
    echo "  rabbitmq                RabbitMQ消息队列"
    echo "  all                     所有服务"
    echo ""
    echo "示例:"
    echo "  $0                      显示所有服务的最新日志"
    echo "  $0 user                 显示用户服务日志"
    echo "  $0 -f user              实时跟踪用户服务日志"
    echo "  $0 -l 100 product       显示商品服务最后100行日志"
    echo "  $0 -s 1h order          显示订单服务最近1小时的日志"
    echo "  $0 -p user              显示用户服务之前实例的日志"
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
            -f|--follow)
                FOLLOW=true
                shift
                ;;
            -l|--lines)
                LINES="$2"
                shift 2
                ;;
            -s|--since)
                SINCE="$2"
                shift 2
                ;;
            -c|--container)
                CONTAINER="$2"
                shift 2
                ;;
            -a|--all-containers)
                ALL_CONTAINERS=true
                shift
                ;;
            -p|--previous)
                PREVIOUS=true
                shift
                ;;
            -t|--tail)
                TAIL_MODE=true
                FOLLOW=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                SERVICE="$1"
                shift
                ;;
        esac
    done
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

# 获取Pod名称
get_pod_name() {
    local service=$1
    local app_label=""
    
    case $service in
        user)
            app_label="user-service"
            ;;
        product)
            app_label="product-service"
            ;;
        order)
            app_label="order-service"
            ;;
        notification)
            app_label="notification-service"
            ;;
        api-gateway|gateway)
            app_label="api-gateway"
            ;;
        postgres|db|database)
            app_label="postgres"
            ;;
        redis|cache)
            app_label="redis"
            ;;
        rabbitmq|mq|queue)
            app_label="rabbitmq"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app="$app_label" --no-headers 2>/dev/null | awk '{print $1}')
    
    if [ -z "$pods" ]; then
        log_error "找不到服务 $service 的Pod"
        return 1
    fi
    
    echo "$pods"
}

# 构建kubectl logs命令
build_logs_command() {
    local pod_name=$1
    local cmd="kubectl logs"
    
    # 添加命名空间
    cmd="$cmd -n $NAMESPACE"
    
    # 添加行数限制
    if [ "$LINES" != "all" ]; then
        cmd="$cmd --tail=$LINES"
    fi
    
    # 添加时间过滤
    if [ -n "$SINCE" ]; then
        cmd="$cmd --since=$SINCE"
    fi
    
    # 添加容器名称
    if [ -n "$CONTAINER" ]; then
        cmd="$cmd -c $CONTAINER"
    fi
    
    # 添加所有容器选项
    if [ "$ALL_CONTAINERS" = true ]; then
        cmd="$cmd --all-containers=true"
    fi
    
    # 添加之前实例选项
    if [ "$PREVIOUS" = true ]; then
        cmd="$cmd --previous"
    fi
    
    # 添加跟踪选项
    if [ "$FOLLOW" = true ]; then
        cmd="$cmd -f"
    fi
    
    # 添加Pod名称
    cmd="$cmd $pod_name"
    
    echo "$cmd"
}

# 显示单个服务日志
show_service_logs() {
    local service=$1
    
    log_header "查看 $service 服务日志"
    
    local pods=$(get_pod_name "$service")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local pod_count=$(echo "$pods" | wc -l)
    
    if [ $pod_count -eq 1 ]; then
        local pod_name=$(echo "$pods" | head -1)
        log_info "Pod: $pod_name"
        
        local cmd=$(build_logs_command "$pod_name")
        log_info "执行命令: $cmd"
        echo
        
        eval "$cmd"
    else
        log_info "发现 $pod_count 个Pod实例"
        
        if [ "$FOLLOW" = true ]; then
            log_warning "跟踪模式下只显示第一个Pod的日志"
            local pod_name=$(echo "$pods" | head -1)
            log_info "Pod: $pod_name"
            
            local cmd=$(build_logs_command "$pod_name")
            eval "$cmd"
        else
            # 显示所有Pod的日志
            while IFS= read -r pod_name; do
                if [ -n "$pod_name" ]; then
                    echo -e "${PURPLE}=== Pod: $pod_name ===${NC}"
                    local cmd=$(build_logs_command "$pod_name")
                    eval "$cmd"
                    echo
                fi
            done <<< "$pods"
        fi
    fi
}

# 显示所有服务日志
show_all_logs() {
    log_header "查看所有服务日志"
    
    local services=("user" "product" "order" "notification" "api-gateway" "postgres" "redis" "rabbitmq")
    
    if [ "$FOLLOW" = true ]; then
        log_warning "跟踪模式下只显示后端微服务日志"
        # 使用kubectl logs同时跟踪多个服务
        kubectl logs -f -l tier=backend -n "$NAMESPACE" --max-log-requests=10 --tail="$LINES"
    else
        for service in "${services[@]}"; do
            if kubectl get pods -n "$NAMESPACE" -l app="${service}-service" &> /dev/null || kubectl get pods -n "$NAMESPACE" -l app="$service" &> /dev/null; then
                show_service_logs "$service"
                echo
            fi
        done
    fi
}

# 日志分析功能
analyze_logs() {
    log_header "日志分析"
    
    local service=$1
    local pods=$(get_pod_name "$service")
    local pod_name=$(echo "$pods" | head -1)
    
    if [ -z "$pod_name" ]; then
        log_error "找不到服务Pod"
        return 1
    fi
    
    log_info "分析 $service 服务日志..."
    
    # 获取最近的日志
    local logs=$(kubectl logs -n "$NAMESPACE" --tail=1000 "$pod_name" 2>/dev/null || echo "")
    
    if [ -z "$logs" ]; then
        log_warning "没有找到日志内容"
        return 1
    fi
    
    echo -e "${BLUE}日志统计:${NC}"
    
    # 统计错误日志
    local error_count=$(echo "$logs" | grep -i "error\|exception\|fail" | wc -l)
    echo "  错误日志: $error_count 条"
    
    # 统计警告日志
    local warning_count=$(echo "$logs" | grep -i "warn\|warning" | wc -l)
    echo "  警告日志: $warning_count 条"
    
    # 统计信息日志
    local info_count=$(echo "$logs" | grep -i "info" | wc -l)
    echo "  信息日志: $info_count 条"
    
    # 显示最近的错误
    if [ $error_count -gt 0 ]; then
        echo
        echo -e "${RED}最近的错误日志:${NC}"
        echo "$logs" | grep -i "error\|exception\|fail" | tail -5
    fi
    
    # 显示最近的警告
    if [ $warning_count -gt 0 ]; then
        echo
        echo -e "${YELLOW}最近的警告日志:${NC}"
        echo "$logs" | grep -i "warn\|warning" | tail -3
    fi
}

# 导出日志
export_logs() {
    local service=$1
    local export_dir="$PROJECT_DIR/.taskmaster/logs"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    mkdir -p "$export_dir"
    
    if [ "$service" = "all" ]; then
        local export_file="$export_dir/all-services-$timestamp.log"
        log_info "导出所有服务日志到: $export_file"
        
        kubectl logs -l tier=backend -n "$NAMESPACE" --tail=1000 > "$export_file"
        kubectl logs -l tier=infrastructure -n "$NAMESPACE" --tail=1000 >> "$export_file"
    else
        local pods=$(get_pod_name "$service")
        local pod_name=$(echo "$pods" | head -1)
        local export_file="$export_dir/$service-$timestamp.log"
        
        log_info "导出 $service 服务日志到: $export_file"
        kubectl logs -n "$NAMESPACE" --tail=1000 "$pod_name" > "$export_file"
    fi
    
    log_success "日志导出完成"
}

# 主函数
main() {
    parse_args "$@"
    check_kubectl
    
    # 如果是tail模式，显示实时监控界面
    if [ "$TAIL_MODE" = true ]; then
        log_header "实时日志监控模式"
        log_info "按 Ctrl+C 退出监控"
        echo
        
        if [ -n "$SERVICE" ] && [ "$SERVICE" != "all" ]; then
            show_service_logs "$SERVICE"
        else
            show_all_logs
        fi
        return
    fi
    
    # 根据参数执行相应操作
    if [ -z "$SERVICE" ] || [ "$SERVICE" = "all" ]; then
        show_all_logs
    else
        case $SERVICE in
            analyze)
                if [ -z "$2" ]; then
                    log_error "请指定要分析的服务名"
                    exit 1
                fi
                analyze_logs "$2"
                ;;
            export)
                if [ -z "$2" ]; then
                    export_logs "all"
                else
                    export_logs "$2"
                fi
                ;;
            *)
                show_service_logs "$SERVICE"
                ;;
        esac
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
