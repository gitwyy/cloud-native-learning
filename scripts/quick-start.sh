#!/bin/bash

# ==============================================================================
# 云原生学习项目 - 快速开始脚本
# 一键启动第一阶段容器化项目
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

# 项目配置
PROJECT_NAME="simple-web-app"
PROJECT_DIR="projects/phase1-containerization/simple-web-app"
CONTAINER_NAME="simple-web-app"
IMAGE_NAME="simple-web-app:latest"
HOST_PORT=8080
NGINX_PORT=80

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
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
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_message $RED "❌ 错误: $1 未安装或不在PATH中"
        print_message $YELLOW "请先安装 $1"
        exit 1
    fi
}

# 检查Docker是否运行
check_docker_running() {
    if ! docker info &> /dev/null; then
        print_message $RED "❌ 错误: Docker 未运行"
        print_message $YELLOW "请启动Docker Desktop或Docker服务"
        exit 1
    fi
}

# 清理现有容器和镜像
cleanup() {
    print_title "🧹 清理现有资源"
    
    # 停止并删除容器
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_message $YELLOW "⏹️  停止现有容器: ${CONTAINER_NAME}"
        docker stop ${CONTAINER_NAME} || true
        print_message $YELLOW "🗑️  删除现有容器: ${CONTAINER_NAME}"
        docker rm ${CONTAINER_NAME} || true
    fi
    
    # 停止并删除Docker Compose服务
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        print_message $YELLOW "🛑 停止Docker Compose服务"
        cd ${PROJECT_DIR}
        docker-compose down --remove-orphans || true
        cd - > /dev/null
    fi
    
    print_message $GREEN "✅ 清理完成"
}

# 构建镜像
build_image() {
    print_title "🔨 构建Docker镜像"
    
    if [ ! -d "${PROJECT_DIR}" ]; then
        print_message $RED "❌ 错误: 项目目录不存在: ${PROJECT_DIR}"
        exit 1
    fi
    
    cd ${PROJECT_DIR}
    
    print_message $BLUE "📦 构建镜像: ${IMAGE_NAME}"
    docker build -t ${IMAGE_NAME} .
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 镜像构建成功"
        print_message $CYAN "📋 镜像信息:"
        docker images ${IMAGE_NAME}
    else
        print_message $RED "❌ 镜像构建失败"
        exit 1
    fi
    
    cd - > /dev/null
}

# 运行单容器模式
run_single_container() {
    print_title "🚀 启动单容器模式"
    
    print_message $BLUE "▶️  启动容器: ${CONTAINER_NAME}"
    docker run -d \
        --name ${CONTAINER_NAME} \
        -p ${HOST_PORT}:5000 \
        --restart unless-stopped \
        --env FLASK_ENV=production \
        --env FLASK_DEBUG=false \
        ${IMAGE_NAME}
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 容器启动成功"
        print_message $CYAN "🌐 访问地址: http://localhost:${HOST_PORT}"
    else
        print_message $RED "❌ 容器启动失败"
        exit 1
    fi
}

# 运行Docker Compose模式
run_compose_mode() {
    print_title "🎼 启动Docker Compose模式"
    
    cd ${PROJECT_DIR}
    
    # 创建必要的目录
    mkdir -p logs logs/nginx
    
    print_message $BLUE "🎵 启动多容器编排"
    BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') docker-compose up -d --build
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ Docker Compose 启动成功"
        print_message $CYAN "🌐 Nginx代理: http://localhost:${NGINX_PORT}"
        print_message $CYAN "🔧 直接访问应用: http://localhost:${HOST_PORT}"
    else
        print_message $RED "❌ Docker Compose 启动失败"
        exit 1
    fi
    
    cd - > /dev/null
}

# 检查服务状态
check_status() {
    print_title "📊 检查服务状态"
    
    # 等待服务启动
    print_message $YELLOW "⏳ 等待服务启动..."
    sleep 5
    
    # 检查容器状态
    print_message $CYAN "📋 容器状态:"
    if [ "$MODE" = "compose" ]; then
        cd ${PROJECT_DIR}
        docker-compose ps
        cd - > /dev/null
    else
        docker ps | grep ${CONTAINER_NAME} || echo "容器未找到"
    fi
    
    echo
    
    # 健康检查
    print_message $CYAN "🏥 健康检查:"
    
    # 检查应用健康状态
    if curl -sf "http://localhost:${HOST_PORT}/health" > /dev/null 2>&1; then
        print_message $GREEN "✅ 应用健康检查通过"
    else
        print_message $RED "❌ 应用健康检查失败"
        print_message $YELLOW "🔍 检查容器日志:"
        docker logs ${CONTAINER_NAME} --tail 20
    fi
    
    # 如果是compose模式，检查Nginx
    if [ "$MODE" = "compose" ]; then
        if curl -sf "http://localhost:${NGINX_PORT}/health" > /dev/null 2>&1; then
            print_message $GREEN "✅ Nginx代理健康检查通过"
        else
            print_message $RED "❌ Nginx代理健康检查失败"
        fi
    fi
}

# 显示访问信息
show_access_info() {
    print_title "🎉 启动完成"
    
    print_message $GREEN "🎊 恭喜！您的第一个容器化应用已成功启动！"
    echo
    
    if [ "$MODE" = "compose" ]; then
        print_message $CYAN "🌐 访问地址:"
        print_message $BLUE "   • Nginx代理: http://localhost:${NGINX_PORT}"
        print_message $BLUE "   • 直接访问: http://localhost:${HOST_PORT}"
    else
        print_message $CYAN "🌐 访问地址:"
        print_message $BLUE "   • 应用主页: http://localhost:${HOST_PORT}"
    fi
    
    echo
    print_message $CYAN "🔧 API端点:"
    print_message $BLUE "   • 健康检查: http://localhost:${HOST_PORT}/health"
    print_message $BLUE "   • 系统信息: http://localhost:${HOST_PORT}/api/info"
    print_message $BLUE "   • 统计信息: http://localhost:${HOST_PORT}/api/stats"
    
    echo
    print_message $CYAN "📋 管理命令:"
    if [ "$MODE" = "compose" ]; then
        print_message $BLUE "   • 查看日志: docker-compose -f ${PROJECT_DIR}/docker-compose.yml logs -f"
        print_message $BLUE "   • 停止服务: docker-compose -f ${PROJECT_DIR}/docker-compose.yml down"
        print_message $BLUE "   • 重启服务: docker-compose -f ${PROJECT_DIR}/docker-compose.yml restart"
    else
        print_message $BLUE "   • 查看日志: docker logs -f ${CONTAINER_NAME}"
        print_message $BLUE "   • 停止容器: docker stop ${CONTAINER_NAME}"
        print_message $BLUE "   • 重启容器: docker restart ${CONTAINER_NAME}"
    fi
    
    echo
    print_message $PURPLE "📚 下一步学习:"
    print_message $BLUE "   • 查看容器内部: docker exec -it ${CONTAINER_NAME} /bin/bash"
    print_message $BLUE "   • 查看镜像层: docker history ${IMAGE_NAME}"
    print_message $BLUE "   • 学习Docker Compose: cd ${PROJECT_DIR} && docker-compose --help"
    
    echo
}

# 显示帮助信息
show_help() {
    echo "云原生学习项目 - 快速开始脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -m, --mode MODE      运行模式 (single|compose)"
    echo "  -c, --clean          启动前清理现有资源"
    echo "  --no-build           跳过镜像构建步骤"
    echo "  --no-check           跳过健康检查"
    echo
    echo "运行模式:"
    echo "  single               单容器模式（仅应用容器）"
    echo "  compose              Docker Compose模式（应用+Nginx）"
    echo
    echo "示例:"
    echo "  $0                   # 默认单容器模式"
    echo "  $0 -m compose        # Docker Compose模式"
    echo "  $0 -c -m compose     # 清理后启动Compose模式"
    echo
}

# 主函数
main() {
    # 默认参数
    MODE="single"
    CLEAN=false
    BUILD=true
    CHECK=true
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN=true
                shift
                ;;
            --no-build)
                BUILD=false
                shift
                ;;
            --no-check)
                CHECK=false
                shift
                ;;
            *)
                print_message $RED "❌ 未知参数: $1"
                echo "使用 $0 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
    
    # 验证模式
    if [[ "$MODE" != "single" && "$MODE" != "compose" ]]; then
        print_message $RED "❌ 错误: 无效的运行模式 '$MODE'"
        print_message $YELLOW "支持的模式: single, compose"
        exit 1
    fi
    
    # 显示启动信息
    print_title "云原生学习项目 - 快速开始"
    print_message $BLUE "📁 项目目录: ${PROJECT_DIR}"
    print_message $BLUE "🎯 运行模式: ${MODE}"
    print_message $BLUE "🧹 清理资源: ${CLEAN}"
    print_message $BLUE "🔨 构建镜像: ${BUILD}"
    
    # 环境检查
    print_title "🔍 环境检查"
    check_command "docker"
    if [ "$MODE" = "compose" ]; then
        check_command "docker-compose"
    fi
    check_command "curl"
    check_docker_running
    print_message $GREEN "✅ 环境检查通过"
    
    # 清理（如果需要）
    if [ "$CLEAN" = true ]; then
        cleanup
    fi
    
    # 构建镜像
    if [ "$BUILD" = true ]; then
        build_image
    fi
    
    # 启动服务
    if [ "$MODE" = "compose" ]; then
        run_compose_mode
    else
        run_single_container
    fi
    
    # 检查状态
    if [ "$CHECK" = true ]; then
        check_status
    fi
    
    # 显示访问信息
    show_access_info
}

# 脚本入口
main "$@"