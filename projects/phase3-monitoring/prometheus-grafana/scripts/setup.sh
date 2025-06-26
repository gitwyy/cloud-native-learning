#!/bin/bash

# Prometheus + Grafana 监控栈一键部署脚本
# 自动部署完整的监控解决方案

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE=${NAMESPACE:-"monitoring"}
DEPLOY_PROMETHEUS=${DEPLOY_PROMETHEUS:-"true"}
DEPLOY_GRAFANA=${DEPLOY_GRAFANA:-"true"}
DEPLOY_NODE_EXPORTER=${DEPLOY_NODE_EXPORTER:-"true"}
DEPLOY_KUBE_STATE_METRICS=${DEPLOY_KUBE_STATE_METRICS:-"true"}

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

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查 kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装"
        exit 1
    fi
    
    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到 Kubernetes 集群"
        exit 1
    fi
    
    # 检查集群版本
    K8S_VERSION=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"v[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/v//' || echo "1.20.0")
    log_info "检测到 Kubernetes 版本: $K8S_VERSION"
    
    # 检查存储类
    if ! kubectl get storageclass &> /dev/null; then
        log_warning "未检测到存储类，可能需要手动配置持久化存储"
    fi
    
    log_success "前置条件检查通过"
}

# 创建命名空间
create_namespace() {
    log_info "创建命名空间 $NAMESPACE..."
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warning "命名空间 $NAMESPACE 已存在"
    else
        kubectl create namespace $NAMESPACE
        log_success "命名空间 $NAMESPACE 创建成功"
    fi
}

# 部署 Node Exporter
deploy_node_exporter() {
    if [ "$DEPLOY_NODE_EXPORTER" != "true" ]; then
        log_info "跳过 Node Exporter 部署"
        return
    fi
    
    log_info "部署 Node Exporter..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: $NAMESPACE
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9100"
        prometheus.io/path: "/metrics"
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.6.1
        args:
          - '--path.procfs=/host/proc'
          - '--path.sysfs=/host/sys'
          - '--path.rootfs=/host/root'
          - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
        ports:
        - name: metrics
          containerPort: 9100
          hostPort: 9100
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
      tolerations:
      - operator: Exists
        effect: NoSchedule
---
apiVersion: v1
kind: Service
metadata:
  name: node-exporter
  namespace: $NAMESPACE
  labels:
    app: node-exporter
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9100"
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: metrics
    port: 9100
    targetPort: 9100
  selector:
    app: node-exporter
EOF
    
    log_success "Node Exporter 部署完成"
}

# 部署 Kube State Metrics
deploy_kube_state_metrics() {
    if [ "$DEPLOY_KUBE_STATE_METRICS" != "true" ]; then
        log_info "跳过 Kube State Metrics 部署"
        return
    fi
    
    log_info "部署 Kube State Metrics..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
- apiGroups: [""]
  resources:
  - configmaps
  - secrets
  - nodes
  - pods
  - services
  - resourcequotas
  - replicationcontrollers
  - limitranges
  - persistentvolumeclaims
  - persistentvolumes
  - namespaces
  - endpoints
  verbs: ["list", "watch"]
- apiGroups: ["apps"]
  resources:
  - statefulsets
  - daemonsets
  - deployments
  - replicasets
  verbs: ["list", "watch"]
- apiGroups: ["batch"]
  resources:
  - cronjobs
  - jobs
  verbs: ["list", "watch"]
- apiGroups: ["autoscaling"]
  resources:
  - horizontalpodautoscalers
  verbs: ["list", "watch"]
- apiGroups: ["authentication.k8s.io"]
  resources:
  - tokenreviews
  verbs: ["create"]
- apiGroups: ["authorization.k8s.io"]
  resources:
  - subjectaccessreviews
  verbs: ["create"]
- apiGroups: ["policy"]
  resources:
  - poddisruptionbudgets
  verbs: ["list", "watch"]
- apiGroups: ["certificates.k8s.io"]
  resources:
  - certificatesigningrequests
  verbs: ["list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources:
  - storageclasses
  - volumeattachments
  verbs: ["list", "watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources:
  - mutatingwebhookconfigurations
  - validatingwebhookconfigurations
  verbs: ["list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources:
  - networkpolicies
  - ingresses
  verbs: ["list", "watch"]
- apiGroups: ["coordination.k8s.io"]
  resources:
  - leases
  verbs: ["list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: $NAMESPACE
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: $NAMESPACE
  labels:
    app: kube-state-metrics
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kube-state-metrics
  template:
    metadata:
      labels:
        app: kube-state-metrics
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: kube-state-metrics
      containers:
      - name: kube-state-metrics
        image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.0
        ports:
        - name: http-metrics
          containerPort: 8080
        - name: telemetry
          containerPort: 8081
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 8081
          initialDelaySeconds: 5
          timeoutSeconds: 5
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: $NAMESPACE
  labels:
    app: kube-state-metrics
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  type: ClusterIP
  ports:
  - name: http-metrics
    port: 8080
    targetPort: http-metrics
  - name: telemetry
    port: 8081
    targetPort: telemetry
  selector:
    app: kube-state-metrics
EOF
    
    log_success "Kube State Metrics 部署完成"
}

# 部署 Prometheus
deploy_prometheus() {
    if [ "$DEPLOY_PROMETHEUS" != "true" ]; then
        log_info "跳过 Prometheus 部署"
        return
    fi
    
    log_info "部署 Prometheus..."
    kubectl apply -f "$PROJECT_ROOT/manifests/prometheus/deployment.yaml"
    
    # 等待 Prometheus 启动
    log_info "等待 Prometheus 启动..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $NAMESPACE
    
    log_success "Prometheus 部署完成"
}

# 部署 Grafana
deploy_grafana() {
    if [ "$DEPLOY_GRAFANA" != "true" ]; then
        log_info "跳过 Grafana 部署"
        return
    fi
    
    log_info "部署 Grafana..."
    kubectl apply -f "$PROJECT_ROOT/manifests/grafana/deployment.yaml"
    
    # 等待 Grafana 启动
    log_info "等待 Grafana 启动..."
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n $NAMESPACE
    
    log_success "Grafana 部署完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    # 检查 Pod 状态
    log_info "检查 Pod 状态..."
    kubectl get pods -n $NAMESPACE
    
    # 检查服务状态
    log_info "检查服务状态..."
    kubectl get svc -n $NAMESPACE
    
    # 获取访问信息
    log_info "获取访问信息..."
    
    echo ""
    echo "=========================================="
    echo "监控栈部署完成！"
    echo "=========================================="
    echo "命名空间: $NAMESPACE"
    echo ""
    echo "访问方式:"
    echo "  # Prometheus"
    echo "  kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090"
    echo "  然后访问: http://localhost:9090"
    echo ""
    echo "  # Grafana"
    echo "  kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
    echo "  然后访问: http://localhost:3000"
    echo "  默认登录: admin / admin123"
    echo ""
    echo "验证命令:"
    echo "  # 检查 Prometheus 目标"
    echo "  curl http://localhost:9090/api/v1/targets"
    echo ""
    echo "  # 检查 Grafana 健康状态"
    echo "  curl http://localhost:3000/api/health"
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "Prometheus + Grafana 监控栈部署脚本"
    echo "=========================================="
    
    check_prerequisites
    create_namespace
    deploy_node_exporter
    deploy_kube_state_metrics
    deploy_prometheus
    deploy_grafana
    verify_deployment
}

# 显示帮助信息
show_help() {
    echo "Prometheus + Grafana 监控栈部署脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --namespace NAMESPACE        设置命名空间 (默认: monitoring)"
    echo "  --no-prometheus             跳过 Prometheus 部署"
    echo "  --no-grafana                跳过 Grafana 部署"
    echo "  --no-node-exporter          跳过 Node Exporter 部署"
    echo "  --no-kube-state-metrics     跳过 Kube State Metrics 部署"
    echo "  -h, --help                  显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  NAMESPACE                   部署命名空间"
    echo "  DEPLOY_PROMETHEUS           是否部署 Prometheus (true/false)"
    echo "  DEPLOY_GRAFANA              是否部署 Grafana (true/false)"
    echo "  DEPLOY_NODE_EXPORTER        是否部署 Node Exporter (true/false)"
    echo "  DEPLOY_KUBE_STATE_METRICS   是否部署 Kube State Metrics (true/false)"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --no-prometheus)
            DEPLOY_PROMETHEUS="false"
            shift
            ;;
        --no-grafana)
            DEPLOY_GRAFANA="false"
            shift
            ;;
        --no-node-exporter)
            DEPLOY_NODE_EXPORTER="false"
            shift
            ;;
        --no-kube-state-metrics)
            DEPLOY_KUBE_STATE_METRICS="false"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 执行主函数
main
