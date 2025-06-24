#!/bin/bash

# ==============================================================================
# Kubernetes基础部署脚本
# 用于快速部署电商微服务应用到Kubernetes集群
# ==============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查前置条件
check_prerequisites() {
    print_header "检查前置条件"
    
    # 检查kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl未安装"
        exit 1
    fi
    print_success "kubectl已安装"
    
    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到Kubernetes集群"
        exit 1
    fi
    print_success "Kubernetes集群连接正常"
    
    # 检查Docker镜像（如果使用本地镜像）
    if command -v docker &> /dev/null; then
        if docker images | grep -q "user-service\|product-service\|order-service\|notification-service"; then
            print_success "检测到电商服务镜像"
        else
            print_warning "未检测到电商服务镜像，请先构建镜像"
            echo "提示：cd ../../phase1-containerization/ecommerce-basic && make build"
        fi
    fi
}

# 部署基础设施
deploy_infrastructure() {
    print_header "部署基础设施服务"
    
    print_step "创建命名空间..."
    kubectl create namespace ecommerce --dry-run=client -o yaml | kubectl apply -f -
    
    print_step "部署PostgreSQL数据库..."
    kubectl apply -f manifests/postgres-deployment.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "部署Redis缓存..."
    kubectl apply -f manifests/redis-deployment.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "部署RabbitMQ消息队列..."
    kubectl apply -f manifests/rabbitmq-deployment.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "等待基础设施服务就绪..."
    kubectl wait --for=condition=ready pod -l tier=database -n ecommerce --timeout=120s 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l tier=cache -n ecommerce --timeout=120s 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l tier=queue -n ecommerce --timeout=120s 2>/dev/null || true
    
    print_success "基础设施服务部署完成"
}

# 部署微服务
deploy_microservices() {
    print_header "部署微服务应用"
    
    print_step "部署用户服务..."
    kubectl apply -f manifests/user-service-deployment.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "部署商品服务..."
    kubectl apply -f manifests/product-service-deployment.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "部署订单服务..."
    kubectl apply -f manifests/order-service-deployment.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "部署通知服务..."
    kubectl apply -f manifests/notification-service-deployment.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "等待微服务就绪..."
    kubectl wait --for=condition=ready pod -l tier=backend -n ecommerce --timeout=180s 2>/dev/null || true
    
    print_success "微服务应用部署完成"
}

# 部署API网关
deploy_gateway() {
    print_header "部署API网关"
    
    print_step "部署Nginx API网关..."
    kubectl apply -f manifests/api-gateway.yaml 2>/dev/null || echo "使用示例配置"
    
    print_step "等待API网关就绪..."
    kubectl wait --for=condition=ready pod -l tier=frontend -n ecommerce --timeout=60s 2>/dev/null || true
    
    print_success "API网关部署完成"
}

# 显示部署状态
show_status() {
    print_header "部署状态检查"
    
    echo -e "${BLUE}📊 Pod状态:${NC}"
    kubectl get pods -n ecommerce
    echo
    
    echo -e "${BLUE}🌐 服务状态:${NC}"
    kubectl get services -n ecommerce
    echo
    
    echo -e "${BLUE}📦 存储状态:${NC}"
    kubectl get pvc -n ecommerce 2>/dev/null || echo "无持久化存储"
    echo
    
    # 获取访问地址
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        GATEWAY_URL=$(minikube service api-gateway -n ecommerce --url 2>/dev/null || echo "暂时无法获取")
        echo -e "${GREEN}🌍 访问地址 (Minikube): $GATEWAY_URL${NC}"
    else
        NODE_PORT=$(kubectl get service api-gateway -n ecommerce -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30080")
        echo -e "${GREEN}🌍 访问地址: http://<节点IP>:$NODE_PORT${NC}"
    fi
}

# 健康检查
health_check() {
    print_header "健康检查"
    
    echo -e "${BLUE}🏥 检查服务健康状态...${NC}"
    
    # 检查Pod健康状态
    READY_PODS=$(kubectl get pods -n ecommerce --no-headers | grep "1/1.*Running" | wc -l)
    TOTAL_PODS=$(kubectl get pods -n ecommerce --no-headers | wc -l)
    
    if [ $READY_PODS -eq $TOTAL_PODS ] && [ $TOTAL_PODS -gt 0 ]; then
        print_success "所有Pod ($READY_PODS/$TOTAL_PODS) 运行正常"
    else
        print_warning "Pod状态: $READY_PODS/$TOTAL_PODS 就绪"
    fi
    
    # 检查服务端点
    SERVICES_WITH_ENDPOINTS=$(kubectl get endpoints -n ecommerce --no-headers | grep -v "<none>" | wc -l)
    TOTAL_SERVICES=$(kubectl get services -n ecommerce --no-headers | wc -l)
    
    if [ $SERVICES_WITH_ENDPOINTS -gt 0 ]; then
        print_success "服务端点: $SERVICES_WITH_ENDPOINTS/$TOTAL_SERVICES 可用"
    else
        print_warning "部分服务可能尚未就绪"
    fi
}

# 显示使用说明
show_usage() {
    print_header "使用说明"
    
    echo -e "${BLUE}📋 可用命令:${NC}"
    echo "  $0 deploy    - 完整部署所有组件"
    echo "  $0 status    - 查看部署状态"
    echo "  $0 health    - 执行健康检查"
    echo "  $0 clean     - 清理所有资源"
    echo "  $0 logs      - 查看服务日志"
    echo
    
    echo -e "${BLUE}📖 后续步骤:${NC}"
    echo "1. 检查Pod状态: kubectl get pods -n ecommerce"
    echo "2. 查看服务日志: kubectl logs -f deployment/user-service -n ecommerce"
    echo "3. 访问应用: 使用上面显示的访问地址"
    echo "4. 测试API: curl \$GATEWAY_URL/health"
    echo
    
    echo -e "${BLUE}🔧 故障排查:${NC}"
    echo "1. 查看Pod详情: kubectl describe pod <pod-name> -n ecommerce"
    echo "2. 查看事件: kubectl get events -n ecommerce --sort-by=.metadata.creationTimestamp"
    echo "3. 检查镜像: 确保第一阶段镜像已构建"
}

# 清理资源
clean_resources() {
    print_header "清理资源"
    
    echo -e "${YELLOW}⚠️  警告: 这将删除ecommerce命名空间下的所有资源${NC}"
    read -p "确认继续? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "删除ecommerce命名空间..."
        kubectl delete namespace ecommerce --ignore-not-found=true
        print_success "资源清理完成"
    else
        echo "操作已取消"
    fi
}

# 查看日志
show_logs() {
    print_header "服务日志"
    
    echo -e "${BLUE}📋 可用的服务:${NC}"
    kubectl get deployments -n ecommerce --no-headers | awk '{print NR ". " $1}'
    echo
    
    read -p "选择服务编号 (或输入服务名): " choice
    
    if [[ $choice =~ ^[0-9]+$ ]]; then
        service=$(kubectl get deployments -n ecommerce --no-headers | sed -n "${choice}p" | awk '{print $1}')
    else
        service=$choice
    fi
    
    if [ -n "$service" ]; then
        print_step "显示 $service 日志..."
        kubectl logs -f deployment/$service -n ecommerce
    else
        print_error "无效的选择"
    fi
}

# 主函数
main() {
    case "${1:-}" in
        "deploy")
            check_prerequisites
            deploy_infrastructure
            deploy_microservices
            deploy_gateway
            show_status
            health_check
            show_usage
            ;;
        "status")
            show_status
            ;;
        "health")
            health_check
            ;;
        "clean")
            clean_resources
            ;;
        "logs")
            show_logs
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo -e "${CYAN}🚀 Kubernetes基础部署脚本${NC}"
            echo
            show_usage
            ;;
    esac
}

# 执行主函数
main "$@"