#!/bin/bash

# ==============================================================================
# 微服务API测试脚本
# 测试所有微服务的API端点功能
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
VERBOSE=false
SAVE_RESULTS=false
TIMEOUT=30
TEST_USER_EMAIL="test@example.com"
TEST_USER_PASSWORD="test123456"
JWT_TOKEN=""

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 帮助信息
show_help() {
    echo "微服务API测试工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  -u, --url URL           指定API基础URL"
    echo "  -v, --verbose           详细输出模式"
    echo "  -s, --save              保存测试结果到文件"
    echo "  -t, --timeout N         请求超时时间 (默认: 30秒)"
    echo "  --email EMAIL           测试用户邮箱 (默认: test@example.com)"
    echo "  --password PASS         测试用户密码 (默认: test123456)"
    echo ""
    echo "示例:"
    echo "  $0                      自动检测URL并运行测试"
    echo "  $0 -u http://localhost:8080  指定URL运行测试"
    echo "  $0 -v -s               详细模式并保存结果"
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

log_test() {
    local status=$1
    local test_name=$2
    local details=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case $status in
        "PASS")
            PASSED_TESTS=$((PASSED_TESTS + 1))
            echo -e "${GREEN}✓ PASS${NC} $test_name"
            ;;
        "FAIL")
            FAILED_TESTS=$((FAILED_TESTS + 1))
            echo -e "${RED}✗ FAIL${NC} $test_name"
            ;;
        "SKIP")
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            echo -e "${YELLOW}- SKIP${NC} $test_name"
            ;;
    esac
    
    if [ "$VERBOSE" = true ] && [ -n "$details" ]; then
        echo "       $details"
    fi
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
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--save)
                SAVE_RESULTS=true
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --email)
                TEST_USER_EMAIL="$2"
                shift 2
                ;;
            --password)
                TEST_USER_PASSWORD="$2"
                shift 2
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
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群，请手动指定URL"
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
    
    # 尝试端口转发
    log_info "尝试使用端口转发..."
    kubectl port-forward service/api-gateway 8080:80 -n "$NAMESPACE" &
    local port_forward_pid=$!
    sleep 3
    
    if curl -s "http://localhost:8080/health" &> /dev/null; then
        BASE_URL="http://localhost:8080"
        log_success "使用端口转发URL: $BASE_URL"
        return 0
    else
        kill $port_forward_pid 2>/dev/null || true
    fi
    
    log_error "无法自动检测API URL，请使用 -u 选项手动指定"
    exit 1
}

# HTTP请求函数
http_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=${4:-200}
    local headers=${5:-""}
    
    local url="$BASE_URL$endpoint"
    local curl_cmd="curl -s -w '%{http_code}' --max-time $TIMEOUT"
    
    # 添加请求方法
    curl_cmd="$curl_cmd -X $method"
    
    # 添加数据
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -d '$data' -H 'Content-Type: application/json'"
    fi
    
    # 添加认证头
    if [ -n "$JWT_TOKEN" ]; then
        curl_cmd="$curl_cmd -H 'Authorization: Bearer $JWT_TOKEN'"
    fi
    
    # 添加自定义头
    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd $headers"
    fi
    
    # 执行请求
    curl_cmd="$curl_cmd '$url'"
    
    if [ "$VERBOSE" = true ]; then
        log_info "执行请求: $curl_cmd"
    fi
    
    local response=$(eval "$curl_cmd")
    local status_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$VERBOSE" = true ]; then
        log_info "响应状态: $status_code"
        log_info "响应内容: $body"
    fi
    
    # 检查状态码
    if [ "$status_code" = "$expected_status" ]; then
        echo "$body"
        return 0
    else
        echo "Expected $expected_status, got $status_code: $body"
        return 1
    fi
}

# 测试API网关健康检查
test_gateway_health() {
    log_header "测试API网关健康检查"
    
    local response=$(http_request "GET" "/health" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "API网关健康检查" "$response"
    else
        log_test "FAIL" "API网关健康检查" "$response"
    fi
}

# 测试用户服务
test_user_service() {
    log_header "测试用户服务"
    
    # 测试用户注册
    local register_data="{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"name\":\"Test User\"}"
    local response=$(http_request "POST" "/api/v1/register" "$register_data" "201")
    if [ $? -eq 0 ]; then
        log_test "PASS" "用户注册" "注册成功"
    else
        # 如果用户已存在，也算正常
        if echo "$response" | grep -q "already exists\|409"; then
            log_test "PASS" "用户注册" "用户已存在"
        else
            log_test "FAIL" "用户注册" "$response"
        fi
    fi
    
    # 测试用户登录
    local login_data="{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}"
    local response=$(http_request "POST" "/api/v1/login" "$login_data" "200")
    if [ $? -eq 0 ]; then
        # 提取JWT token
        JWT_TOKEN=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        log_test "PASS" "用户登录" "登录成功，获取到token"
    else
        log_test "FAIL" "用户登录" "$response"
        return 1
    fi
    
    # 测试获取用户信息
    local response=$(http_request "GET" "/api/v1/profile" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "获取用户信息" "获取成功"
    else
        log_test "FAIL" "获取用户信息" "$response"
    fi
    
    # 测试用户健康检查
    local response=$(http_request "GET" "/health/user" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "用户服务健康检查" "$response"
    else
        log_test "FAIL" "用户服务健康检查" "$response"
    fi
}

# 测试商品服务
test_product_service() {
    log_header "测试商品服务"
    
    # 测试获取商品列表
    local response=$(http_request "GET" "/api/v1/products" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "获取商品列表" "获取成功"
    else
        log_test "FAIL" "获取商品列表" "$response"
    fi
    
    # 测试获取分类列表
    local response=$(http_request "GET" "/api/v1/categories" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "获取分类列表" "获取成功"
    else
        log_test "FAIL" "获取分类列表" "$response"
    fi
    
    # 测试商品搜索
    local response=$(http_request "GET" "/api/v1/products/search?q=test" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "商品搜索" "搜索成功"
    else
        log_test "FAIL" "商品搜索" "$response"
    fi
    
    # 测试商品服务健康检查
    local response=$(http_request "GET" "/health/product" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "商品服务健康检查" "$response"
    else
        log_test "FAIL" "商品服务健康检查" "$response"
    fi
}

# 测试订单服务
test_order_service() {
    log_header "测试订单服务"
    
    if [ -z "$JWT_TOKEN" ]; then
        log_test "SKIP" "订单服务测试" "需要用户认证"
        return 0
    fi
    
    # 测试获取订单列表
    local response=$(http_request "GET" "/api/v1/orders" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "获取订单列表" "获取成功"
    else
        log_test "FAIL" "获取订单列表" "$response"
    fi
    
    # 测试创建订单
    local order_data="{\"items\":[{\"product_id\":1,\"quantity\":2}],\"total\":100.00}"
    local response=$(http_request "POST" "/api/v1/orders" "$order_data" "201")
    if [ $? -eq 0 ]; then
        log_test "PASS" "创建订单" "创建成功"
    else
        log_test "FAIL" "创建订单" "$response"
    fi
    
    # 测试订单服务健康检查
    local response=$(http_request "GET" "/health/order" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "订单服务健康检查" "$response"
    else
        log_test "FAIL" "订单服务健康检查" "$response"
    fi
}

# 测试通知服务
test_notification_service() {
    log_header "测试通知服务"
    
    if [ -z "$JWT_TOKEN" ]; then
        log_test "SKIP" "通知服务测试" "需要用户认证"
        return 0
    fi
    
    # 测试获取通知列表
    local response=$(http_request "GET" "/api/v1/notifications" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "获取通知列表" "获取成功"
    else
        log_test "FAIL" "获取通知列表" "$response"
    fi
    
    # 测试获取通知模板
    local response=$(http_request "GET" "/api/v1/templates" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "获取通知模板" "获取成功"
    else
        log_test "FAIL" "获取通知模板" "$response"
    fi
    
    # 测试通知服务健康检查
    local response=$(http_request "GET" "/health/notification" "" "200")
    if [ $? -eq 0 ]; then
        log_test "PASS" "通知服务健康检查" "$response"
    else
        log_test "FAIL" "通知服务健康检查" "$response"
    fi
}

# 生成测试报告
generate_test_report() {
    if [ "$SAVE_RESULTS" = false ]; then
        return 0
    fi
    
    local report_dir="$PROJECT_DIR/.taskmaster/reports"
    local report_file="$report_dir/api-test-report-$(date +%Y%m%d-%H%M%S).json"
    
    mkdir -p "$report_dir"
    
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "base_url": "$BASE_URL",
  "test_summary": {
    "total": $TOTAL_TESTS,
    "passed": $PASSED_TESTS,
    "failed": $FAILED_TESTS,
    "skipped": $SKIPPED_TESTS,
    "success_rate": "$(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")%"
  },
  "test_config": {
    "timeout": $TIMEOUT,
    "verbose": $VERBOSE,
    "test_user": "$TEST_USER_EMAIL"
  }
}
EOF
    
    log_success "测试报告已保存: $report_file"
}

# 主函数
main() {
    parse_args "$@"
    
    log_header "微服务API测试开始"
    
    # 检测API URL
    detect_api_url
    
    # 执行测试
    test_gateway_health
    test_user_service
    test_product_service
    test_order_service
    test_notification_service
    
    # 生成报告
    generate_test_report
    
    # 输出测试总结
    log_header "测试总结"
    
    echo -e "${BLUE}测试统计:${NC}"
    echo "  总测试数: $TOTAL_TESTS"
    echo -e "  通过: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "  失败: ${RED}$FAILED_TESTS${NC}"
    echo -e "  跳过: ${YELLOW}$SKIPPED_TESTS${NC}"
    
    if [ $TOTAL_TESTS -gt 0 ]; then
        local success_rate=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
        echo -e "  成功率: ${CYAN}$success_rate%${NC}"
    fi
    
    echo
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "🎉 所有测试通过！"
        exit 0
    else
        log_warning "⚠️  发现 $FAILED_TESTS 个测试失败"
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
