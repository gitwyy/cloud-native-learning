#!/bin/bash

# 端口转发管理脚本
# 用于管理云原生可观测性系统的端口转发

set -e

# 检查是否支持必要的功能
if ! command -v lsof >/dev/null 2>&1; then
    echo "警告: lsof 命令不可用，端口检查功能可能受限"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# PID 文件目录
PID_DIR="/tmp/k8s-port-forward"
mkdir -p "$PID_DIR"

# 端口转发配置函数
get_port_forward_config() {
    local service_name=$1
    case "$service_name" in
        "kibana")
            echo "logging:svc/kibana:5601:5601"
            ;;
        "jaeger")
            echo "tracing:svc/jaeger-query:16686:16686"
            ;;
        "elasticsearch")
            echo "logging:svc/elasticsearch:9200:9200"
            ;;
        "user-service")
            echo "default:svc/user-service:8080:8080"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 获取所有服务名称
get_all_services() {
    echo "kibana jaeger elasticsearch user-service"
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 启动单个端口转发
start_port_forward() {
    local service_name=$1
    local config=$(get_port_forward_config "$service_name")

    if [ -z "$config" ]; then
        log_error "未知服务: $service_name"
        return 1
    fi
    
    IFS=':' read -r namespace service local_port remote_port <<< "$config"
    local pid_file="$PID_DIR/${service_name}.pid"
    
    # 检查是否已经在运行
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log_warning "$service_name 端口转发已在运行 (PID: $(cat "$pid_file"))"
        return 0
    fi
    
    # 检查端口是否被占用
    if check_port "$local_port"; then
        log_warning "端口 $local_port 已被占用，尝试终止现有进程..."
        pkill -f "kubectl.*port-forward.*$local_port" || true
        sleep 2
    fi
    
    # 启动端口转发
    log_info "启动 $service_name 端口转发: $local_port -> $remote_port"
    
    if [ "$namespace" = "default" ]; then
        kubectl port-forward "$service" "$local_port:$remote_port" >/dev/null 2>&1 &
    else
        kubectl port-forward -n "$namespace" "$service" "$local_port:$remote_port" >/dev/null 2>&1 &
    fi
    
    local pid=$!
    echo "$pid" > "$pid_file"
    
    # 等待端口转发建立
    sleep 3
    
    # 验证端口转发是否成功
    if kill -0 "$pid" 2>/dev/null && check_port "$local_port"; then
        log_success "$service_name 端口转发启动成功 (PID: $pid, Port: $local_port)"
        return 0
    else
        log_error "$service_name 端口转发启动失败"
        rm -f "$pid_file"
        return 1
    fi
}

# 停止单个端口转发
stop_port_forward() {
    local service_name=$1
    local pid_file="$PID_DIR/${service_name}.pid"
    
    if [ ! -f "$pid_file" ]; then
        log_warning "$service_name 端口转发未运行"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
        log_info "停止 $service_name 端口转发 (PID: $pid)"
        kill "$pid"
        rm -f "$pid_file"
        log_success "$service_name 端口转发已停止"
    else
        log_warning "$service_name 端口转发进程不存在，清理 PID 文件"
        rm -f "$pid_file"
    fi
}

# 检查端口转发状态
check_status() {
    local service_name=$1
    local config=$(get_port_forward_config "$service_name")
    local pid_file="$PID_DIR/${service_name}.pid"

    if [ -z "$config" ]; then
        echo "❌ 未知服务"
        return 1
    fi
    
    IFS=':' read -r namespace service local_port remote_port <<< "$config"
    
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        local pid=$(cat "$pid_file")
        if check_port "$local_port"; then
            echo "✅ 运行中 (PID: $pid, Port: $local_port)"
            return 0
        else
            echo "❌ 进程存在但端口未监听"
            return 1
        fi
    else
        echo "❌ 未运行"
        return 1
    fi
}

# 启动所有端口转发
start_all() {
    log_info "启动所有端口转发..."
    local failed=0

    for service in $(get_all_services); do
        if ! start_port_forward "$service"; then
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log_success "所有端口转发启动成功"
        show_access_info
    else
        log_warning "$failed 个端口转发启动失败"
    fi
}

# 停止所有端口转发
stop_all() {
    log_info "停止所有端口转发..."

    for service in $(get_all_services); do
        stop_port_forward "$service"
    done
    
    # 清理所有相关进程
    pkill -f "kubectl.*port-forward" 2>/dev/null || true
    
    log_success "所有端口转发已停止"
}

# 显示状态
show_status() {
    echo ""
    echo "=========================================="
    echo "📊 端口转发状态"
    echo "=========================================="
    
    for service in $(get_all_services); do
        local config=$(get_port_forward_config "$service")
        IFS=':' read -r namespace service_path local_port remote_port <<< "$config"
        
        printf "%-15s: " "$service"
        check_status "$service"
    done
    
    echo ""
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "=========================================="
    echo "🌐 服务访问地址"
    echo "=========================================="
    echo ""
    echo "📊 Web 界面："
    echo "----------------------------------------"
    echo "Kibana (日志分析):     http://localhost:5601"
    echo "Jaeger (链路追踪):     http://localhost:16686"
    echo "Elasticsearch API:     http://localhost:9200"
    echo "用户服务 API:          http://localhost:8080"
    echo ""
    echo "📝 API 示例："
    echo "----------------------------------------"
    echo "# 检查 Elasticsearch 健康状态"
    echo "curl http://localhost:9200/_cluster/health"
    echo ""
    echo "# 查询日志数据"
    echo "curl \"http://localhost:9200/fluentbit/_search?q=user-service&size=5\""
    echo ""
    echo "# 查看 Jaeger 服务列表"
    echo "curl http://localhost:16686/api/services"
    echo ""
    echo "# 测试用户服务"
    echo "curl http://localhost:8080/health"
    echo "curl http://localhost:8080/api/users"
    echo ""
    echo "🔧 管理命令："
    echo "----------------------------------------"
    echo "查看状态: ./port-forward.sh status"
    echo "停止转发: ./port-forward.sh stop"
    echo "重启转发: ./port-forward.sh restart"
    echo ""
    echo "=========================================="
}

# 重启所有端口转发
restart_all() {
    log_info "重启所有端口转发..."
    stop_all
    sleep 2
    start_all
}

# 清理函数
cleanup() {
    log_info "清理端口转发..."
    stop_all
    exit 0
}

# 捕获退出信号
trap cleanup SIGINT SIGTERM

# 显示帮助信息
show_help() {
    echo "端口转发管理脚本"
    echo ""
    echo "用法: $0 [命令] [服务名]"
    echo ""
    echo "命令:"
    echo "  start [service]    启动端口转发 (默认启动所有)"
    echo "  stop [service]     停止端口转发 (默认停止所有)"
    echo "  restart [service]  重启端口转发 (默认重启所有)"
    echo "  status             显示端口转发状态"
    echo "  info               显示访问信息"
    echo "  help               显示此帮助信息"
    echo ""
    echo "支持的服务:"
    for service in $(get_all_services); do
        local config=$(get_port_forward_config "$service")
        IFS=':' read -r namespace service_path local_port remote_port <<< "$config"
        echo "  $service (端口 $local_port)"
    done
    echo ""
    echo "示例:"
    echo "  $0 start              # 启动所有端口转发"
    echo "  $0 start kibana       # 只启动 Kibana 端口转发"
    echo "  $0 stop               # 停止所有端口转发"
    echo "  $0 status             # 查看状态"
}

# 主函数
main() {
    local command=${1:-"start"}
    local service=${2:-""}
    
    case "$command" in
        "start")
            if [ -n "$service" ]; then
                start_port_forward "$service"
            else
                start_all
            fi
            ;;
        "stop")
            if [ -n "$service" ]; then
                stop_port_forward "$service"
            else
                stop_all
            fi
            ;;
        "restart")
            if [ -n "$service" ]; then
                stop_port_forward "$service"
                sleep 1
                start_port_forward "$service"
            else
                restart_all
            fi
            ;;
        "status")
            show_status
            ;;
        "info")
            show_access_info
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
