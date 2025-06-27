#!/bin/bash

# 负载生成脚本
# 为示例应用生成测试流量，产生日志和追踪数据

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

# 配置参数
DURATION=${1:-300}  # 默认运行 5 分钟
REQUESTS_PER_SECOND=${2:-5}  # 默认每秒 5 个请求
USER_SERVICE_URL="http://user-service:8080"

# 检查服务是否可用
check_services() {
    log_info "检查服务可用性..."
    
    # 检查用户服务
    if kubectl get svc user-service &>/dev/null; then
        log_success "用户服务已部署"
    else
        log_error "用户服务未部署，请先部署示例应用"
        exit 1
    fi
}

# 创建负载生成器 Pod
create_load_generator() {
    log_info "创建负载生成器..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
  labels:
    app: load-generator
spec:
  restartPolicy: Never
  containers:
  - name: load-generator
    image: curlimages/curl:latest
    command: ["/bin/sh"]
    args:
      - -c
      - |
        echo "开始生成负载..."
        echo "目标服务: $USER_SERVICE_URL"
        echo "持续时间: $DURATION 秒"
        echo "请求频率: $REQUESTS_PER_SECOND 请求/秒"
        echo ""
        
        # 计算请求间隔
        INTERVAL=\$(echo "scale=2; 1 / $REQUESTS_PER_SECOND" | bc -l)
        END_TIME=\$((\$(date +%s) + $DURATION))
        REQUEST_COUNT=0
        
        while [ \$(date +%s) -lt \$END_TIME ]; do
          REQUEST_COUNT=\$((REQUEST_COUNT + 1))
          
          # 随机选择 API 端点
          ENDPOINT=\$(shuf -n 1 -e "/api/users" "/api/users/1" "/api/users/2" "/health")
          
          # 发送请求
          echo "[\$(date)] 请求 #\$REQUEST_COUNT: GET \$ENDPOINT"
          curl -s -w "状态码: %{http_code}, 响应时间: %{time_total}s\n" \\
               "$USER_SERVICE_URL\$ENDPOINT" || echo "请求失败"
          
          # 等待下一个请求
          sleep \$INTERVAL
        done
        
        echo ""
        echo "负载生成完成，总共发送了 \$REQUEST_COUNT 个请求"
    env:
    - name: USER_SERVICE_URL
      value: "$USER_SERVICE_URL"
    - name: DURATION
      value: "$DURATION"
    - name: REQUESTS_PER_SECOND
      value: "$REQUESTS_PER_SECOND"
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
EOF

    log_success "负载生成器已创建"
}

# 监控负载生成过程
monitor_load_generation() {
    log_info "监控负载生成过程..."
    
    # 等待 Pod 启动
    kubectl wait --for=condition=Ready pod/load-generator --timeout=60s
    
    # 跟踪日志
    kubectl logs -f load-generator
}

# 清理负载生成器
cleanup_load_generator() {
    log_info "清理负载生成器..."
    kubectl delete pod load-generator --ignore-not-found=true
    log_success "清理完成"
}

# 生成多种类型的负载
generate_mixed_load() {
    log_info "生成混合负载模式..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mixed-load-generator
spec:
  parallelism: 3
  completions: 3
  template:
    metadata:
      labels:
        app: mixed-load-generator
    spec:
      restartPolicy: Never
      containers:
      - name: load-generator
        image: curlimages/curl:latest
        command: ["/bin/sh"]
        args:
          - -c
          - |
            # 获取 Pod 名称来区分不同的负载模式
            POD_NAME=\$(hostname)
            
            case "\$POD_NAME" in
              *-1-*)
                echo "启动正常负载模式..."
                for i in \$(seq 1 50); do
                  curl -s "$USER_SERVICE_URL/api/users" > /dev/null
                  sleep 2
                done
                ;;
              *-2-*)
                echo "启动高频负载模式..."
                for i in \$(seq 1 100); do
                  curl -s "$USER_SERVICE_URL/api/users/\$((\$i % 5 + 1))" > /dev/null
                  sleep 0.5
                done
                ;;
              *-3-*)
                echo "启动错误模拟模式..."
                for i in \$(seq 1 30); do
                  # 访问不存在的用户 ID
                  curl -s "$USER_SERVICE_URL/api/users/999" > /dev/null
                  curl -s "$USER_SERVICE_URL/api/users/\$((\$i % 3 + 1))" > /dev/null
                  sleep 3
                done
                ;;
            esac
            
            echo "负载生成完成"
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
EOF

    log_success "混合负载生成器已启动"
}

# 显示使用帮助
show_help() {
    echo "负载生成脚本使用说明"
    echo ""
    echo "用法: $0 [持续时间] [请求频率]"
    echo ""
    echo "参数:"
    echo "  持续时间    负载生成持续时间（秒），默认 300"
    echo "  请求频率    每秒请求数，默认 5"
    echo ""
    echo "示例:"
    echo "  $0                    # 使用默认参数（5分钟，5请求/秒）"
    echo "  $0 600 10            # 运行10分钟，10请求/秒"
    echo "  $0 mixed             # 生成混合负载模式"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -c, --cleanup        清理现有的负载生成器"
    echo "  -m, --mixed          生成混合负载模式"
    echo ""
}

# 主函数
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--cleanup)
            cleanup_load_generator
            kubectl delete job mixed-load-generator --ignore-not-found=true
            exit 0
            ;;
        -m|--mixed|mixed)
            check_services
            generate_mixed_load
            log_info "混合负载生成器已启动，使用以下命令查看进度："
            echo "kubectl get jobs"
            echo "kubectl logs -l app=mixed-load-generator"
            exit 0
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo "🚀 负载生成器"
    echo "=========================================="
    echo ""
    echo "配置参数："
    echo "- 持续时间: $DURATION 秒"
    echo "- 请求频率: $REQUESTS_PER_SECOND 请求/秒"
    echo "- 目标服务: $USER_SERVICE_URL"
    echo ""
    
    # 执行负载生成
    check_services
    
    # 清理之前的负载生成器
    cleanup_load_generator
    
    # 创建新的负载生成器
    create_load_generator
    
    # 监控过程
    monitor_load_generation
    
    # 完成后清理
    cleanup_load_generator
    
    echo ""
    echo "=========================================="
    echo "✅ 负载生成完成"
    echo "=========================================="
    echo ""
    echo "📊 查看结果："
    echo "- Kibana 日志分析: http://localhost:5601"
    echo "- Jaeger 链路追踪: http://localhost:16686"
    echo "- Prometheus 指标: http://localhost:9090"
    echo ""
    echo "🔍 有用的查询："
    echo "- 在 Kibana 中搜索: kubernetes.labels.app:user-service"
    echo "- 在 Jaeger 中查看: user-service 服务的追踪"
    echo "- 在 Prometheus 中查询: user_service_requests_total"
    echo ""
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
