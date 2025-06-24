#!/bin/bash

# ==============================================================================
# 云原生学习环境 - 自动化环境设置脚本
# 支持 macOS、Ubuntu/Debian、CentOS/RHEL 系统
# ==============================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/cloud-native-setup.log"
INSTALL_MODE="full"  # full, basic, kubernetes, monitoring

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        ARCH=$(uname -m)
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        ARCH=$(uname -m)
    else
        echo "❌ 不支持的操作系统"
        exit 1
    fi
    
    echo "🖥️  检测到系统: $OS ($ARCH)"
}

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
}

# 打印标题
print_title() {
    echo
    print_message $CYAN "🚀 ================================"
    print_message $CYAN "   $1"
    print_message $CYAN "================================"
    echo
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查是否以root权限运行
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        print_message $RED "❌ 请不要以root用户运行此脚本"
        print_message $YELLOW "💡 脚本会在需要时自动请求sudo权限"
        exit 1
    fi
}

# 检查系统要求
check_system_requirements() {
    print_title "🔍 检查系统要求"
    
    # 检查内存
    if [[ "$OS" == "macos" ]]; then
        MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    else
        MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    fi
    
    if [ "$MEMORY_GB" -lt 8 ]; then
        print_message $YELLOW "⚠️  内存不足: ${MEMORY_GB}GB (推荐16GB以上)"
        print_message $YELLOW "💡 建议增加虚拟内存或关闭其他应用"
    else
        print_message $GREEN "✅ 内存充足: ${MEMORY_GB}GB"
    fi
    
    # 检查磁盘空间
    if [[ "$OS" == "macos" ]]; then
        DISK_GB=$(df -g / | awk 'NR==2{print $4}')
    else
        DISK_GB=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')
    fi
    
    if [ "$DISK_GB" -lt 50 ]; then
        print_message $YELLOW "⚠️  磁盘空间不足: ${DISK_GB}GB (推荐100GB以上)"
    else
        print_message $GREEN "✅ 磁盘空间充足: ${DISK_GB}GB"
    fi
}

# 安装包管理器 (macOS)
install_homebrew() {
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi
    
    print_title "🍺 安装 Homebrew"
    
    if command_exists brew; then
        print_message $GREEN "✅ Homebrew 已安装"
        return 0
    fi
    
    print_message $BLUE "📦 正在安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # 添加到PATH (Apple Silicon Mac)
    if [[ "$ARCH" == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    print_message $GREEN "✅ Homebrew 安装完成"
}

# 更新系统包
update_system() {
    print_title "🔄 更新系统包"
    
    case "$OS" in
        "macos")
            brew update
            ;;
        "ubuntu"|"debian")
            sudo apt update && sudo apt upgrade -y
            sudo apt install -y curl wget git vim build-essential apt-transport-https ca-certificates gnupg lsb-release
            ;;
        "centos"|"rhel"|"fedora")
            if command_exists dnf; then
                sudo dnf update -y
                sudo dnf install -y curl wget git vim gcc make
            else
                sudo yum update -y
                sudo yum install -y curl wget git vim gcc make
            fi
            ;;
    esac
    
    print_message $GREEN "✅ 系统包更新完成"
}

# 安装Git
install_git() {
    print_title "📋 安装 Git"
    
    if command_exists git; then
        print_message $GREEN "✅ Git 已安装: $(git --version)"
        return 0
    fi
    
    case "$OS" in
        "macos")
            brew install git
            ;;
        "ubuntu"|"debian")
            sudo apt install -y git
            ;;
        "centos"|"rhel"|"fedora")
            if command_exists dnf; then
                sudo dnf install -y git
            else
                sudo yum install -y git
            fi
            ;;
    esac
    
    print_message $GREEN "✅ Git 安装完成"
    
    # 配置Git（如果尚未配置）
    if ! git config --global user.name > /dev/null 2>&1; then
        print_message $YELLOW "⚙️  配置Git用户信息"
        read -p "请输入您的姓名: " git_name
        read -p "请输入您的邮箱: " git_email
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        print_message $GREEN "✅ Git 配置完成"
    fi
}

# 安装Docker
install_docker() {
    print_title "🐳 安装 Docker"
    
    if command_exists docker; then
        print_message $GREEN "✅ Docker 已安装: $(docker --version)"
        return 0
    fi
    
    case "$OS" in
        "macos")
            print_message $BLUE "📦 正在安装 Docker Desktop..."
            brew install --cask docker
            print_message $YELLOW "⚠️  请手动启动 Docker Desktop 应用"
            ;;
        "ubuntu"|"debian")
            # 卸载旧版本
            sudo apt remove -y docker docker-engine docker.io containerd runc || true
            
            # 添加Docker官方GPG密钥
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # 设置稳定版本仓库
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # 安装Docker Engine
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
            
            # 启动Docker服务
            sudo systemctl start docker
            sudo systemctl enable docker
            
            # 将用户添加到docker组
            sudo usermod -aG docker $USER
            ;;
        "centos"|"rhel"|"fedora")
            # 安装Docker
            if command_exists dnf; then
                sudo dnf install -y docker
            else
                sudo yum install -y docker
            fi
            
            # 启动Docker服务
            sudo systemctl start docker
            sudo systemctl enable docker
            
            # 将用户添加到docker组
            sudo usermod -aG docker $USER
            ;;
    esac
    
    print_message $GREEN "✅ Docker 安装完成"
    
    # 配置Docker镜像源
    setup_docker_registry_mirror
}

# 配置Docker镜像源
setup_docker_registry_mirror() {
    print_message $BLUE "⚙️  配置Docker镜像源..."
    
    if [[ "$OS" == "macos" ]]; then
        print_message $YELLOW "💡 macOS用户请在Docker Desktop设置中手动配置镜像源"
        print_message $BLUE "   推荐镜像源: https://mirror.ccs.tencentyun.com"
        return 0
    fi
    
    # Linux系统配置
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://reg-mirror.qiniu.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    
    sudo systemctl restart docker
    print_message $GREEN "✅ Docker镜像源配置完成"
}

# 安装Docker Compose
install_docker_compose() {
    print_title "🎼 安装 Docker Compose"
    
    if command_exists docker-compose; then
        print_message $GREEN "✅ Docker Compose 已安装: $(docker-compose --version)"
        return 0
    fi
    
    case "$OS" in
        "macos")
            # Docker Desktop已包含Docker Compose
            print_message $GREEN "✅ Docker Compose 已随Docker Desktop安装"
            ;;
        *)
            # 下载最新版本
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            
            # 创建软链接
            sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
            ;;
    esac
    
    print_message $GREEN "✅ Docker Compose 安装完成"
}

# 安装kubectl
install_kubectl() {
    print_title "⚙️ 安装 kubectl"
    
    if command_exists kubectl; then
        print_message $GREEN "✅ kubectl 已安装: $(kubectl version --client --short)"
        return 0
    fi
    
    case "$OS" in
        "macos")
            brew install kubectl
            ;;
        "ubuntu"|"debian")
            sudo apt-get update
            sudo apt-get install -y apt-transport-https ca-certificates curl
            sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
            echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update
            sudo apt-get install -y kubectl
            ;;
        *)
            # 通用安装方法
            KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
            curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
    esac
    
    print_message $GREEN "✅ kubectl 安装完成"
}

# 安装Minikube
install_minikube() {
    print_title "🚀 安装 Minikube"
    
    if command_exists minikube; then
        print_message $GREEN "✅ Minikube 已安装: $(minikube version --short)"
        return 0
    fi
    
    case "$OS" in
        "macos")
            brew install minikube
            ;;
        *)
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            chmod +x minikube-linux-amd64
            sudo mv minikube-linux-amd64 /usr/local/bin/minikube
            ;;
    esac
    
    print_message $GREEN "✅ Minikube 安装完成"
}

# 安装Kind
install_kind() {
    print_title "🎯 安装 Kind"
    
    if command_exists kind; then
        print_message $GREEN "✅ Kind 已安装: $(kind version)"
        return 0
    fi
    
    case "$OS" in
        "macos")
            brew install kind
            ;;
        *)
            KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
    esac
    
    print_message $GREEN "✅ Kind 安装完成"
}

# 安装Helm
install_helm() {
    print_title "⛵ 安装 Helm"
    
    if command_exists helm; then
        print_message $GREEN "✅ Helm 已安装: $(helm version --short)"
        return 0
    fi
    
    case "$OS" in
        "macos")
            brew install helm
            ;;
        *)
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            ;;
    esac
    
    # 添加常用Chart仓库
    helm repo add stable https://charts.helm.sh/stable
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    print_message $GREEN "✅ Helm 安装完成"
}

# 安装监控工具
install_monitoring_tools() {
    if [[ "$INSTALL_MODE" != "full" && "$INSTALL_MODE" != "monitoring" ]]; then
        return 0
    fi
    
    print_title "📊 安装监控工具"
    
    # 安装k9s
    if ! command_exists k9s; then
        case "$OS" in
            "macos")
                brew install k9s
                ;;
            *)
                K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
                curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_x86_64.tar.gz" | sudo tar xfz - -C /usr/local/bin k9s
                ;;
        esac
        print_message $GREEN "✅ k9s 安装完成"
    fi
    
    # 安装kubectx和kubens
    if ! command_exists kubectx; then
        case "$OS" in
            "macos")
                brew install kubectx
                ;;
            *)
                sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
                sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
                sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
                ;;
        esac
        print_message $GREEN "✅ kubectx & kubens 安装完成"
    fi
}

# 安装开发工具
install_development_tools() {
    print_title "🛠️ 安装开发工具"
    
    # 安装Node.js (通过nvm)
    if ! command_exists node; then
        print_message $BLUE "📦 正在安装 Node.js..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm use --lts
        print_message $GREEN "✅ Node.js 安装完成"
    fi
    
    # 安装Python3 (如果未安装)
    if ! command_exists python3; then
        case "$OS" in
            "macos")
                brew install python@3.9
                ;;
            "ubuntu"|"debian")
                sudo apt install -y python3 python3-pip
                ;;
            *)
                if command_exists dnf; then
                    sudo dnf install -y python3 python3-pip
                else
                    sudo yum install -y python3 python3-pip
                fi
                ;;
        esac
        print_message $GREEN "✅ Python3 安装完成"
    fi
}

# 创建工作目录
setup_workspace() {
    print_title "📁 设置工作空间"
    
    # 创建必要的目录
    mkdir -p ~/.kube
    mkdir -p ~/cloud-native-workspace
    
    # 创建kubectl自动补全
    if command_exists kubectl; then
        kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
        echo 'alias k=kubectl' >> ~/.bashrc
        echo 'complete -F __start_kubectl k' >> ~/.bashrc
    fi
    
    print_message $GREEN "✅ 工作空间设置完成"
}

# 验证安装
verify_installation() {
    print_title "✅ 验证安装"
    
    # 创建验证脚本
    cat > /tmp/verify-installation.sh << 'EOF'
#!/bin/bash

echo "🔍 验证云原生工具安装状态..."
echo "=================================="

# 基础工具
echo "📦 基础工具:"
command -v git >/dev/null 2>&1 && echo "✅ Git: $(git --version)" || echo "❌ Git: 未安装"
command -v docker >/dev/null 2>&1 && echo "✅ Docker: $(docker --version)" || echo "❌ Docker: 未安装"
command -v docker-compose >/dev/null 2>&1 && echo "✅ Docker Compose: $(docker-compose --version)" || echo "❌ Docker Compose: 未安装"

echo ""
echo "☸️ Kubernetes工具:"
command -v kubectl >/dev/null 2>&1 && echo "✅ kubectl: $(kubectl version --client --short)" || echo "❌ kubectl: 未安装"
command -v minikube >/dev/null 2>&1 && echo "✅ Minikube: $(minikube version --short)" || echo "❌ Minikube: 未安装"
command -v kind >/dev/null 2>&1 && echo "✅ Kind: $(kind version)" || echo "❌ Kind: 未安装"
command -v helm >/dev/null 2>&1 && echo "✅ Helm: $(helm version --short)" || echo "❌ Helm: 未安装"

echo ""
echo "🛠️ 开发工具:"
command -v node >/dev/null 2>&1 && echo "✅ Node.js: $(node --version)" || echo "❌ Node.js: 未安装"
command -v python3 >/dev/null 2>&1 && echo "✅ Python: $(python3 --version)" || echo "❌ Python: 未安装"

echo ""
echo "🔧 管理工具:"
command -v k9s >/dev/null 2>&1 && echo "✅ k9s: $(k9s version --short)" || echo "❌ k9s: 未安装"
command -v kubectx >/dev/null 2>&1 && echo "✅ kubectx: 已安装" || echo "❌ kubectx: 未安装"

echo ""
echo "=================================="
echo "✨ 验证完成！"
EOF
    
    chmod +x /tmp/verify-installation.sh
    /tmp/verify-installation.sh
}

# 显示后续步骤
show_next_steps() {
    print_title "🎉 安装完成"
    
    print_message $GREEN "🎊 恭喜！云原生学习环境安装完成！"
    echo
    
    print_message $CYAN "📚 下一步建议："
    print_message $BLUE "1. 重新登录终端或执行: source ~/.bashrc"
    print_message $BLUE "2. 启动第一个Kubernetes集群: minikube start"
    print_message $BLUE "3. 验证集群状态: kubectl cluster-info"
    print_message $BLUE "4. 开始第一个项目: cd $PROJECT_ROOT && ./scripts/quick-start.sh"
    echo
    
    print_message $CYAN "🔗 有用的命令："
    print_message $BLUE "• 查看Docker状态: docker info"
    print_message $BLUE "• 启动Minikube: minikube start --driver=docker"
    print_message $BLUE "• 创建Kind集群: kind create cluster"
    print_message $BLUE "• Kubernetes管理: k9s"
    echo
    
    print_message $CYAN "📖 学习资源："
    print_message $BLUE "• 文档目录: $PROJECT_ROOT/docs/"
    print_message $BLUE "• 实践项目: $PROJECT_ROOT/projects/"
    print_message $BLUE "• 配置模板: $PROJECT_ROOT/templates/"
    echo
    
    if [[ "$OS" != "macos" ]]; then
        print_message $YELLOW "⚠️  重要提醒：需要重新登录或执行以下命令使Docker组权限生效："
        print_message $BLUE "   newgrp docker"
    fi
}

# 显示帮助信息
show_help() {
    echo "云原生学习环境 - 自动化安装脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -m, --mode MODE      安装模式 (full|basic|kubernetes|monitoring)"
    echo "  --skip-docker        跳过Docker安装"
    echo "  --skip-k8s           跳过Kubernetes工具安装"
    echo "  --skip-dev           跳过开发工具安装"
    echo
    echo "安装模式:"
    echo "  full                 完整安装（推荐）"
    echo "  basic                基础工具（Docker + Git）"
    echo "  kubernetes           Kubernetes相关工具"
    echo "  monitoring           监控管理工具"
    echo
    echo "示例:"
    echo "  $0                   # 完整安装"
    echo "  $0 -m basic          # 只安装基础工具"
    echo "  $0 --skip-docker     # 跳过Docker安装"
    echo
}

# 主函数
main() {
    # 默认参数
    SKIP_DOCKER=false
    SKIP_K8S=false
    SKIP_DEV=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -m|--mode)
                INSTALL_MODE="$2"
                shift 2
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --skip-k8s)
                SKIP_K8S=true
                shift
                ;;
            --skip-dev)
                SKIP_DEV=true
                shift
                ;;
            *)
                print_message $RED "❌ 未知参数: $1"
                echo "使用 $0 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
    
    # 检查sudo权限
    check_sudo
    
    # 初始化日志
    echo "云原生环境安装日志 - $(date)" > "$LOG_FILE"
    
    # 检测操作系统
    detect_os
    
    # 显示安装信息
    print_title "云原生学习环境 - 自动化安装"
    print_message $BLUE "🖥️  操作系统: $OS"
    print_message $BLUE "🎯 安装模式: $INSTALL_MODE"
    print_message $BLUE "📝 日志文件: $LOG_FILE"
    
    # 系统检查
    check_system_requirements
    
    # 根据安装模式执行
    case "$INSTALL_MODE" in
        "full")
            install_homebrew
            update_system
            install_git
            [[ "$SKIP_DOCKER" != true ]] && install_docker && install_docker_compose
            [[ "$SKIP_K8S" != true ]] && install_kubectl && install_minikube && install_kind && install_helm
            install_monitoring_tools
            [[ "$SKIP_DEV" != true ]] && install_development_tools
            setup_workspace
            ;;
        "basic")
            install_homebrew
            update_system
            install_git
            [[ "$SKIP_DOCKER" != true ]] && install_docker && install_docker_compose
            ;;
        "kubernetes")
            [[ "$SKIP_K8S" != true ]] && install_kubectl && install_minikube && install_kind && install_helm
            install_monitoring_tools
            ;;
        "monitoring")
            install_monitoring_tools
            ;;
        *)
            print_message $RED "❌ 无效的安装模式: $INSTALL_MODE"
            exit 1
            ;;
    esac
    
    # 验证安装
    verify_installation
    
    # 显示后续步骤
    show_next_steps
}

# 脚本入口
main "$@"