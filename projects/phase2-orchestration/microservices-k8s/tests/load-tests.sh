#!/bin/bash

# ==============================================================================
# 微服务负载测试脚本
# 使用Apache Bench (ab) 和 curl 进行负载测试
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

# 测试配置
BASE_URL=""
CONCURRENT_USERS=10
TOTAL_REQUESTS=100
TEST_DURATION=60
RAMP_UP_TIME=10
VERBOSE=false
SAVE_RESULTS=false
TEST_SCENARIO="basic"

# 帮助信息
show_help() {
    echo "微服务负载测试工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  -u, --url URL           指定API基础URL"
    echo "  -c, --concurrent N      并发用户数 (默认: 10)"
    echo "  -n, --requests N        总请求数 (默认: 100)"
    echo "  -t, --time N            测试持续时间(秒) (默认: 60)"
    echo "  -r, --ramp-up N         预热时间(秒) (默认: 10)"
    echo "  -s, --scenario NAME     测试场景 (basic|stress|spike|endurance)"
    echo "  -v, --verbose           详细输出模式"
    echo "  --save                  保存测试结果到文件"
    echo ""
    echo "测试场景:"
    echo "  basic                   基础负载测试"
    echo "  stress                  压力测试 (高并发)"
    echo "  spike                   峰值测试 (突发流量)"
    echo "  endurance               持久性测试 (长时间)"
    echo ""
    echo "示例:"
    echo "  $0                      运行基础负载测试"
    echo "  $0 -c 50 -n 1000       50并发用户，1000请求"
    echo "  $0 -s stress           运行压力测试"
    echo "  $0 -t 300 -s endurance 运行5分钟持久性测试"
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
            -u|--url)
                BASE_URL="$2"
                shift 2
                ;;
            -c|--concurrent)
                CONCURRENT_USERS="$2"
                shift 2
                ;;
            -n|--requests)
                TOTAL_REQUESTS="$2"
                shift 2
                ;;
            -t|--time)
                TEST_DURATION="$2"
                shift 2
                ;;
            -r|--ramp-up)
                RAMP_UP_TIME="$2"
                shift 2
                ;;
            -s|--scenario)
                TEST_SCENARIO="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --save)
                SAVE_RESULTS=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查依赖工具
check_dependencies() {
    local missing_tools=()
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v ab &> /dev/null; then
        log_warning "Apache Bench (ab) 未安装，将使用curl进行测试"
        log_info "安装建议: apt-get install apache2-utils 或 brew install httpie"
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        exit 1
    fi
}

# 自动检测API URL
detect_api_url() {
    if [ -n "$BASE_URL" ]; then
        log_info "使用指定的URL: $BASE_URL"
        return 0
    fi
    
    log_info "自动检测API URL..."
    
    # 检查kubectl连接
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl未安装，请手动指定URL"
        exit 1
    fi
    
    # 尝试获取Minikube URL
    if command -v minikube &> /dev/null && minikube status &> /dev/null 2>&1; then
        local minikube_url=$(minikube service api-gateway -n "$NAMESPACE" --url 2>/dev/null || echo "")
        if [ -n "$minikube_url" ]; then
            BASE_URL="$minikube_url"
            log_success "检测到Minikube URL: $BASE_URL"
            return 0
        fi
    fi
    
    # 尝试获取NodePort
    local node_port=$(kubectl get service api-gateway -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    if [ -n "$node_port" ]; then
        BASE_URL="http://localhost:$node_port"
        log_success "检测到NodePort URL: $BASE_URL"
        return 0
    fi
    
    log_error "无法自动检测API URL，请使用 -u 选项手动指定"
    exit 1
}

# 设置测试场景参数
setup_test_scenario() {
    case $TEST_SCENARIO in
        basic)
            CONCURRENT_USERS=${CONCURRENT_USERS:-10}
            TOTAL_REQUESTS=${TOTAL_REQUESTS:-100}
            TEST_DURATION=${TEST_DURATION:-60}
            ;;
        stress)
            CONCURRENT_USERS=${CONCURRENT_USERS:-50}
            TOTAL_REQUESTS=${TOTAL_REQUESTS:-1000}
            TEST_DURATION=${TEST_DURATION:-120}
            ;;
        spike)
            CONCURRENT_USERS=${CONCURRENT_USERS:-100}
            TOTAL_REQUESTS=${TOTAL_REQUESTS:-500}
            TEST_DURATION=${TEST_DURATION:-30}
            RAMP_UP_TIME=5
            ;;
        endurance)
            CONCURRENT_USERS=${CONCURRENT_USERS:-20}
            TOTAL_REQUESTS=${TOTAL_REQUESTS:-2000}
            TEST_DURATION=${TEST_DURATION:-300}
            ;;
        *)
            log_error "未知测试场景: $TEST_SCENARIO"
            exit 1
            ;;
    esac
    
    log_info "测试场景: $TEST_SCENARIO"
    log_info "并发用户: $CONCURRENT_USERS"
    log_info "总请求数: $TOTAL_REQUESTS"
    log_info "测试时长: $TEST_DURATION 秒"
    log_info "预热时间: $RAMP_UP_TIME 秒"
}

# 检查服务可用性
check_service_availability() {
    log_info "检查服务可用性..."
    
    local health_url="$BASE_URL/health"
    local response=$(curl -s -w "%{http_code}" --max-time 10 "$health_url" 2>/dev/null || echo "000")
    local status_code="${response: -3}"
    
    if [ "$status_code" = "200" ]; then
        log_success "服务可用，开始负载测试"
        return 0
    else
        log_error "服务不可用 (HTTP $status_code)，无法进行负载测试"
        exit 1
    fi
}

# 使用Apache Bench进行负载测试
run_ab_test() {
    local endpoint=$1
    local test_name=$2
    
    if ! command -v ab &> /dev/null; then
        return 1
    fi
    
    local url="$BASE_URL$endpoint"
    
    log_info "使用Apache Bench测试: $test_name"
    log_info "URL: $url"
    
    # 执行ab测试
    local ab_output=$(ab -n "$TOTAL_REQUESTS" -c "$CONCURRENT_USERS" -g "/tmp/ab_results.tsv" "$url" 2>&1)
    
    if [ $? -eq 0 ]; then
        # 解析结果
        local requests_per_sec=$(echo "$ab_output" | grep "Requests per second" | awk '{print $4}')
        local time_per_request=$(echo "$ab_output" | grep "Time per request" | head -1 | awk '{print $4}')
        local failed_requests=$(echo "$ab_output" | grep "Failed requests" | awk '{print $3}')
        local transfer_rate=$(echo "$ab_output" | grep "Transfer rate" | awk '{print $3}')
        
        echo -e "${GREEN}测试结果:${NC}"
        echo "  请求/秒: $requests_per_sec"
        echo "  平均响应时间: $time_per_request ms"
        echo "  失败请求: $failed_requests"
        echo "  传输速率: $transfer_rate KB/sec"
        
        if [ "$VERBOSE" = true ]; then
            echo
            echo -e "${BLUE}详细输出:${NC}"
            echo "$ab_output"
        fi
        
        return 0
    else
        log_error "Apache Bench测试失败"
        return 1
    fi
}

# 使用curl进行负载测试
run_curl_test() {
    local endpoint=$1
    local test_name=$2
    
    local url="$BASE_URL$endpoint"
    
    log_info "使用curl测试: $test_name"
    log_info "URL: $url"
    
    local start_time=$(date +%s)
    local success_count=0
    local error_count=0
    local total_time=0
    local min_time=999999
    local max_time=0
    
    # 预热
    log_info "预热阶段 ($RAMP_UP_TIME 秒)..."
    for ((i=1; i<=RAMP_UP_TIME; i++)); do
        curl -s -o /dev/null "$url" &
        sleep 1
    done
    wait
    
    # 主测试
    log_info "开始负载测试..."
    
    for ((i=1; i<=TOTAL_REQUESTS; i++)); do
        # 控制并发数
        if [ $((i % CONCURRENT_USERS)) -eq 0 ]; then
            wait
        fi
        
        (
            local request_start=$(date +%s.%3N)
            local response=$(curl -s -w "%{http_code}:%{time_total}" --max-time 30 "$url" 2>/dev/null || echo "000:30.000")
            local request_end=$(date +%s.%3N)
            
            local status_code=$(echo "$response" | cut -d':' -f1)
            local time_total=$(echo "$response" | cut -d':' -f2)
            
            if [ "$status_code" = "200" ]; then
                echo "SUCCESS:$time_total" >> /tmp/curl_results.txt
            else
                echo "ERROR:$status_code" >> /tmp/curl_results.txt
            fi
        ) &
        
        # 显示进度
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    
    wait
    echo
    
    # 分析结果
    if [ -f /tmp/curl_results.txt ]; then
        success_count=$(grep "SUCCESS" /tmp/curl_results.txt | wc -l)
        error_count=$(grep "ERROR" /tmp/curl_results.txt | wc -l)
        
        if [ $success_count -gt 0 ]; then
            local times=$(grep "SUCCESS" /tmp/curl_results.txt | cut -d':' -f2)
            total_time=$(echo "$times" | awk '{sum+=$1} END {print sum}')
            min_time=$(echo "$times" | sort -n | head -1)
            max_time=$(echo "$times" | sort -n | tail -1)
            local avg_time=$(echo "scale=3; $total_time / $success_count" | bc -l)
            
            local end_time=$(date +%s)
            local test_duration=$((end_time - start_time))
            local requests_per_sec=$(echo "scale=2; $success_count / $test_duration" | bc -l)
            
            echo -e "${GREEN}测试结果:${NC}"
            echo "  总请求数: $TOTAL_REQUESTS"
            echo "  成功请求: $success_count"
            echo "  失败请求: $error_count"
            echo "  请求/秒: $requests_per_sec"
            echo "  平均响应时间: ${avg_time}s"
            echo "  最小响应时间: ${min_time}s"
            echo "  最大响应时间: ${max_time}s"
            echo "  测试时长: ${test_duration}s"
        fi
        
        rm -f /tmp/curl_results.txt
    fi
}

# 运行负载测试
run_load_test() {
    local endpoint=$1
    local test_name=$2
    
    log_header "负载测试: $test_name"
    
    # 优先使用Apache Bench
    if run_ab_test "$endpoint" "$test_name"; then
        return 0
    else
        # 回退到curl
        run_curl_test "$endpoint" "$test_name"
    fi
}

# 监控系统资源
monitor_resources() {
    if ! command -v kubectl &> /dev/null; then
        return 0
    fi
    
    log_info "监控系统资源使用情况..."
    
    # 获取Pod资源使用情况
    if command -v kubectl &> /dev/null; then
        echo -e "${BLUE}Pod资源使用:${NC}"
        kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "无法获取资源使用情况"
        
        echo
        echo -e "${BLUE}节点资源使用:${NC}"
        kubectl top nodes 2>/dev/null || echo "无法获取节点资源使用情况"
    fi
}

# 生成测试报告
generate_load_test_report() {
    if [ "$SAVE_RESULTS" = false ]; then
        return 0
    fi
    
    local report_dir="$PROJECT_DIR/.taskmaster/reports"
    local report_file="$report_dir/load-test-report-$(date +%Y%m%d-%H%M%S).json"
    
    mkdir -p "$report_dir"
    
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_config": {
    "scenario": "$TEST_SCENARIO",
    "base_url": "$BASE_URL",
    "concurrent_users": $CONCURRENT_USERS,
    "total_requests": $TOTAL_REQUESTS,
    "test_duration": $TEST_DURATION,
    "ramp_up_time": $RAMP_UP_TIME
  },
  "environment": {
    "namespace": "$NAMESPACE",
    "test_tool": "$(command -v ab &> /dev/null && echo 'apache-bench' || echo 'curl')"
  }
}
EOF
    
    log_success "负载测试报告已保存: $report_file"
}

# 主函数
main() {
    parse_args "$@"
    
    log_header "微服务负载测试开始"
    
    # 检查依赖
    check_dependencies
    
    # 检测API URL
    detect_api_url
    
    # 设置测试场景
    setup_test_scenario
    
    # 检查服务可用性
    check_service_availability
    
    # 运行负载测试
    run_load_test "/health" "健康检查端点"
    run_load_test "/api/v1/products" "商品列表API"
    run_load_test "/api/v1/categories" "分类列表API"
    
    # 监控资源
    monitor_resources
    
    # 生成报告
    generate_load_test_report
    
    log_header "负载测试完成"
    log_success "🎉 负载测试执行完毕！"
    
    if [ "$SAVE_RESULTS" = true ]; then
        log_info "详细结果已保存到报告文件"
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
