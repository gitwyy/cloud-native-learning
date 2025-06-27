#!/bin/bash

# 云原生日志收集与分析项目清理脚本
# 用于清理所有部署的组件和资源

set -e

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

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到 Kubernetes 集群"
        exit 1
    fi
    
    log_success "kubectl 连接正常"
}

# 清理应用服务
cleanup_applications() {
    log_info "清理应用服务..."
    
    # 清理用户服务
    if kubectl get deployment user-service &> /dev/null; then
        kubectl delete deployment user-service
        log_success "删除 user-service deployment"
    fi
    
    if kubectl get service user-service &> /dev/null; then
        kubectl delete service user-service
        log_success "删除 user-service service"
    fi
    
    if kubectl get configmap user-service-config &> /dev/null; then
        kubectl delete configmap user-service-config
        log_success "删除 user-service-config configmap"
    fi
}

# 清理 Jaeger 追踪系统
cleanup_jaeger() {
    log_info "清理 Jaeger 追踪系统..."
    
    # 删除 Jaeger 部署
    kubectl delete -f ../manifests/jaeger/ --ignore-not-found=true
    
    # 删除简化版本的 Jaeger（如果存在）
    if kubectl get deployment jaeger -n tracing &> /dev/null; then
        kubectl delete deployment jaeger -n tracing
    fi
    
    if kubectl get service jaeger-query -n tracing &> /dev/null; then
        kubectl delete service jaeger-query -n tracing
    fi
    
    if kubectl get service jaeger-collector -n tracing &> /dev/null; then
        kubectl delete service jaeger-collector -n tracing
    fi
    
    if kubectl get service jaeger-agent -n tracing &> /dev/null; then
        kubectl delete service jaeger-agent -n tracing
    fi
    
    if kubectl get service jaeger-query-nodeport -n tracing &> /dev/null; then
        kubectl delete service jaeger-query-nodeport -n tracing
    fi
    
    log_success "Jaeger 组件清理完成"
}

# 清理 Kibana
cleanup_kibana() {
    log_info "清理 Kibana..."
    
    # 删除 Kibana 部署
    kubectl delete -f ../manifests/kibana/ --ignore-not-found=true
    
    # 删除简化版本的 Kibana（如果存在）
    if kubectl get deployment kibana -n logging &> /dev/null; then
        kubectl delete deployment kibana -n logging
    fi
    
    if kubectl get service kibana -n logging &> /dev/null; then
        kubectl delete service kibana -n logging
    fi
    
    if kubectl get service kibana-nodeport -n logging &> /dev/null; then
        kubectl delete service kibana-nodeport -n logging
    fi
    
    if kubectl get configmap kibana-config -n logging &> /dev/null; then
        kubectl delete configmap kibana-config -n logging
    fi
    
    log_success "Kibana 清理完成"
}

# 清理 Fluent Bit
cleanup_fluentbit() {
    log_info "清理 Fluent Bit..."
    
    # 删除 Fluent Bit 部署
    kubectl delete -f ../manifests/fluent-bit/ --ignore-not-found=true
    
    # 删除简化版本的 Fluent Bit（如果存在）
    if kubectl get daemonset fluent-bit -n logging &> /dev/null; then
        kubectl delete daemonset fluent-bit -n logging
    fi
    
    if kubectl get service fluent-bit -n logging &> /dev/null; then
        kubectl delete service fluent-bit -n logging
    fi
    
    if kubectl get configmap fluent-bit-config -n logging &> /dev/null; then
        kubectl delete configmap fluent-bit-config -n logging
    fi
    
    if kubectl get serviceaccount fluent-bit -n logging &> /dev/null; then
        kubectl delete serviceaccount fluent-bit -n logging
    fi
    
    if kubectl get clusterrole fluent-bit-read &> /dev/null; then
        kubectl delete clusterrole fluent-bit-read
    fi
    
    if kubectl get clusterrolebinding fluent-bit-read &> /dev/null; then
        kubectl delete clusterrolebinding fluent-bit-read
    fi
    
    log_success "Fluent Bit 清理完成"
}

# 清理 Elasticsearch
cleanup_elasticsearch() {
    log_info "清理 Elasticsearch..."
    
    # 删除 Elasticsearch 部署
    kubectl delete -f ../manifests/elasticsearch/ --ignore-not-found=true
    
    # 删除简化版本的 Elasticsearch（如果存在）
    if kubectl get deployment elasticsearch -n logging &> /dev/null; then
        kubectl delete deployment elasticsearch -n logging
    fi
    
    if kubectl get service elasticsearch -n logging &> /dev/null; then
        kubectl delete service elasticsearch -n logging
    fi
    
    if kubectl get service elasticsearch-nodeport -n logging &> /dev/null; then
        kubectl delete service elasticsearch-nodeport -n logging
    fi
    
    if kubectl get configmap elasticsearch-config -n logging &> /dev/null; then
        kubectl delete configmap elasticsearch-config -n logging
    fi
    
    # 清理 PVC（如果存在）
    kubectl delete pvc -n logging --all --ignore-not-found=true
    
    log_success "Elasticsearch 清理完成"
}

# 清理命名空间
cleanup_namespaces() {
    log_info "清理命名空间..."
    
    # 等待所有资源删除完成
    sleep 10
    
    # 删除 logging 命名空间
    if kubectl get namespace logging &> /dev/null; then
        kubectl delete namespace logging
        log_success "删除 logging 命名空间"
    fi
    
    # 删除 tracing 命名空间
    if kubectl get namespace tracing &> /dev/null; then
        kubectl delete namespace tracing
        log_success "删除 tracing 命名空间"
    fi
}

# 清理 Docker 镜像（可选）
cleanup_docker_images() {
    log_info "清理 Docker 镜像..."
    
    # 检查是否有 minikube
    if command -v minikube &> /dev/null; then
        # 删除用户服务镜像
        if minikube image ls | grep -q "user-service:latest"; then
            minikube image rm user-service:latest || log_warning "无法删除 user-service 镜像"
            log_success "删除 user-service Docker 镜像"
        fi
    fi
    
    # 删除本地 Docker 镜像
    if command -v docker &> /dev/null; then
        if docker images | grep -q "user-service"; then
            docker rmi user-service:latest || log_warning "无法删除本地 user-service 镜像"
            log_success "删除本地 user-service Docker 镜像"
        fi
    fi
}

# 清理端口转发进程
cleanup_port_forwards() {
    log_info "清理端口转发进程..."
    
    # 查找并终止 kubectl port-forward 进程
    pkill -f "kubectl port-forward" || log_warning "没有找到运行中的端口转发进程"
    
    log_success "端口转发进程清理完成"
}

# 主清理函数
main() {
    log_info "开始清理云原生日志收集与分析项目..."
    
    # 检查前置条件
    check_kubectl
    
    # 清理端口转发进程
    cleanup_port_forwards
    
    # 清理应用服务
    cleanup_applications
    
    # 清理 Jaeger
    cleanup_jaeger
    
    # 清理 Kibana
    cleanup_kibana
    
    # 清理 Fluent Bit
    cleanup_fluentbit
    
    # 清理 Elasticsearch
    cleanup_elasticsearch
    
    # 清理命名空间
    cleanup_namespaces
    
    # 清理 Docker 镜像（可选）
    read -p "是否清理 Docker 镜像？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_docker_images
    fi
    
    log_success "清理完成！"
    log_info "所有组件已从集群中删除"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
