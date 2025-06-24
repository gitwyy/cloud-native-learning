#!/bin/bash

# ==============================================================================
# 云原生学习环境 - 环境验证和测试脚本
# 全面检查和验证云原生学习环境的安装状态
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

# 检查计数器
CHECKS_TOTAL=0
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# 打印消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_title() {
    echo
    print_message $CYAN "🔍 ================================"
    print_message $CYAN "   $1"
    print_message $CYAN "================================"
    echo
}

# 记录检查结果
record_check() {
    local status=$1
    local message=$2
    
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
    
    case $status in
        "pass")
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            print_message $GREEN "✅ $message"
            ;;
        "fail")
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            print_message $RED "❌ $message"
            ;;
        "warn")
            CHECKS_WARNING=$((CHECKS_WARNING + 1))
            print_message $YELLOW "⚠️  $message"
            ;;
    esac
}

# 检查命令是否存在
check_command_exists() {
    local cmd=$1
    local description=$2
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "未知版本")
        record_check "pass" "$description: $version"
        return 0
    else
        record_check "fail" "$description: 未安装"
        return 1
    fi
}

# 检查服务状态
check_service_status() {
    local service=$1
    local description=$2
    local check_cmd=$3
    
    if eval "$check_cmd" &> /dev/null; then
        record_check "pass" "$description: 运行中"
        return 0
    else
        record_check "fail" "$description: 未运行或无法连接"
        return 1
    fi
}

# 检查系统要求
check_system_requirements() {
    print_title "💻 系统要求检查"
    
    # 检测操作系统
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
        MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
        DISK_GB=$(df -g / | awk 'NR==2{print $4}')
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="$PRETTY_NAME"
        MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
        DISK_GB=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')
    else
        OS="未知"
        MEMORY_GB=0
        DISK_GB=0
    fi
    
    print_message $BLUE "🖥️  操作系统: $OS"
    
    # 检查内存
    if [ "$MEMORY_GB" -ge 16 ]; then
        record_check "pass" "内存: ${MEMORY_GB}GB (推荐16GB+)"
    elif [ "$MEMORY_GB" -ge 8 ]; then
        record_check "warn" "内存: ${MEMORY_GB}GB (最低8GB，推荐16GB+)"
    else
        record_check "fail" "内存: ${MEMORY_GB}GB (不足8GB最低要求)"
    fi
    
    # 检查磁盘空间
    if [ "$DISK_GB" -ge 100 ]; then
        record_check "pass" "可用磁盘空间: ${DISK_GB}GB (推荐100GB+)"
    elif [ "$DISK_GB" -ge 50 ]; then
        record_check "warn" "可用磁盘空间: ${DISK_GB}GB (最低50GB，推荐100GB+)"
    else
        record_check "fail" "可用磁盘空间: ${DISK_GB}GB (不足50GB最低要求)"
    fi
    
    # 检查CPU核心数
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CPU_CORES=$(sysctl -n hw.ncpu)
    else
        CPU_CORES=$(nproc)
    fi
    
    if [ "$CPU_CORES" -ge 4 ]; then
        record_check "pass" "CPU核心数: $CPU_CORES (推荐4核+)"
    else
        record_check "warn" "CPU核心数: $CPU_CORES (推荐4核+)"
    fi
}

# 检查基础工具
check_basic_tools() {
    print_title "🛠️ 基础工具检查"
    
    check_command_exists "git" "Git版本控制"
    check_command_exists "curl" "网络工具curl"
    check_command_exists "wget" "网络工具wget" || record_check "warn" "wget: 未安装 (可选)"
    
    # 检查包管理器
    if [[ "$OSTYPE" == "darwin"* ]]; then
        check_command_exists "brew" "Homebrew包管理器"
    fi
    
    # 检查编辑器
    if command -v code &> /dev/null; then
        record_check "pass" "VS Code编辑器: 已安装"
    elif command -v vim &> /dev/null; then
        record_check "pass" "Vim编辑器: 已安装"
    else
        record_check "warn" "代码编辑器: 未检测到常用编辑器"
    fi
}

# 检查容器化工具
check_container_tools() {
    print_title "🐳 容器化工具检查"
    
    # 检查Docker
    if check_command_exists "docker" "Docker引擎"; then
        # 检查Docker服务状态
        check_service_status "Docker服务" "Docker守护进程" "docker info"
        
        # 检查Docker版本
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        local docker_major=$(echo $docker_version | cut -d. -f1)
        local docker_minor=$(echo $docker_version | cut -d. -f2)
        
        if [ "$docker_major" -gt 20 ] || ([ "$docker_major" -eq 20 ] && [ "$docker_minor" -ge 10 ]); then
            record_check "pass" "Docker版本检查: $docker_version (推荐20.10+)"
        else
            record_check "warn" "Docker版本检查: $docker_version (推荐升级到20.10+)"
        fi
        
        # 测试Docker功能
        if docker run --rm hello-world &> /dev/null; then
            record_check "pass" "Docker功能测试: Hello World容器运行成功"
        else
            record_check "fail" "Docker功能测试: 无法运行测试容器"
        fi
    fi
    
    # 检查Docker Compose
    if check_command_exists "docker-compose" "Docker Compose"; then
        # 检查版本
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        local compose_major=$(echo $compose_version | cut -d. -f1)
        
        if [ "$compose_major" -ge 2 ]; then
            record_check "pass" "Docker Compose版本: $compose_version (推荐2.0+)"
        else
            record_check "warn" "Docker Compose版本: $compose_version (推荐升级到2.0+)"
        fi
    fi
}

# 检查Kubernetes工具
check_kubernetes_tools() {
    print_title "⚙️ Kubernetes工具检查"
    
    check_command_exists "kubectl" "Kubernetes CLI"
    check_command_exists "minikube" "Minikube本地集群"
    check_command_exists "kind" "Kind集群工具"
    check_command_exists "helm" "Helm包管理器"
    
    # 检查kubectl配置
    if command -v kubectl &> /dev/null; then
        if kubectl config current-context &> /dev/null; then
            local current_context=$(kubectl config current-context)
            record_check "pass" "kubectl配置: 当前上下文 '$current_context'"
            
            # 检查集群连接
            if kubectl cluster-info &> /dev/null; then
                record_check "pass" "Kubernetes集群: 连接正常"
                
                # 检查节点状态
                local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
                local total_nodes=$(kubectl get nodes --no-headers | wc -l || echo "0")
                
                if [ "$ready_nodes" -gt 0 ]; then
                    record_check "pass" "集群节点状态: $ready_nodes/$total_nodes 节点就绪"
                else
                    record_check "fail" "集群节点状态: 没有就绪的节点"
                fi
                
                # 检查核心组件
                local system_pods=$(kubectl get pods -n kube-system --no-headers | grep -c "Running" || echo "0")
                if [ "$system_pods" -gt 0 ]; then
                    record_check "pass" "系统组件: $system_pods 个核心Pod运行中"
                else
                    record_check "fail" "系统组件: 核心组件未运行"
                fi
            else
                record_check "fail" "Kubernetes集群: 无法连接"
            fi
        else
            record_check "warn" "kubectl配置: 未配置集群上下文"
        fi
    fi
    
    # 检查Helm仓库
    if command -v helm &> /dev/null; then
        local repo_count=$(helm repo list 2>/dev/null | wc -l || echo "0")
        if [ "$repo_count" -gt 1 ]; then  # 减1是因为表头
            record_check "pass" "Helm仓库: 已配置 $((repo_count-1)) 个仓库"
        else
            record_check "warn" "Helm仓库: 未配置仓库，建议添加常用仓库"
        fi
    fi
}

# 检查监控工具
check_monitoring_tools() {
    print_title "📊 监控工具检查"
    
    check_command_exists "k9s" "Kubernetes集群管理工具"
    check_command_exists "kubectx" "Kubernetes上下文切换工具" || record_check "warn" "kubectx: 未安装 (可选但推荐)"
    check_command_exists "kubens" "Kubernetes命名空间切换工具" || record_check "warn" "kubens: 未安装 (可选但推荐)"
    
    # 检查监控堆栈是否部署
    if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
        if kubectl get namespace monitoring &> /dev/null; then
            record_check "pass" "监控命名空间: 已创建"
            
            # 检查Prometheus
            if kubectl get pods -n monitoring -l "app.kubernetes.io/name=prometheus" --no-headers 2>/dev/null | grep -q "Running"; then
                record_check "pass" "Prometheus: 运行中"
            else
                record_check "warn" "Prometheus: 未部署或未运行"
            fi
            
            # 检查Grafana
            if kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana" --no-headers 2>/dev/null | grep -q "Running"; then
                record_check "pass" "Grafana: 运行中"
            else
                record_check "warn" "Grafana: 未部署或未运行"
            fi
        else
            record_check "warn" "监控堆栈: 未部署 (可选)"
        fi
    fi
}

# 检查开发工具
check_development_tools() {
    print_title "💻 开发工具检查"
    
    # 检查Node.js
    if check_command_exists "node" "Node.js运行时"; then
        check_command_exists "npm" "NPM包管理器"
        
        # 检查Node.js版本
        local node_version=$(node --version | grep -oE '[0-9]+' | head -n1)
        if [ "$node_version" -ge 16 ]; then
            record_check "pass" "Node.js版本: $(node --version) (推荐16+)"
        else
            record_check "warn" "Node.js版本: $(node --version) (推荐升级到16+)"
        fi
    fi
    
    # 检查Python
    if check_command_exists "python3" "Python3运行时"; then
        check_command_exists "pip3" "Python包管理器"
        
        # 检查Python版本
        local python_version=$(python3 --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        local python_major=$(echo $python_version | cut -d. -f1)
        local python_minor=$(echo $python_version | cut -d. -f2)
        
        if [ "$python_major" -eq 3 ] && [ "$python_minor" -ge 8 ]; then
            record_check "pass" "Python版本: $(python3 --version) (推荐3.8+)"
        else
            record_check "warn" "Python版本: $(python3 --version) (推荐升级到3.8+)"
        fi
    fi
    
    # 检查Go
    check_command_exists "go" "Go语言工具链" || record_check "warn" "Go: 未安装 (可选)"
    
    # 检查其他工具
    check_command_exists "terraform" "Terraform基础设施工具" || record_check "warn" "Terraform: 未安装 (可选)"
    check_command_exists "jq" "JSON处理工具" || record_check "warn" "jq: 未安装 (推荐安装)"
}

# 检查网络连接
check_network_connectivity() {
    print_title "🌐 网络连接检查"
    
    # 检查基本网络连接
    if ping -c 1 google.com &> /dev/null; then
        record_check "pass" "互联网连接: 正常"
    else
        record_check "fail" "互联网连接: 无法访问外网"
    fi
    
    # 检查Docker Hub连接
    if curl -sSf https://registry-1.docker.io/v2/ &> /dev/null; then
        record_check "pass" "Docker Hub连接: 正常"
    else
        record_check "warn" "Docker Hub连接: 连接异常，可能需要配置镜像源"
    fi
    
    # 检查GitHub连接
    if curl -sSf https://api.github.com &> /dev/null; then
        record_check "pass" "GitHub连接: 正常"
    else
        record_check "warn" "GitHub连接: 连接异常"
    fi
    
    # 检查Kubernetes资源
    if curl -sSf https://dl.k8s.io &> /dev/null; then
        record_check "pass" "Kubernetes资源: 正常"
    else
        record_check "warn" "Kubernetes资源: 连接异常"
    fi
}

# 执行功能测试
run_functional_tests() {
    print_title "🧪 功能测试"
    
    # Docker功能测试
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        print_message $BLUE "🐳 执行Docker功能测试..."
        
        # 测试镜像拉取
        if docker pull alpine:latest &> /dev/null; then
            record_check "pass" "Docker镜像拉取: 成功"
            
            # 测试容器运行
            if docker run --rm alpine:latest echo "test" &> /dev/null; then
                record_check "pass" "Docker容器运行: 成功"
            else
                record_check "fail" "Docker容器运行: 失败"
            fi
        else
            record_check "fail" "Docker镜像拉取: 失败"
        fi
    fi
    
    # Kubernetes功能测试
    if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
        print_message $BLUE "⚙️ 执行Kubernetes功能测试..."
        
        # 创建测试Pod
        local test_pod_name="validation-test-$(date +%s)"
        if kubectl run "$test_pod_name" --image=nginx:latest --restart=Never --quiet &> /dev/null; then
            sleep 5
            
            # 检查Pod状态
            if kubectl get pod "$test_pod_name" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then
                record_check "pass" "Kubernetes Pod创建: 成功"
            else
                record_check "fail" "Kubernetes Pod创建: Pod未进入Running状态"
            fi
            
            # 清理测试Pod
            kubectl delete pod "$test_pod_name" --grace-period=0 --force &> /dev/null || true
        else
            record_check "fail" "Kubernetes Pod创建: 失败"
        fi
        
        # 测试Service创建
        if kubectl create service clusterip test-svc --tcp=80:80 --dry-run=client &> /dev/null; then
            record_check "pass" "Kubernetes Service测试: YAML生成成功"
        else
            record_check "fail" "Kubernetes Service测试: YAML生成失败"
        fi
    fi
}

# 生成建议
generate_recommendations() {
    print_title "💡 优化建议"
    
    if [ $CHECKS_FAILED -gt 0 ]; then
        print_message $RED "🚨 发现 $CHECKS_FAILED 个严重问题，需要立即解决:"
        print_message $BLUE "• 运行环境安装脚本: ./scripts/setup-environment.sh"
        print_message $BLUE "• 查看详细文档: docs/tools-setup.md"
    fi
    
    if [ $CHECKS_WARNING -gt 0 ]; then
        print_message $YELLOW "⚠️  发现 $CHECKS_WARNING 个警告，建议优化:"
        if ! command -v kubectl &> /dev/null || ! kubectl cluster-info &> /dev/null; then
            print_message $BLUE "• 创建Kubernetes集群: ./scripts/setup-kubernetes.sh create"
        fi
        if ! kubectl get namespace monitoring &> /dev/null 2>&1; then
            print_message $BLUE "• 部署监控堆栈: ./scripts/setup-monitoring.sh deploy"
        fi
    fi
    
    if [ $CHECKS_FAILED -eq 0 ] && [ $CHECKS_WARNING -eq 0 ]; then
        print_message $GREEN "🎉 环境配置完美！可以开始云原生学习之旅！"
        print_message $BLUE "• 开始第一个项目: ./scripts/quick-start.sh"
        print_message $BLUE "• 查看学习路径: docs/learning-path.md"
    fi
    
    echo
    print_message $CYAN "📚 推荐学习顺序:"
    print_message $BLUE "1. 容器化基础: projects/phase1-containerization/"
    print_message $BLUE "2. Kubernetes编排: projects/phase2-orchestration/"
    print_message $BLUE "3. 监控可观测: projects/phase3-monitoring/"
    print_message $BLUE "4. 生产级实践: projects/phase4-production/"
}

# 显示总结
show_summary() {
    print_title "📊 验证结果总结"
    
    print_message $CYAN "📋 检查统计:"
    print_message $GREEN "✅ 通过: $CHECKS_PASSED/$CHECKS_TOTAL"
    print_message $YELLOW "⚠️  警告: $CHECKS_WARNING/$CHECKS_TOTAL"
    print_message $RED "❌ 失败: $CHECKS_FAILED/$CHECKS_TOTAL"
    
    echo
    local pass_rate=$((CHECKS_PASSED * 100 / CHECKS_TOTAL))
    print_message $CYAN "🎯 通过率: $pass_rate%"
    
    if [ $pass_rate -ge 90 ]; then
        print_message $GREEN "🏆 优秀！环境配置非常完善"
    elif [ $pass_rate -ge 75 ]; then
        print_message $BLUE "👍 良好！大部分功能正常，建议优化警告项"
    elif [ $pass_rate -ge 50 ]; then
        print_message $YELLOW "⚠️  一般！存在一些问题，建议修复"
    else
        print_message $RED "❌ 需要改进！环境存在较多问题"
    fi
    
    echo
    print_message $PURPLE "📄 完整报告已保存到: /tmp/cloud-native-validation-$(date +%Y%m%d_%H%M%S).log"
}

# 保存报告
save_report() {
    local report_file="/tmp/cloud-native-validation-$(date +%Y%m%d_%H%M%S).log"
    {
        echo "云原生学习环境验证报告"
        echo "生成时间: $(date)"
        echo "=================================="
        echo "检查统计:"
        echo "- 总计: $CHECKS_TOTAL"
        echo "- 通过: $CHECKS_PASSED"
        echo "- 警告: $CHECKS_WARNING"
        echo "- 失败: $CHECKS_FAILED"
        echo "- 通过率: $((CHECKS_PASSED * 100 / CHECKS_TOTAL))%"
        echo "=================================="
    } > "$report_file"
    
    echo "$report_file"
}

# 显示帮助
show_help() {
    echo "云原生学习环境 - 验证测试脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  --quick              快速检查模式（跳过功能测试）"
    echo "  --full               完整检查模式（默认）"
    echo "  --report-only        只生成报告，不显示详细输出"
    echo
    echo "示例:"
    echo "  $0                   # 完整验证"
    echo "  $0 --quick           # 快速检查"
    echo "  $0 --report-only     # 静默模式"
    echo
}

# 主函数
main() {
    local mode="full"
    local report_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --quick)
                mode="quick"
                shift
                ;;
            --full)
                mode="full"
                shift
                ;;
            --report-only)
                report_only=true
                shift
                ;;
            *)
                print_message $RED "❌ 未知参数: $1"
                echo "使用 $0 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
    
    if [ "$report_only" = false ]; then
        print_title "云原生学习环境验证"
        print_message $BLUE "🔍 开始全面环境检查..."
        echo
    fi
    
    # 执行检查
    check_system_requirements
    check_basic_tools
    check_container_tools
    check_kubernetes_tools
    check_monitoring_tools
    check_development_tools
    check_network_connectivity
    
    if [ "$mode" = "full" ]; then
        run_functional_tests
    fi
    
    if [ "$report_only" = false ]; then
        generate_recommendations
        show_summary
    fi
    
    # 保存报告
    local report_file=$(save_report)
    
    if [ "$report_only" = true ]; then
        echo "报告已生成: $report_file"
        echo "通过率: $((CHECKS_PASSED * 100 / CHECKS_TOTAL))% ($CHECKS_PASSED/$CHECKS_TOTAL)"
    fi
    
    # 设置退出码
    if [ $CHECKS_FAILED -gt 0 ]; then
        exit 1
    elif [ $CHECKS_WARNING -gt 0 ]; then
        exit 2
    else
        exit 0
    fi
}

# 脚本入口
main "$@"