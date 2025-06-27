#!/bin/bash

# 日志收集与链路追踪系统一键部署脚本
# 部署 EFK Stack + Jaeger 完整可观测性解决方案

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

# 检查DNS状态
check_dns_status() {
    log_info "检查DNS服务状态..."

    # 检查是否有DNS相关的Pod
    local dns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)

    if [ "$dns_pods" -eq 0 ]; then
        log_warning "未找到DNS服务，将使用Pod IP进行服务发现"
        return 1
    else
        log_success "找到DNS服务"
        return 0
    fi
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."

    # 检查 kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi

    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到 Kubernetes 集群"
        exit 1
    fi

    # 检查节点资源
    local nodes=$(kubectl get nodes --no-headers | wc -l)
    if [ $nodes -lt 1 ]; then
        log_error "集群中没有可用节点"
        exit 1
    fi

    # 检查 Docker（用于构建镜像）
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在 PATH 中"
        exit 1
    fi

    # 检查 minikube（如果使用）
    if command -v minikube &> /dev/null; then
        log_info "检测到 minikube 环境"
        # 启用存储提供程序
        minikube addons enable storage-provisioner || log_warning "无法启用存储提供程序"
    fi

    # 检查DNS状态
    check_dns_status || true  # DNS检查失败不影响整体检查

    log_success "前置条件检查通过"
}

# 创建命名空间
create_namespaces() {
    log_info "创建命名空间..."
    
    # 创建日志命名空间
    kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
    
    # 创建追踪命名空间
    kubectl create namespace tracing --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "命名空间创建完成"
}

# 部署 Elasticsearch
deploy_elasticsearch() {
    log_info "部署 Elasticsearch 集群..."

    # 使用简化版本的 Elasticsearch 配置
    if [ -f "../manifests/elasticsearch/elasticsearch-simple.yaml" ]; then
        kubectl apply -f ../manifests/elasticsearch/elasticsearch-simple.yaml
    else
        kubectl apply -f ../manifests/elasticsearch/elasticsearch.yaml
    fi

    # 等待 Elasticsearch 启动
    log_info "等待 Elasticsearch Pod 启动..."
    kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

    # 验证集群状态
    log_info "验证 Elasticsearch 集群状态..."
    sleep 30

    # 端口转发验证
    kubectl port-forward -n logging svc/elasticsearch 9200:9200 &
    local port_forward_pid=$!
    sleep 5

    if curl -s "http://localhost:9200/_cluster/health" | grep -q "green\|yellow"; then
        log_success "Elasticsearch 集群部署成功"
    else
        log_warning "Elasticsearch 集群状态可能不正常，请检查"
    fi

    # 停止端口转发
    kill $port_forward_pid 2>/dev/null || true
}

# 部署 Fluent Bit
deploy_fluent_bit() {
    log_info "部署 Fluent Bit 日志收集器..."

    # 获取 Elasticsearch Pod IP
    local es_ip=$(kubectl get pods -n logging -l app=elasticsearch -o jsonpath='{.items[0].status.podIP}')
    if [ -z "$es_ip" ]; then
        log_error "无法获取 Elasticsearch Pod IP"
        exit 1
    fi

    log_info "Elasticsearch Pod IP: $es_ip"

    # 使用简化版本的 Fluent Bit 配置
    if [ -f "../manifests/fluent-bit/fluent-bit-simple.yaml" ]; then
        # 更新配置中的 Elasticsearch IP
        sed "s/10\.244\.0\.42/$es_ip/g" ../manifests/fluent-bit/fluent-bit-simple.yaml | kubectl apply -f -
    else
        # 更新原始配置中的 Elasticsearch IP
        sed "s/elasticsearch\.logging\.svc\.cluster\.local/$es_ip/g" ../manifests/fluent-bit/fluent-bit.yaml | kubectl apply -f -
    fi

    # 等待 DaemonSet 启动
    log_info "等待 Fluent Bit DaemonSet 启动..."
    kubectl rollout status daemonset/fluent-bit -n logging --timeout=180s

    log_success "Fluent Bit 部署成功"
}

# 部署 Kibana
deploy_kibana() {
    log_info "部署 Kibana 可视化平台..."

    # 获取 Elasticsearch Pod IP
    local es_ip=$(kubectl get pods -n logging -l app=elasticsearch -o jsonpath='{.items[0].status.podIP}')
    if [ -z "$es_ip" ]; then
        log_error "无法获取 Elasticsearch Pod IP"
        exit 1
    fi

    # 使用简化版本的 Kibana 配置
    if [ -f "../manifests/kibana/kibana-simple.yaml" ]; then
        # 更新配置中的 Elasticsearch IP
        sed "s/10\.244\.0\.42/$es_ip/g" ../manifests/kibana/kibana-simple.yaml | kubectl apply -f -
    else
        # 更新原始配置中的 Elasticsearch IP
        sed "s/elasticsearch\.logging\.svc\.cluster\.local/$es_ip/g" ../manifests/kibana/kibana.yaml | kubectl apply -f -
    fi

    # 等待 Kibana 启动
    log_info "等待 Kibana Pod 启动..."
    kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s

    log_success "Kibana 部署成功"
}

# 部署 Jaeger
deploy_jaeger() {
    log_info "部署 Jaeger 链路追踪系统..."

    # 使用简化版本的 Jaeger 配置（内存存储）
    if [ -f "../manifests/jaeger/jaeger-simple.yaml" ]; then
        kubectl apply -f ../manifests/jaeger/jaeger-simple.yaml
    else
        kubectl apply -f ../manifests/jaeger/jaeger-all-in-one.yaml
    fi

    # 等待 Jaeger 启动
    log_info "等待 Jaeger Pod 启动..."
    kubectl wait --for=condition=ready pod -l app=jaeger -n tracing --timeout=300s

    log_success "Jaeger 部署成功"
}

# 构建用户服务镜像
build_user_service() {
    log_info "构建用户服务 Docker 镜像..."

    # 检查用户服务目录
    if [ ! -d "../apps/user-service" ]; then
        log_warning "用户服务源码目录不存在，跳过构建"
        return
    fi

    # 构建 Docker 镜像
    cd ../apps/user-service
    docker build -t user-service:latest .
    cd ../../scripts

    # 加载镜像到 minikube（如果使用）
    if command -v minikube &> /dev/null; then
        minikube image load user-service:latest
        log_success "用户服务镜像已加载到 minikube"
    fi

    log_success "用户服务镜像构建完成"
}

# 部署示例应用
deploy_sample_apps() {
    log_info "部署示例微服务应用..."

    # 构建用户服务镜像
    build_user_service

    # 获取 Jaeger Pod IP
    local jaeger_ip=$(kubectl get pods -n tracing -l app=jaeger -o jsonpath='{.items[0].status.podIP}')
    if [ -z "$jaeger_ip" ]; then
        log_warning "无法获取 Jaeger Pod IP，使用默认配置"
        jaeger_ip="jaeger-agent.tracing.svc.cluster.local"
    fi

    # 部署用户服务
    if [ -f "../manifests/apps/user-service.yaml" ]; then
        # 更新配置中的 Jaeger IP
        sed "s/jaeger-agent\.tracing\.svc\.cluster\.local/$jaeger_ip/g" ../manifests/apps/user-service.yaml | kubectl apply -f -

        # 等待用户服务启动
        log_info "等待用户服务启动..."
        kubectl wait --for=condition=ready pod -l app=user-service --timeout=300s

        log_success "用户服务部署完成"
    else
        log_warning "用户服务配置文件不存在，跳过部署"
    fi

    # 部署负载生成器
    if [ -f "../manifests/apps/load-generator.yaml" ]; then
        kubectl apply -f ../manifests/apps/load-generator.yaml
        log_info "负载生成器部署完成"
    else
        log_warning "负载生成器配置文件不存在，跳过部署"
    fi

    log_success "示例应用部署完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    echo ""
    echo "=== Elasticsearch 状态 ==="
    kubectl get pods -n logging -l app=elasticsearch
    
    echo ""
    echo "=== Fluent Bit 状态 ==="
    kubectl get pods -n logging -l app=fluent-bit
    
    echo ""
    echo "=== Kibana 状态 ==="
    kubectl get pods -n logging -l app=kibana
    
    echo ""
    echo "=== Jaeger 状态 ==="
    kubectl get pods -n tracing -l app=jaeger
    
    echo ""
    echo "=== 服务状态 ==="
    kubectl get svc -n logging
    kubectl get svc -n tracing
    
    log_success "部署验证完成"
}

# 显示访问信息
show_access_info() {
    log_info "显示访问信息..."
    
    echo ""
    echo "=========================================="
    echo "🎉 可观测性系统部署完成！"
    echo "=========================================="
    echo ""
    echo "📊 访问地址："
    echo "----------------------------------------"
    echo "Kibana (日志分析):     http://localhost:5601"
    echo "  端口转发命令: kubectl port-forward -n logging svc/kibana 5601:5601"
    echo ""
    echo "Jaeger (链路追踪):     http://localhost:16686"
    echo "  端口转发命令: kubectl port-forward -n tracing svc/jaeger-query 16686:16686"
    echo ""
    echo "Elasticsearch:         http://localhost:9200"
    echo "  端口转发命令: kubectl port-forward -n logging svc/elasticsearch 9200:9200"
    echo ""
    echo "🔧 NodePort 访问 (如果支持)："
    echo "----------------------------------------"
    echo "Kibana:               http://<node-ip>:30561"
    echo "Jaeger:               http://<node-ip>:30686"
    echo "Elasticsearch:        http://<node-ip>:30920"
    echo ""
    echo "📝 下一步操作："
    echo "----------------------------------------"
    echo "1. 配置 Kibana 索引模式: fluentbit-*"
    echo "2. 在 Jaeger UI 中查看追踪数据"
    echo "3. 运行负载生成器: ./generate-load.sh"
    echo "4. 查看监控仪表板和日志分析"
    echo ""
    echo "🚨 故障排查："
    echo "----------------------------------------"
    echo "查看组件日志: kubectl logs -n <namespace> <pod-name>"
    echo "检查资源状态: kubectl describe pod -n <namespace> <pod-name>"
    echo "运行测试脚本: ./test.sh"
    echo ""
    echo "🔗 启动端口转发："
    echo "----------------------------------------"
    echo "启动所有端口转发: ./port-forward.sh start"
    echo "查看端口转发状态: ./port-forward.sh status"
    echo "停止端口转发: ./port-forward.sh stop"
    echo ""
    echo "=========================================="
}

# 主函数
main() {
    echo ""
    echo "=========================================="
    echo "🚀 云原生可观测性系统部署"
    echo "=========================================="
    echo ""
    echo "本脚本将部署以下组件："
    echo "- Elasticsearch (日志存储)"
    echo "- Fluent Bit (日志收集)"
    echo "- Kibana (日志可视化)"
    echo "- Jaeger (链路追踪)"
    echo "- 示例微服务应用"
    echo ""
    
    read -p "是否继续部署? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
    
    # 执行部署步骤
    check_prerequisites
    create_namespaces
    deploy_elasticsearch
    deploy_fluent_bit
    deploy_kibana
    deploy_jaeger
    deploy_sample_apps
    verify_deployment
    show_access_info
    
    log_success "🎉 可观测性系统部署完成！"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
