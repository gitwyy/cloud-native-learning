#!/bin/bash

# ==============================================================================
# 云原生学习环境 - Kubernetes集群管理脚本
# 支持 Minikube、Kind、k3s 等本地集群部署
# ==============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
CLUSTER_NAME="cloud-native-learning"
K8S_VERSION="1.25.0"
CLUSTER_TYPE="minikube"  # minikube, kind, k3s
NODES=1
MEMORY="8192"
CPUS="4"
DISK_SIZE="50g"

# 打印消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_title() {
    echo
    print_message $CYAN "🚀 ================================"
    print_message $CYAN "   $1"
    print_message $CYAN "================================"
    echo
}

# 检查命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_message $RED "❌ 错误: $1 未安装"
        print_message $YELLOW "请先运行环境设置脚本: ./scripts/setup-environment.sh"
        exit 1
    fi
}

# 检查Docker
check_docker() {
    if ! docker info &> /dev/null; then
        print_message $RED "❌ 错误: Docker 未运行"
        print_message $YELLOW "请启动Docker Desktop或Docker服务"
        exit 1
    fi
}

# 创建Minikube集群
create_minikube_cluster() {
    print_title "🚀 创建 Minikube 集群"
    
    check_command minikube
    check_docker
    
    # 删除现有集群（如果存在）
    if minikube status --profile="$CLUSTER_NAME" &> /dev/null; then
        print_message $YELLOW "🗑️  删除现有Minikube集群..."
        minikube delete --profile="$CLUSTER_NAME"
    fi
    
    print_message $BLUE "⚙️  集群配置:"
    print_message $BLUE "   • 名称: $CLUSTER_NAME"
    print_message $BLUE "   • K8s版本: $K8S_VERSION"
    print_message $BLUE "   • 内存: ${MEMORY}MB"
    print_message $BLUE "   • CPU: ${CPUS}核"
    print_message $BLUE "   • 磁盘: $DISK_SIZE"
    
    # 启动Minikube
    print_message $BLUE "🚀 启动Minikube集群..."
    minikube start \
        --profile="$CLUSTER_NAME" \
        --driver=docker \
        --kubernetes-version="v$K8S_VERSION" \
        --memory="$MEMORY" \
        --cpus="$CPUS" \
        --disk-size="$DISK_SIZE" \
        --addons=dashboard,ingress,metrics-server,registry
    
    # 设置kubectl上下文
    kubectl config use-context "$CLUSTER_NAME"
    
    print_message $GREEN "✅ Minikube集群创建完成"
}

# 创建Kind集群
create_kind_cluster() {
    print_title "🎯 创建 Kind 集群"
    
    check_command kind
    check_docker
    
    # 删除现有集群（如果存在）
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        print_message $YELLOW "🗑️  删除现有Kind集群..."
        kind delete cluster --name="$CLUSTER_NAME"
    fi
    
    # 创建Kind配置文件
    local config_file="/tmp/kind-config-$CLUSTER_NAME.yaml"
    cat > "$config_file" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
EOF
    
    # 添加控制平面节点
    cat >> "$config_file" << EOF
- role: control-plane
  image: kindest/node:v$K8S_VERSION
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
    
    # 添加工作节点
    for ((i=1; i<NODES; i++)); do
        cat >> "$config_file" << EOF
- role: worker
  image: kindest/node:v$K8S_VERSION
EOF
    done
    
    print_message $BLUE "⚙️  集群配置:"
    print_message $BLUE "   • 名称: $CLUSTER_NAME"
    print_message $BLUE "   • K8s版本: $K8S_VERSION"
    print_message $BLUE "   • 节点数: $NODES"
    print_message $BLUE "   • 配置文件: $config_file"
    
    # 创建Kind集群
    print_message $BLUE "🚀 创建Kind集群..."
    kind create cluster --config="$config_file"
    
    # 安装Nginx Ingress Controller
    print_message $BLUE "🔧 安装Nginx Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # 等待Ingress Controller就绪
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    print_message $GREEN "✅ Kind集群创建完成"
}

# 创建k3s集群
create_k3s_cluster() {
    print_title "🐄 创建 k3s 集群"
    
    # 检查是否为Linux系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_message $RED "❌ k3s仅支持Linux系统"
        exit 1
    fi
    
    # 安装k3s
    print_message $BLUE "📦 安装k3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v$K8S_VERSION+k3s1" sh -
    
    # 配置kubectl
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    
    print_message $GREEN "✅ k3s集群创建完成"
}

# 安装基础组件
install_base_components() {
    print_title "📦 安装基础组件"
    
    # 等待集群就绪
    print_message $BLUE "⏳ 等待集群就绪..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # 创建命名空间
    print_message $BLUE "📁 创建命名空间..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    
    # 安装Metrics Server（如果不存在）
    if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
        print_message $BLUE "📊 安装Metrics Server..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        
        # 为本地集群修补Metrics Server
        kubectl patch deployment metrics-server -n kube-system --type='json' \
            -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
    fi
    
    print_message $GREEN "✅ 基础组件安装完成"
}

# 部署示例应用
deploy_sample_apps() {
    print_title "🎯 部署示例应用"
    
    # 部署nginx示例
    print_message $BLUE "🌐 部署Nginx示例..."
    kubectl create deployment nginx-demo --image=nginx:latest
    kubectl expose deployment nginx-demo --type=NodePort --port=80
    
    # 部署httpbin示例
    print_message $BLUE "🔧 部署HTTPBin示例..."
    kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  selector:
    app: httpbin
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
    
    print_message $GREEN "✅ 示例应用部署完成"
}

# 配置开发环境
setup_dev_environment() {
    print_title "🛠️ 配置开发环境"
    
    # 配置kubectl别名
    if ! grep -q "alias k=kubectl" ~/.bashrc; then
        echo "alias k=kubectl" >> ~/.bashrc
        echo "complete -F __start_kubectl k" >> ~/.bashrc
        print_message $BLUE "⚙️  添加kubectl别名"
    fi
    
    # 创建有用的脚本
    cat > ~/k8s-status.sh << 'EOF'
#!/bin/bash
echo "🔍 Kubernetes集群状态检查"
echo "================================"
echo "📋 集群信息:"
kubectl cluster-info
echo ""
echo "📊 节点状态:"
kubectl get nodes -o wide
echo ""
echo "🏠 命名空间:"
kubectl get namespaces
echo ""
echo "🚀 工作负载:"
kubectl get deployments,services,pods --all-namespaces
EOF
    chmod +x ~/k8s-status.sh
    
    print_message $GREEN "✅ 开发环境配置完成"
}

# 显示集群信息
show_cluster_info() {
    print_title "📊 集群信息"
    
    print_message $CYAN "🏷️  集群基本信息:"
    kubectl cluster-info
    echo
    
    print_message $CYAN "📋 节点状态:"
    kubectl get nodes -o wide
    echo
    
    print_message $CYAN "🏠 命名空间:"
    kubectl get namespaces
    echo
    
    print_message $CYAN "🚀 示例应用:"
    kubectl get deployments,services,pods
    echo
    
    print_message $CYAN "🌐 访问方式:"
    case "$CLUSTER_TYPE" in
        "minikube")
            print_message $BLUE "• Minikube Dashboard: minikube dashboard --profile=$CLUSTER_NAME"
            print_message $BLUE "• Service访问: minikube service <service-name> --profile=$CLUSTER_NAME"
            ;;
        "kind")
            print_message $BLUE "• 端口转发: kubectl port-forward svc/<service-name> <local-port>:<service-port>"
            print_message $BLUE "• Ingress: http://localhost (需要配置Ingress)"
            ;;
        "k3s")
            print_message $BLUE "• NodePort: http://<node-ip>:<node-port>"
            print_message $BLUE "• 端口转发: kubectl port-forward svc/<service-name> <local-port>:<service-port>"
            ;;
    esac
    echo
    
    print_message $CYAN "🔧 有用的命令:"
    print_message $BLUE "• 集群状态: ~/k8s-status.sh"
    print_message $BLUE "• 查看Pod日志: kubectl logs <pod-name>"
    print_message $BLUE "• 进入Pod: kubectl exec -it <pod-name> -- /bin/bash"
    print_message $BLUE "• 端口转发: kubectl port-forward <pod-name> <local-port>:<pod-port>"
}

# 清理集群
cleanup_cluster() {
    print_title "🧹 清理集群"
    
    case "$CLUSTER_TYPE" in
        "minikube")
            if minikube status --profile="$CLUSTER_NAME" &> /dev/null; then
                print_message $YELLOW "🗑️  删除Minikube集群..."
                minikube delete --profile="$CLUSTER_NAME"
            fi
            ;;
        "kind")
            if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
                print_message $YELLOW "🗑️  删除Kind集群..."
                kind delete cluster --name="$CLUSTER_NAME"
            fi
            ;;
        "k3s")
            print_message $YELLOW "🗑️  卸载k3s..."
            sudo /usr/local/bin/k3s-uninstall.sh
            ;;
    esac
    
    print_message $GREEN "✅ 清理完成"
}

# 显示帮助
show_help() {
    echo "云原生学习环境 - Kubernetes集群管理脚本"
    echo
    echo "用法: $0 [选项] <命令>"
    echo
    echo "命令:"
    echo "  create               创建新的Kubernetes集群"
    echo "  delete               删除现有集群"
    echo "  status               显示集群状态信息"
    echo "  restart              重启集群"
    echo "  deploy-samples       部署示例应用"
    echo
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -t, --type TYPE      集群类型 (minikube|kind|k3s)"
    echo "  -n, --name NAME      集群名称"
    echo "  -v, --version VER    Kubernetes版本"
    echo "  --nodes NUM          节点数量 (仅Kind)"
    echo "  --memory SIZE        内存大小 (MB)"
    echo "  --cpus NUM           CPU核心数"
    echo
    echo "示例:"
    echo "  $0 create                    # 创建默认Minikube集群"
    echo "  $0 -t kind create            # 创建Kind集群"
    echo "  $0 -n my-cluster create      # 创建自定义名称集群"
    echo "  $0 --nodes 3 -t kind create  # 创建3节点Kind集群"
    echo "  $0 status                    # 显示集群状态"
    echo "  $0 delete                    # 删除集群"
    echo
}

# 主函数
main() {
    local command=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--type)
                CLUSTER_TYPE="$2"
                shift 2
                ;;
            -n|--name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -v|--version)
                K8S_VERSION="$2"
                shift 2
                ;;
            --nodes)
                NODES="$2"
                shift 2
                ;;
            --memory)
                MEMORY="$2"
                shift 2
                ;;
            --cpus)
                CPUS="$2"
                shift 2
                ;;
            create|delete|status|restart|deploy-samples)
                command="$1"
                shift
                ;;
            *)
                print_message $RED "❌ 未知参数: $1"
                echo "使用 $0 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
    
    # 验证集群类型
    if [[ "$CLUSTER_TYPE" != "minikube" && "$CLUSTER_TYPE" != "kind" && "$CLUSTER_TYPE" != "k3s" ]]; then
        print_message $RED "❌ 无效的集群类型: $CLUSTER_TYPE"
        print_message $YELLOW "支持的类型: minikube, kind, k3s"
        exit 1
    fi
    
    # 执行命令
    case "$command" in
        "create")
            case "$CLUSTER_TYPE" in
                "minikube")
                    create_minikube_cluster
                    ;;
                "kind")
                    create_kind_cluster
                    ;;
                "k3s")
                    create_k3s_cluster
                    ;;
            esac
            install_base_components
            setup_dev_environment
            show_cluster_info
            ;;
        "delete")
            cleanup_cluster
            ;;
        "status")
            show_cluster_info
            ;;
        "restart")
            case "$CLUSTER_TYPE" in
                "minikube")
                    minikube stop --profile="$CLUSTER_NAME"
                    minikube start --profile="$CLUSTER_NAME"
                    ;;
                *)
                    print_message $YELLOW "⚠️  重启功能仅支持Minikube"
                    ;;
            esac
            ;;
        "deploy-samples")
            deploy_sample_apps
            ;;
        "")
            print_message $RED "❌ 请指定命令"
            echo "使用 $0 --help 查看帮助信息"
            exit 1
            ;;
        *)
            print_message $RED "❌ 未知命令: $command"
            echo "使用 $0 --help 查看帮助信息"
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@"