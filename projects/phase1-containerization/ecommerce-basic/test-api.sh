#!/bin/bash

# ==============================================================================
# 电商应用基础版 - API测试脚本
# 测试所有微服务的主要API端点
# ==============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
BASE_URL="http://localhost"
USER_SERVICE_URL="$BASE_URL:5001"
PRODUCT_SERVICE_URL="$BASE_URL:5002"
ORDER_SERVICE_URL="$BASE_URL:5003"
NOTIFICATION_SERVICE_URL="$BASE_URL:5004"

# 测试计数器
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# 测试用户ID和JWT Token（在实际测试中会动态获取）
USER_ID=""
JWT_TOKEN=""

print_title() {
    echo
    echo -e "${CYAN}🧪 ================================${NC}"
    echo -e "${CYAN}   $1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

print_test() {
    echo -e "${BLUE}📋 测试: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 执行HTTP请求并检查响应
test_request() {
    local method=$1
    local url=$2
    local data=$3
    local expected_status=${4:-200}
    local description=$5
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_test "$description"
    
    local headers=""
    if [ ! -z "$JWT_TOKEN" ]; then
        headers="-H 'Authorization: Bearer $JWT_TOKEN'"
    fi
    
    if [ "$method" = "POST" ] || [ "$method" = "PUT" ]; then
        headers="$headers -H 'Content-Type: application/json'"
    fi
    
    local cmd="curl -s -w '%{http_code}' -o /tmp/api_response.json"
    if [ ! -z "$data" ]; then
        cmd="$cmd -d '$data'"
    fi
    
    if [ ! -z "$headers" ]; then
        cmd="$cmd $headers"
    fi
    
    cmd="$cmd -X $method '$url'"
    
    local status_code=$(eval $cmd)
    local response=$(cat /tmp/api_response.json 2>/dev/null || echo "{}")
    
    if [ "$status_code" = "$expected_status" ]; then
        print_success "$description - 状态码: $status_code"
        echo "   响应: $(echo $response | jq -c . 2>/dev/null || echo $response)"
    else
        print_error "$description - 期望: $expected_status, 实际: $status_code"
        echo "   响应: $(echo $response | jq -c . 2>/dev/null || echo $response)"
    fi
    
    echo "$response"
}

# 等待服务启动
wait_for_services() {
    print_title "等待服务启动"
    
    local services=("$BASE_URL/health" "$USER_SERVICE_URL/health" "$PRODUCT_SERVICE_URL/health" "$ORDER_SERVICE_URL/health" "$NOTIFICATION_SERVICE_URL/health")
    local max_retries=30
    local retry_count=0
    
    for service in "${services[@]}"; do
        echo -n "等待 $service "
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
            if curl -sf "$service" > /dev/null 2>&1; then
                echo -e " ${GREEN}✅${NC}"
                break
            else
                echo -n "."
                sleep 2
                retry_count=$((retry_count + 1))
            fi
        done
        
        if [ $retry_count -eq $max_retries ]; then
            echo -e " ${RED}❌ 超时${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}🎉 所有服务已启动${NC}"
}

# 测试用户服务
test_user_service() {
    print_title "测试用户服务"
    
    # 用户注册
    local register_data='{
        "username": "testuser",
        "email": "test@example.com",
        "password": "password123",
        "first_name": "Test",
        "last_name": "User"
    }'
    
    local register_response=$(test_request "POST" "$USER_SERVICE_URL/api/v1/register" "$register_data" "201" "用户注册")
    USER_ID=$(echo $register_response | jq -r '.user.id' 2>/dev/null || echo "")
    
    # 用户登录
    local login_data='{
        "username": "testuser",
        "password": "password123"
    }'
    
    local login_response=$(test_request "POST" "$USER_SERVICE_URL/api/v1/login" "$login_data" "200" "用户登录")
    JWT_TOKEN=$(echo $login_response | jq -r '.access_token' 2>/dev/null || echo "")
    
    # 获取用户信息
    test_request "GET" "$USER_SERVICE_URL/api/v1/profile" "" "200" "获取用户信息"
    
    # 更新用户信息
    local update_data='{
        "first_name": "Updated",
        "phone": "1234567890"
    }'
    
    test_request "PUT" "$USER_SERVICE_URL/api/v1/profile" "$update_data" "200" "更新用户信息"
    
    # 获取用户统计
    test_request "GET" "$USER_SERVICE_URL/api/v1/stats" "" "200" "获取用户统计"
}

# 测试商品服务
test_product_service() {
    print_title "测试商品服务"
    
    # 获取分类列表
    test_request "GET" "$PRODUCT_SERVICE_URL/api/v1/categories" "" "200" "获取分类列表"
    
    # 获取商品列表
    test_request "GET" "$PRODUCT_SERVICE_URL/api/v1/products" "" "200" "获取商品列表"
    
    # 搜索商品
    test_request "GET" "$PRODUCT_SERVICE_URL/api/v1/products/search?q=iPhone" "" "200" "搜索商品"
    
    # 获取商品详情（假设有ID为1的商品）
    test_request "GET" "$PRODUCT_SERVICE_URL/api/v1/products/1" "" "200" "获取商品详情"
    
    # 获取商品统计
    test_request "GET" "$PRODUCT_SERVICE_URL/api/v1/stats" "" "200" "获取商品统计"
}

# 测试订单服务
test_order_service() {
    print_title "测试订单服务"
    
    if [ -z "$USER_ID" ]; then
        print_warning "跳过订单测试：用户ID不可用"
        return
    fi
    
    # 创建订单
    local order_data="{
        \"user_id\": $USER_ID,
        \"items\": [
            {
                \"product_id\": 1,
                \"quantity\": 2
            }
        ],
        \"shipping_address\": \"123 Test Street\",
        \"shipping_city\": \"Test City\",
        \"shipping_country\": \"China\",
        \"recipient_name\": \"Test User\",
        \"recipient_phone\": \"1234567890\"
    }"
    
    local order_response=$(test_request "POST" "$ORDER_SERVICE_URL/api/v1/orders" "$order_data" "201" "创建订单")
    local order_id=$(echo $order_response | jq -r '.order.id' 2>/dev/null || echo "")
    
    # 获取订单列表
    test_request "GET" "$ORDER_SERVICE_URL/api/v1/orders?user_id=$USER_ID" "" "200" "获取订单列表"
    
    # 获取订单详情
    if [ ! -z "$order_id" ] && [ "$order_id" != "null" ]; then
        test_request "GET" "$ORDER_SERVICE_URL/api/v1/orders/$order_id?user_id=$USER_ID" "" "200" "获取订单详情"
        
        # 支付订单
        local payment_data='{
            "payment_method": "card",
            "amount": 100.00
        }'
        test_request "POST" "$ORDER_SERVICE_URL/api/v1/orders/$order_id/pay" "$payment_data" "200" "支付订单"
    fi
    
    # 获取订单统计
    test_request "GET" "$ORDER_SERVICE_URL/api/v1/stats" "" "200" "获取订单统计"
}

# 测试通知服务
test_notification_service() {
    print_title "测试通知服务"
    
    # 获取通知模板
    test_request "GET" "$NOTIFICATION_SERVICE_URL/api/v1/templates" "" "200" "获取通知模板"
    
    # 创建通知
    local notification_data='{
        "type": "email",
        "recipient": "test@example.com",
        "subject": "测试通知",
        "content": "这是一个测试通知"
    }'
    
    test_request "POST" "$NOTIFICATION_SERVICE_URL/api/v1/notifications" "$notification_data" "201" "创建通知"
    
    # 获取通知列表
    test_request "GET" "$NOTIFICATION_SERVICE_URL/api/v1/notifications" "" "200" "获取通知列表"
    
    # 获取通知统计
    test_request "GET" "$NOTIFICATION_SERVICE_URL/api/v1/stats" "" "200" "获取通知统计"
}

# 测试Nginx代理
test_nginx_proxy() {
    print_title "测试Nginx代理"
    
    # 测试主页
    test_request "GET" "$BASE_URL/" "" "200" "访问主页"
    
    # 测试健康检查
    test_request "GET" "$BASE_URL/health" "" "200" "Nginx健康检查"
    
    # 测试服务健康检查代理
    test_request "GET" "$BASE_URL/health/user" "" "200" "用户服务健康检查代理"
    test_request "GET" "$BASE_URL/health/product" "" "200" "商品服务健康检查代理"
    test_request "GET" "$BASE_URL/health/order" "" "200" "订单服务健康检查代理"
    test_request "GET" "$BASE_URL/health/notification" "" "200" "通知服务健康检查代理"
    
    # 测试统计信息代理
    test_request "GET" "$BASE_URL/stats/user" "" "200" "用户统计代理"
    test_request "GET" "$BASE_URL/stats/product" "" "200" "商品统计代理"
    test_request "GET" "$BASE_URL/stats/order" "" "200" "订单统计代理"
    test_request "GET" "$BASE_URL/stats/notification" "" "200" "通知统计代理"
}

# 显示测试结果
show_results() {
    print_title "测试结果"
    
    echo -e "${CYAN}📊 测试统计:${NC}"
    echo -e "  总计: $TESTS_TOTAL"
    echo -e "  ${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "  ${RED}失败: $TESTS_FAILED${NC}"
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo -e "  成功率: $success_rate%"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 所有测试通过！${NC}"
        exit 0
    else
        echo -e "${RED}❌ 有测试失败，请检查服务状态${NC}"
        exit 1
    fi
}

# 清理临时文件
cleanup() {
    rm -f /tmp/api_response.json
}

# 主函数
main() {
    echo -e "${CYAN}🧪 电商应用基础版 - API测试${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
    
    # 检查依赖
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl 未安装${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️  jq 未安装，JSON响应显示可能不够美观${NC}"
    fi
    
    # 设置清理陷阱
    trap cleanup EXIT
    
    # 等待服务启动
    wait_for_services
    
    # 运行测试
    test_nginx_proxy
    test_user_service
    test_product_service
    test_order_service
    test_notification_service
    
    # 显示结果
    show_results
}

# 脚本入口
main "$@"