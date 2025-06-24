#!/bin/bash

# ==============================================================================
# 云原生学习环境 - 监控堆栈部署脚本
# 自动部署 Prometheus + Grafana + AlertManager 监控体系
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

# 配置变量
NAMESPACE="monitoring"
RELEASE_NAME="prometheus-stack"
GRAFANA_PASSWORD="admin123"
PROMETHEUS_RETENTION="15d"
GRAFANA_PORT="3000"
PROMETHEUS_PORT="9090"
ALERTMANAGER_PORT="9093"

# 打印消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_title() {
    echo
    print_message $CYAN "📊 ================================"
    print_message $CYAN "   $1"
    print_message $CYAN "================================"
    echo
}

# 检查命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_message $RED "❌ 错误: $1 未安装"
        print_message $YELLOW "请先运行: ./scripts/setup-environment.sh"
        exit 1
    fi
}

# 检查Kubernetes集群
check_kubernetes() {
    if ! kubectl cluster-info &> /dev/null; then
        print_message $RED "❌ 错误: 无法连接到Kubernetes集群"
        print_message $YELLOW "请先创建集群: ./scripts/setup-kubernetes.sh create"
        exit 1
    fi
}

# 创建命名空间
create_namespace() {
    print_title "📁 创建监控命名空间"
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    print_message $GREEN "✅ 命名空间 '$NAMESPACE' 已准备就绪"
}

# 添加Helm仓库
add_helm_repos() {
    print_title "📦 添加Helm仓库"
    
    print_message $BLUE "🔄 添加Prometheus社区仓库..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    
    print_message $BLUE "🔄 添加Grafana仓库..."
    helm repo add grafana https://grafana.github.io/helm-charts
    
    print_message $BLUE "🔄 更新仓库索引..."
    helm repo update
    
    print_message $GREEN "✅ Helm仓库添加完成"
}

# 部署Prometheus Stack
deploy_prometheus_stack() {
    print_title "🔥 部署 Prometheus Stack"
    
    # 创建自定义values文件
    local values_file="/tmp/prometheus-values.yaml"
    cat > "$values_file" << EOF
# Prometheus配置
prometheus:
  prometheusSpec:
    retention: $PROMETHEUS_RETENTION
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

# Grafana配置
grafana:
  adminPassword: $GRAFANA_PASSWORD
  service:
    type: NodePort
    nodePort: 30300
  persistence:
    enabled: true
    size: 5Gi
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 6417
        revision: 1
        datasource: Prometheus
      kubernetes-pods:
        gnetId: 6336
        revision: 1
        datasource: Prometheus
      node-exporter:
        gnetId: 1860
        revision: 27
        datasource: Prometheus

# AlertManager配置
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi

# kube-state-metrics配置
kubeStateMetrics:
  enabled: true

# node-exporter配置
nodeExporter:
  enabled: true

# 禁用一些不需要的组件
kubelet:
  enabled: true
kubeApiServer:
  enabled: true
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeProxy:
  enabled: false
kubeEtcd:
  enabled: false
EOF
    
    print_message $BLUE "📋 配置文件位置: $values_file"
    print_message $BLUE "🚀 开始部署Prometheus Stack..."
    
    # 部署或升级
    helm upgrade --install "$RELEASE_NAME" \
        prometheus-community/kube-prometheus-stack \
        --namespace "$NAMESPACE" \
        --values "$values_file" \
        --wait \
        --timeout 10m
    
    print_message $GREEN "✅ Prometheus Stack 部署完成"
}

# 等待服务就绪
wait_for_services() {
    print_title "⏳ 等待服务就绪"
    
    print_message $BLUE "⏳ 等待Prometheus就绪..."
    kubectl wait --for=condition=ready pod \
        -l "app.kubernetes.io/name=prometheus" \
        -n "$NAMESPACE" \
        --timeout=300s
    
    print_message $BLUE "⏳ 等待Grafana就绪..."
    kubectl wait --for=condition=ready pod \
        -l "app.kubernetes.io/name=grafana" \
        -n "$NAMESPACE" \
        --timeout=300s
    
    print_message $BLUE "⏳ 等待AlertManager就绪..."
    kubectl wait --for=condition=ready pod \
        -l "app.kubernetes.io/name=alertmanager" \
        -n "$NAMESPACE" \
        --timeout=300s
    
    print_message $GREEN "✅ 所有服务已就绪"
}

# 创建ServiceMonitor示例
create_sample_servicemonitor() {
    print_title "📊 创建示例ServiceMonitor"
    
    kubectl apply -f - << EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-app
  namespace: $NAMESPACE
  labels:
    app: example-app
spec:
  selector:
    matchLabels:
      app: example-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  namespace: default
  labels:
    app: example-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
      - name: app
        image: quay.io/prometheus/node-exporter:latest
        ports:
        - name: metrics
          containerPort: 9100
---
apiVersion: v1
kind: Service
metadata:
  name: example-app
  namespace: default
  labels:
    app: example-app
spec:
  ports:
  - name: metrics
    port: 9100
    targetPort: 9100
  selector:
    app: example-app
EOF
    
    print_message $GREEN "✅ 示例ServiceMonitor创建完成"
}

# 创建告警规则示例
create_sample_alerts() {
    print_title "🚨 创建示例告警规则"
    
    kubectl apply -f - << EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: example-alerts
  namespace: $NAMESPACE
  labels:
    prometheus: kube-prometheus-stack-prometheus
    role: alert-rules
spec:
  groups:
  - name: example.rules
    rules:
    - alert: HighPodCPU
      expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod CPU usage is high"
        description: "Pod {{ \$labels.pod }} CPU usage is above 80%"
    
    - alert: HighPodMemory
      expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod memory usage is high"
        description: "Pod {{ \$labels.pod }} memory usage is above 80%"
    
    - alert: PodCrashLooping
      expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ \$labels.pod }} has restarted {{ \$value }} times in the last hour"
EOF
    
    print_message $GREEN "✅ 示例告警规则创建完成"
}

# 配置端口转发
setup_port_forwarding() {
    print_title "🌐 配置端口转发"
    
    # 创建端口转发脚本
    cat > ~/start-monitoring-ports.sh << EOF
#!/bin/bash
echo "🚀 启动监控服务端口转发..."

# 停止现有的端口转发
pkill -f "kubectl.*port-forward.*monitoring" || true
sleep 2

# Grafana
echo "📊 启动Grafana端口转发 (localhost:$GRAFANA_PORT)..."
kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-grafana $GRAFANA_PORT:80 &

# Prometheus
echo "🔥 启动Prometheus端口转发 (localhost:$PROMETHEUS_PORT)..."
kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-kube-prom-prometheus $PROMETHEUS_PORT:9090 &

# AlertManager
echo "🚨 启动AlertManager端口转发 (localhost:$ALERTMANAGER_PORT)..."
kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-kube-prom-alertmanager $ALERTMANAGER_PORT:9093 &

echo "✅ 端口转发已启动！"
echo "📊 Grafana: http://localhost:$GRAFANA_PORT (admin/admin123)"
echo "🔥 Prometheus: http://localhost:$PROMETHEUS_PORT"
echo "🚨 AlertManager: http://localhost:$ALERTMANAGER_PORT"
echo ""
echo "💡 停止端口转发: pkill -f 'kubectl.*port-forward.*monitoring'"

wait
EOF
    
    chmod +x ~/start-monitoring-ports.sh
    
    # 创建停止脚本
    cat > ~/stop-monitoring-ports.sh << EOF
#!/bin/bash
echo "🛑 停止监控服务端口转发..."
pkill -f "kubectl.*port-forward.*monitoring" || true
echo "✅ 端口转发已停止"
EOF
    
    chmod +x ~/stop-monitoring-ports.sh
    
    print_message $GREEN "✅ 端口转发脚本创建完成"
    print_message $BLUE "• 启动: ~/start-monitoring-ports.sh"
    print_message $BLUE "• 停止: ~/stop-monitoring-ports.sh"
}

# 显示访问信息
show_access_info() {
    print_title "🎉 部署完成"
    
    print_message $GREEN "🎊 监控堆栈部署成功！"
    echo
    
    print_message $CYAN "📊 服务信息:"
    kubectl get pods,svc -n "$NAMESPACE"
    echo
    
    print_message $CYAN "🌐 访问方式:"
    print_message $BLUE "方式1: 端口转发"
    print_message $BLUE "  启动转发: ~/start-monitoring-ports.sh"
    print_message $BLUE "  • Grafana: http://localhost:$GRAFANA_PORT"
    print_message $BLUE "  • Prometheus: http://localhost:$PROMETHEUS_PORT"
    print_message $BLUE "  • AlertManager: http://localhost:$ALERTMANAGER_PORT"
    echo
    
    # 检查集群类型并提供相应的访问方法
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        print_message $BLUE "方式2: Minikube服务"
        print_message $BLUE "  • minikube service $RELEASE_NAME-grafana -n $NAMESPACE"
        print_message $BLUE "  • minikube service $RELEASE_NAME-kube-prom-prometheus -n $NAMESPACE"
    fi
    
    echo
    print_message $CYAN "🔐 登录信息:"
    print_message $BLUE "• Grafana用户名: admin"
    print_message $BLUE "• Grafana密码: $GRAFANA_PASSWORD"
    echo
    
    print_message $CYAN "📈 预装仪表板:"
    print_message $BLUE "• Kubernetes Cluster Overview"
    print_message $BLUE "• Kubernetes Pods"
    print_message $BLUE "• Node Exporter"
    echo
    
    print_message $CYAN "🔧 管理命令:"
    print_message $BLUE "• 查看监控Pod: kubectl get pods -n $NAMESPACE"
    print_message $BLUE "• 查看日志: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=grafana"
    print_message $BLUE "• 重启Grafana: kubectl rollout restart deployment/$RELEASE_NAME-grafana -n $NAMESPACE"
    print_message $BLUE "• 卸载监控: helm uninstall $RELEASE_NAME -n $NAMESPACE"
    echo
    
    print_message $PURPLE "📚 下一步学习:"
    print_message $BLUE "1. 访问Grafana并探索预装的仪表板"
    print_message $BLUE "2. 在Prometheus中查询指标: kubectl_version_info"
    print_message $BLUE "3. 创建自定义仪表板和告警规则"
    print_message $BLUE "4. 为应用添加metrics端点和ServiceMonitor"
}

# 清理监控堆栈
cleanup_monitoring() {
    print_title "🧹 清理监控堆栈"
    
    print_message $YELLOW "🗑️  删除Helm发布..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
    
    print_message $YELLOW "🗑️  删除自定义资源..."
    kubectl delete crd alertmanagerconfigs.monitoring.coreos.com || true
    kubectl delete crd alertmanagers.monitoring.coreos.com || true
    kubectl delete crd podmonitors.monitoring.coreos.com || true
    kubectl delete crd probes.monitoring.coreos.com || true
    kubectl delete crd prometheuses.monitoring.coreos.com || true
    kubectl delete crd prometheusrules.monitoring.coreos.com || true
    kubectl delete crd servicemonitors.monitoring.coreos.com || true
    kubectl delete crd thanosrulers.monitoring.coreos.com || true
    
    print_message $YELLOW "🗑️  删除命名空间..."
    kubectl delete namespace "$NAMESPACE" || true
    
    print_message $YELLOW "🗑️  删除脚本..."
    rm -f ~/start-monitoring-ports.sh ~/stop-monitoring-ports.sh
    
    print_message $GREEN "✅ 清理完成"
}

# 显示状态
show_status() {
    print_title "📊 监控堆栈状态"
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_message $YELLOW "⚠️  监控堆栈未部署"
        return 1
    fi
    
    print_message $CYAN "📋 Pod状态:"
    kubectl get pods -n "$NAMESPACE"
    echo
    
    print_message $CYAN "🌐 服务状态:"
    kubectl get svc -n "$NAMESPACE"
    echo
    
    print_message $CYAN "📊 PVC状态:"
    kubectl get pvc -n "$NAMESPACE"
    echo
    
    # 检查服务健康状态
    local grafana_ready=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    local prometheus_ready=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=prometheus" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    
    print_message $CYAN "🏥 健康状态:"
    if [[ "$grafana_ready" == "True" ]]; then
        print_message $GREEN "✅ Grafana: 就绪"
    else
        print_message $RED "❌ Grafana: 未就绪"
    fi
    
    if [[ "$prometheus_ready" == "True" ]]; then
        print_message $GREEN "✅ Prometheus: 就绪"
    else
        print_message $RED "❌ Prometheus: 未就绪"
    fi
}

# 显示帮助
show_help() {
    echo "云原生学习环境 - 监控堆栈部署脚本"
    echo
    echo "用法: $0 [选项] <命令>"
    echo
    echo "命令:"
    echo "  deploy               部署完整的监控堆栈"
    echo "  status               显示监控堆栈状态"
    echo "  cleanup              清理监控堆栈"
    echo "  port-forward         启动端口转发"
    echo "  stop-forward         停止端口转发"
    echo
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -n, --namespace NS   指定命名空间 (默认: monitoring)"
    echo "  -p, --password PWD   设置Grafana密码 (默认: admin123)"
    echo "  --retention PERIOD   Prometheus数据保留期 (默认: 15d)"
    echo
    echo "示例:"
    echo "  $0 deploy                    # 部署监控堆栈"
    echo "  $0 -p mypassword deploy      # 使用自定义密码部署"
    echo "  $0 status                    # 查看状态"
    echo "  $0 cleanup                   # 清理监控堆栈"
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
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -p|--password)
                GRAFANA_PASSWORD="$2"
                shift 2
                ;;
            --retention)
                PROMETHEUS_RETENTION="$2"
                shift 2
                ;;
            deploy|status|cleanup|port-forward|stop-forward)
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
    
    # 基础检查
    check_command kubectl
    check_command helm
    check_kubernetes
    
    # 执行命令
    case "$command" in
        "deploy")
            create_namespace
            add_helm_repos
            deploy_prometheus_stack
            wait_for_services
            create_sample_servicemonitor
            create_sample_alerts
            setup_port_forwarding
            show_access_info
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup_monitoring
            ;;
        "port-forward")
            if [[ -f ~/start-monitoring-ports.sh ]]; then
                ~/start-monitoring-ports.sh
            else
                print_message $RED "❌ 端口转发脚本不存在，请先部署监控堆栈"
            fi
            ;;
        "stop-forward")
            if [[ -f ~/stop-monitoring-ports.sh ]]; then
                ~/stop-monitoring-ports.sh
            else
                print_message $YELLOW "⚠️  端口转发脚本不存在"
            fi
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