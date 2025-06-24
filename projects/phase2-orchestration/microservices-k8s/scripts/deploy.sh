#!/bin/bash

# ==============================================================================
# 微服务Kubernetes部署脚本
# 自动化部署电商微服务应用到Kubernetes集群
# ==============================================================================

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="ecommerce-k8s"
ECOMMERCE_BASIC_PATH="../../phase1-containerization/ecommerce-basic"

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

# 检查前置条件
check_prerequisites() {
    log_header "检查前置条件"
    
    # 检查kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl未安装，请先安装kubectl"
        exit 1
    fi
    log_success "kubectl已安装: $(kubectl version --client --short 2>/dev/null || echo '版本未知')"
    
    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群，请检查kubeconfig配置"
        exit 1
    fi
    log_success "Kubernetes集群连接正常"
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        log_success "Docker已安装: $(docker --version 2>/dev/null || echo '版本未知')"
    else
        log_warning "Docker未安装，可能无法构建镜像"
    fi
    
    # 检查第一阶段项目
    if [ ! -d "$PROJECT_DIR/$ECOMMERCE_BASIC_PATH" ]; then
        log_error "找不到第一阶段项目: $PROJECT_DIR/$ECOMMERCE_BASIC_PATH"
        log_error "请确保已完成第一阶段ecommerce-basic项目"
        exit 1
    fi
    log_success "第一阶段项目路径验证通过"
}

# 构建镜像
build_images() {
    log_header "构建微服务镜像"
    
    cd "$PROJECT_DIR/$ECOMMERCE_BASIC_PATH"
    
    # 如果使用Minikube，配置Docker环境
    if command -v minikube &> /dev/null && minikube status &> /dev/null 2>&1; then
        log_info "检测到Minikube，配置Docker环境..."
        eval $(minikube docker-env)
        log_success "Minikube Docker环境配置完成"
    fi
    
    # 构建镜像
    log_info "开始构建微服务镜像..."
    if make build; then
        log_success "微服务镜像构建完成"
    else
        log_error "镜像构建失败"
        exit 1
    fi
    
    # 验证镜像
    log_info "验证镜像是否存在..."
    local missing_images=()
    for service in user-service product-service order-service notification-service; do
        if ! docker images | grep -q "$service"; then
            missing_images+=("$service")
        fi
    done
    
    if [ ${#missing_images[@]} -gt 0 ]; then
        log_error "以下镜像构建失败: ${missing_images[*]}"
        exit 1
    fi
    
    log_success "所有微服务镜像验证通过"
    cd "$PROJECT_DIR"
}

# 创建命名空间
create_namespace() {
    log_header "创建命名空间"
    
    log_info "创建命名空间: $NAMESPACE"
    kubectl apply -f k8s/namespace/
    
    # 等待命名空间创建完成
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_success "命名空间 $NAMESPACE 创建成功"
    else
        log_error "命名空间创建失败"
        exit 1
    fi
}

# 部署密钥和配置
deploy_configs() {
    log_header "部署配置和密钥"
    
    log_info "部署Secret配置..."
    kubectl apply -f k8s/secrets/
    
    log_info "部署ConfigMap配置..."
    kubectl apply -f k8s/configmaps/
    
    # 验证配置
    local configs_ready=0
    local max_retries=30
    local retry_count=0
    
    while [ $configs_ready -eq 0 ] && [ $retry_count -lt $max_retries ]; do
        if kubectl get secrets,configmaps -n "$NAMESPACE" &> /dev/null; then
            configs_ready=1
            log_success "配置和密钥部署完成"
        else
            log_info "等待配置创建完成..."
            sleep 2
            retry_count=$((retry_count + 1))
        fi
    done
    
    if [ $configs_ready -eq 0 ]; then
        log_error "配置部署超时"
        exit 1
    fi
}

# 部署存储
deploy_storage() {
    log_header "部署持久化存储"
    
    log_info "创建PVC..."
    kubectl apply -f k8s/storage/
    
    # 等待PVC创建完成
    log_info "等待PVC就绪..."
    local storage_ready=0
    local max_retries=60
    local retry_count=0
    
    while [ $storage_ready -eq 0 ] && [ $retry_count -lt $max_retries ]; do
        local pending_pvcs=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Pending" || echo "0")
        if [ "$pending_pvcs" -eq 0 ]; then
            storage_ready=1
            log_success "持久化存储部署完成"
        else
            log_info "等待PVC绑定... (剩余: $pending_pvcs)"
            sleep 3
            retry_count=$((retry_count + 1))
        fi
    done
    
    if [ $storage_ready -eq 0 ]; then
        log_warning "部分PVC可能仍在Pending状态，继续部署..."
    fi
}

# 部署基础设施服务
deploy_infrastructure() {
    log_header "部署基础设施服务"
    
    log_info "部署PostgreSQL..."
    kubectl apply -f k8s/infrastructure/postgres.yaml
    
    log_info "部署Redis..."
    kubectl apply -f k8s/infrastructure/redis.yaml

    log_info "部署RabbitMQ..."
    kubectl apply -f k8s/infrastructure/rabbitmq.yaml
    
    # 等待基础设施服务就绪
    log_info "等待基础设施服务启动..."
    local max_wait=300
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        local ready_pods=$(kubectl get pods -n "$NAMESPACE" -l tier=infrastructure --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
        local total_pods=$(kubectl get pods -n "$NAMESPACE" -l tier=infrastructure --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            log_success "基础设施服务部署完成 ($ready_pods/$total_pods)"
            break
        else
            log_info "等待基础设施服务就绪... ($ready_pods/$total_pods) [${waited}s/${max_wait}s]"
            sleep 10
            waited=$((waited + 10))
        fi
    done
    
    if [ $waited -ge $max_wait ]; then
        log_warning "基础设施服务启动超时，继续部署微服务..."
    fi
}

# 部署微服务
deploy_microservices() {
    log_header "部署微服务应用"
    
    log_info "部署用户服务..."
    kubectl apply -f k8s/microservices/user-service.yaml

    log_info "部署商品服务..."
    kubectl apply -f k8s/microservices/product-service.yaml

    log_info "部署订单服务..."
    kubectl apply -f k8s/microservices/order-service.yaml

    log_info "部署通知服务..."
    kubectl apply -f k8s/microservices/notification-service.yaml
    
    # 等待微服务就绪
    log_info "等待微服务启动..."
    local max_wait=300
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        local ready_pods=$(kubectl get pods -n "$NAMESPACE" -l tier=backend --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
        local total_pods=$(kubectl get pods -n "$NAMESPACE" -l tier=backend --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            log_success "微服务应用部署完成 ($ready_pods/$total_pods)"
            break
        else
            log_info "等待微服务就绪... ($ready_pods/$total_pods) [${waited}s/${max_wait}s]"
            sleep 15
            waited=$((waited + 15))
        fi
    done
    
    if [ $waited -ge $max_wait ]; then
        log_warning "微服务启动超时，继续部署网关..."
    fi
}

# 部署API网关
deploy_gateway() {
    log_header "部署API网关"
    
    log_info "部署API网关..."
    kubectl apply -f k8s/gateway/
    
    # 等待网关就绪
    log_info "等待API网关启动..."
    if kubectl wait --for=condition=ready pod -l app=api-gateway -n "$NAMESPACE" --timeout=120s 2>/dev/null; then
        log_success "API网关部署完成"
    else
        log_warning "API网关启动可能需要更多时间"
    fi
}

# 显示部署状态
show_deployment_status() {
    log_header "部署状态检查"
    
    echo -e "${BLUE}📊 Pod状态:${NC}"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo
    
    echo -e "${BLUE}🌐 服务状态:${NC}"
    kubectl get services -n "$NAMESPACE"
    echo
    
    echo -e "${BLUE}📦 存储状态:${NC}"
    kubectl get pvc -n "$NAMESPACE" 2>/dev/null || echo "无PVC"
    echo
    
    echo -e "${BLUE}📈 HPA状态:${NC}"
    kubectl get hpa -n "$NAMESPACE" 2>/dev/null || echo "无HPA配置"
    echo
}

# 获取访问地址
get_access_url() {
    log_header "获取访问地址"
    
    # 检查Minikube
    if command -v minikube &> /dev/null && minikube status &> /dev/null 2>&1; then
        local url=$(minikube service api-gateway -n "$NAMESPACE" --url 2>/dev/null)
        if [ -n "$url" ]; then
            echo -e "${GREEN}🌍 Minikube访问地址: $url${NC}"
        else
            log_warning "无法获取Minikube服务地址"
        fi
    fi
    
    # 检查NodePort
    local node_port=$(kubectl get service api-gateway -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    if [ -n "$node_port" ]; then
        echo -e "${GREEN}🌍 NodePort访问地址: http://<节点IP>:$node_port${NC}"
    fi
    
    echo
    echo -e "${BLUE}💡 其他访问方式:${NC}"
    echo "端口转发: kubectl port-forward service/api-gateway 8080:80 -n $NAMESPACE"
    echo "然后访问: http://localhost:8080"
}

# 健康检查
health_check() {
    log_header "健康检查"
    
    local healthy_count=0
    local total_count=0
    
    # 检查各组件状态
    for component in postgres redis rabbitmq user-service product-service order-service notification-service api-gateway; do
        total_count=$((total_count + 1))
        if kubectl get pods -l app="$component" -n "$NAMESPACE" 2>/dev/null | grep -q "1/1.*Running"; then
            echo -e "  $component: ${GREEN}✅ 健康${NC}"
            healthy_count=$((healthy_count + 1))
        else
            echo -e "  $component: ${RED}❌ 异常${NC}"
        fi
    done
    
    echo
    if [ $healthy_count -eq $total_count ]; then
        log_success "所有组件健康 ($healthy_count/$total_count)"
    else
        log_warning "部分组件异常 ($healthy_count/$total_count)"
    fi
}

# 清理函数（错误时调用）
cleanup_on_error() {
    log_error "部署过程中出现错误"
    echo
    echo -e "${YELLOW}可以查看以下信息进行故障排查:${NC}"
    echo "1. kubectl get events -n $NAMESPACE --sort-by=.metadata.creationTimestamp"
    echo "2. kubectl describe pods -n $NAMESPACE"
    echo "3. kubectl logs -l tier=backend -n $NAMESPACE"
    echo
    echo -e "${BLUE}清理命令:${NC}"
    echo "kubectl delete namespace $NAMESPACE"
}

# 主部署流程
main() {
    log_header "微服务Kubernetes部署开始"
    
    # 设置错误处理
    trap cleanup_on_error ERR
    
    # 执行部署步骤
    check_prerequisites
    build_images
    create_namespace
    deploy_configs
    deploy_storage
    deploy_infrastructure
    deploy_microservices
    deploy_gateway
    
    # 显示结果
    show_deployment_status
    get_access_url
    health_check
    
    log_header "部署完成"
    log_success "🎉 微服务应用已成功部署到Kubernetes集群！"
    echo
    echo -e "${BLUE}后续操作建议:${NC}"
    echo "1. 运行健康检查: ./scripts/health-check.sh"
    echo "2. 查看日志: ./scripts/logs.sh"
    echo "3. 运行API测试: ./tests/api-tests.sh"
    echo "4. 扩缩容测试: ./scripts/scale.sh user-service 5"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi