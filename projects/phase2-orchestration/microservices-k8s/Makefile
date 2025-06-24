# ==============================================================================
# 微服务Kubernetes部署项目 - Makefile
# 项目管理和自动化部署工具
# ==============================================================================

.PHONY: help build-images deploy status clean test scale-all get-url logs health check

# 默认目标
.DEFAULT_GOAL := help

# 项目配置
PROJECT_NAME := microservices-k8s
NAMESPACE := ecommerce-k8s
DOCKER_REGISTRY := # 留空使用本地镜像
IMAGE_TAG := 1.0
REPLICAS := 2

# 第一阶段项目路径
ECOMMERCE_BASIC_PATH := ../../phase1-containerization/ecommerce-basic

# 颜色定义
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m

help: ## 显示帮助信息
	@echo "$(CYAN)微服务Kubernetes部署项目 - 管理命令$(NC)"
	@echo "========================================="
	@echo ""
	@echo "$(YELLOW)构建命令:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)使用示例:$(NC)"
	@echo "  make build-images  # 构建所有微服务镜像"
	@echo "  make deploy        # 部署到Kubernetes"
	@echo "  make status        # 查看部署状态"
	@echo "  make test          # 运行测试"
	@echo "  make clean         # 清理资源"

build-images: ## 构建所有微服务镜像
	@echo "$(CYAN)🔨 构建微服务镜像...$(NC)"
	@if [ ! -d "$(ECOMMERCE_BASIC_PATH)" ]; then \
		echo "$(RED)❌ 找不到第一阶段项目: $(ECOMMERCE_BASIC_PATH)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)📁 切换到第一阶段项目目录$(NC)"
	@cd $(ECOMMERCE_BASIC_PATH) && \
	if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then \
		echo "$(BLUE)🐳 配置Minikube Docker环境$(NC)"; \
		eval $$(minikube docker-env) && make build; \
	else \
		echo "$(BLUE)🐳 使用本地Docker环境$(NC)"; \
		make build; \
	fi
	@echo "$(GREEN)✅ 镜像构建完成$(NC)"

check-images: ## 检查镜像是否存在
	@echo "$(CYAN)🔍 检查镜像状态...$(NC)"
	@if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then \
		eval $$(minikube docker-env) && \
		docker images | grep -E "(user-service|product-service|order-service|notification-service)" || \
		(echo "$(YELLOW)⚠️  镜像不存在，请先运行 make build-images$(NC)" && exit 1); \
	else \
		docker images | grep -E "(user-service|product-service|order-service|notification-service)" || \
		(echo "$(YELLOW)⚠️  镜像不存在，请先运行 make build-images$(NC)" && exit 1); \
	fi
	@echo "$(GREEN)✅ 镜像检查通过$(NC)"

create-namespace: ## 创建命名空间
	@echo "$(CYAN)📦 创建命名空间 $(NAMESPACE)...$(NC)"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "$(GREEN)✅ 命名空间创建完成$(NC)"

deploy-secrets: ## 部署密钥配置
	@echo "$(CYAN)🔐 部署密钥配置...$(NC)"
	@kubectl apply -f k8s/secrets/
	@echo "$(GREEN)✅ 密钥配置完成$(NC)"

deploy-configmaps: ## 部署配置映射
	@echo "$(CYAN)⚙️  部署配置映射...$(NC)"
	@kubectl apply -f k8s/configmaps/
	@echo "$(GREEN)✅ 配置映射完成$(NC)"

deploy-storage: ## 部署存储配置
	@echo "$(CYAN)💾 部署存储配置...$(NC)"
	@kubectl apply -f k8s/storage/
	@echo "$(GREEN)✅ 存储配置完成$(NC)"

deploy-infrastructure: ## 部署基础设施
	@echo "$(CYAN)🏗️  部署基础设施服务...$(NC)"
	@kubectl apply -f k8s/infrastructure/
	@echo "$(BLUE)⏳ 等待基础设施服务就绪...$(NC)"
	@kubectl wait --for=condition=ready pod -l tier=infrastructure -n $(NAMESPACE) --timeout=300s || echo "$(YELLOW)⚠️  基础设施启动可能需要更多时间$(NC)"
	@echo "$(GREEN)✅ 基础设施部署完成$(NC)"

deploy-microservices: ## 部署微服务
	@echo "$(CYAN)🚀 部署微服务应用...$(NC)"
	@kubectl apply -f k8s/microservices/
	@echo "$(BLUE)⏳ 等待微服务就绪...$(NC)"
	@kubectl wait --for=condition=ready pod -l tier=backend -n $(NAMESPACE) --timeout=300s || echo "$(YELLOW)⚠️  微服务启动可能需要更多时间$(NC)"
	@echo "$(GREEN)✅ 微服务部署完成$(NC)"

deploy-gateway: ## 部署API网关
	@echo "$(CYAN)🌐 部署API网关...$(NC)"
	@kubectl apply -f k8s/gateway/
	@echo "$(BLUE)⏳ 等待网关就绪...$(NC)"
	@kubectl wait --for=condition=ready pod -l tier=frontend -n $(NAMESPACE) --timeout=120s || echo "$(YELLOW)⚠️  网关启动可能需要更多时间$(NC)"
	@echo "$(GREEN)✅ API网关部署完成$(NC)"

deploy-ingress: ## 部署Ingress配置
	@echo "$(CYAN)🔗 部署Ingress配置...$(NC)"
	@kubectl apply -f k8s/ingress/ || echo "$(YELLOW)⚠️  Ingress配置可选，如未安装Ingress控制器则跳过$(NC)"
	@echo "$(GREEN)✅ Ingress配置完成$(NC)"

deploy: check-images create-namespace deploy-secrets deploy-configmaps deploy-storage deploy-infrastructure deploy-microservices deploy-gateway deploy-ingress ## 完整部署所有组件
	@echo "$(GREEN)🎉 部署完成！$(NC)"
	@echo ""
	@make status
	@echo ""
	@make get-url

status: ## 查看部署状态
	@echo "$(CYAN)📊 部署状态检查$(NC)"
	@echo ""
	@echo "$(YELLOW)📦 命名空间状态:$(NC)"
	@kubectl get ns $(NAMESPACE) 2>/dev/null || echo "$(RED)❌ 命名空间不存在$(NC)"
	@echo ""
	@echo "$(YELLOW)🚀 Pod状态:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -o wide 2>/dev/null || echo "$(RED)❌ 无Pod运行$(NC)"
	@echo ""
	@echo "$(YELLOW)🌐 服务状态:$(NC)"
	@kubectl get services -n $(NAMESPACE) 2>/dev/null || echo "$(RED)❌ 无服务运行$(NC)"
	@echo ""
	@echo "$(YELLOW)📊 部署状态:$(NC)"
	@kubectl get deployments -n $(NAMESPACE) 2>/dev/null || echo "$(RED)❌ 无部署$(NC)"
	@echo ""
	@echo "$(YELLOW)💾 存储状态:$(NC)"
	@kubectl get pvc -n $(NAMESPACE) 2>/dev/null || echo "$(BLUE)ℹ️  无持久化存储$(NC)"

health: ## 健康检查
	@echo "$(CYAN)🏥 执行健康检查...$(NC)"
	@./scripts/health-check.sh || echo "$(YELLOW)⚠️  健康检查脚本不存在，使用基础检查$(NC)"
	@echo ""
	@echo "$(BLUE)🔍 检查关键组件状态:$(NC)"
	@for component in postgres redis rabbitmq user-service product-service order-service notification-service api-gateway; do \
		echo -n "  $$component: "; \
		if kubectl get pods -l app=$$component -n $(NAMESPACE) | grep -q "1/1.*Running"; then \
			echo "$(GREEN)✅ 健康$(NC)"; \
		else \
			echo "$(RED)❌ 异常$(NC)"; \
		fi; \
	done

get-url: ## 获取访问地址
	@echo "$(CYAN)🌍 获取访问地址...$(NC)"
	@if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then \
		echo "$(GREEN)📍 Minikube访问地址:$(NC)"; \
		minikube service api-gateway -n $(NAMESPACE) --url 2>/dev/null || echo "$(YELLOW)⚠️  API网关服务未就绪$(NC)"; \
	else \
		NODE_PORT=$$(kubectl get service api-gateway -n $(NAMESPACE) -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null); \
		if [ -n "$$NODE_PORT" ]; then \
			echo "$(GREEN)📍 NodePort访问地址: http://<节点IP>:$$NODE_PORT$(NC)"; \
		else \
			echo "$(YELLOW)⚠️  无法获取访问地址，请检查服务状态$(NC)"; \
		fi; \
	fi
	@echo ""
	@echo "$(BLUE)💡 提示: 也可以使用端口转发访问$(NC)"
	@echo "kubectl port-forward service/api-gateway 8080:80 -n $(NAMESPACE)"

logs: ## 查看服务日志
	@echo "$(CYAN)📋 查看服务日志...$(NC)"
	@./scripts/logs.sh || kubectl logs -l tier=backend -n $(NAMESPACE) --tail=50

verify: ## 验证部署状态
	@echo "$(CYAN)🔍 验证部署状态...$(NC)"
	@if [ -f "scripts/verify-deployment.sh" ]; then \
		./scripts/verify-deployment.sh; \
	else \
		echo "$(YELLOW)⚠️  验证脚本不存在，使用基础检查$(NC)"; \
		make health; \
	fi

test: ## 运行API测试
	@echo "$(CYAN)🧪 运行API测试...$(NC)"
	@if [ -f "tests/api-tests.sh" ]; then \
		./tests/api-tests.sh; \
	else \
		echo "$(YELLOW)⚠️  测试脚本不存在，手动测试:$(NC)"; \
		echo "kubectl run test-pod --image=busybox --rm -it --restart=Never -n $(NAMESPACE) -- sh"; \
	fi

load-test: ## 运行负载测试
	@echo "$(CYAN)⚡ 运行负载测试...$(NC)"
	@if [ -f "tests/load-tests.sh" ]; then \
		./tests/load-tests.sh; \
	else \
		echo "$(YELLOW)⚠️  负载测试脚本不存在$(NC)"; \
	fi

scale: ## 扩缩容服务 (使用: make scale SERVICE=user-service REPLICAS=5)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make scale SERVICE=user-service REPLICAS=5$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(REPLICAS)" ]; then \
		echo "$(RED)❌ 请指定副本数: make scale SERVICE=user-service REPLICAS=5$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)📈 扩缩容 $(SERVICE) 到 $(REPLICAS) 个副本...$(NC)"
	@kubectl scale deployment $(SERVICE) --replicas=$(REPLICAS) -n $(NAMESPACE)
	@echo "$(GREEN)✅ 扩缩容完成$(NC)"

scale-all: ## 扩缩容所有微服务 (使用: make scale-all REPLICAS=3)
	@if [ -z "$(REPLICAS)" ]; then \
		echo "$(RED)❌ 请指定副本数: make scale-all REPLICAS=3$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)📈 扩缩容所有微服务到 $(REPLICAS) 个副本...$(NC)"
	@for service in user-service product-service order-service notification-service; do \
		echo "$(BLUE)📊 扩缩容 $$service...$(NC)"; \
		kubectl scale deployment $$service --replicas=$(REPLICAS) -n $(NAMESPACE); \
	done
	@echo "$(GREEN)✅ 所有服务扩缩容完成$(NC)"

restart: ## 重启指定服务 (使用: make restart SERVICE=user-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make restart SERVICE=user-service$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)🔄 重启 $(SERVICE)...$(NC)"
	@kubectl rollout restart deployment $(SERVICE) -n $(NAMESPACE)
	@kubectl rollout status deployment $(SERVICE) -n $(NAMESPACE)
	@echo "$(GREEN)✅ $(SERVICE) 重启完成$(NC)"

clean: ## 清理所有资源
	@echo "$(YELLOW)⚠️  警告: 这将删除 $(NAMESPACE) 命名空间下的所有资源$(NC)"
	@read -p "确认继续? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(CYAN)🗑️  清理资源...$(NC)"; \
		kubectl delete namespace $(NAMESPACE) --ignore-not-found=true; \
		echo "$(GREEN)✅ 资源清理完成$(NC)"; \
	else \
		echo "$(BLUE)ℹ️  操作已取消$(NC)"; \
	fi

clean-force: ## 强制清理所有资源
	@echo "$(CYAN)🗑️  强制清理资源...$(NC)"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)✅ 资源清理完成$(NC)"

update: ## 更新指定服务镜像 (使用: make update SERVICE=user-service IMAGE=user-service:v2.0)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make update SERVICE=user-service IMAGE=user-service:v2.0$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(IMAGE)" ]; then \
		echo "$(RED)❌ 请指定镜像: make update SERVICE=user-service IMAGE=user-service:v2.0$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)🔄 更新 $(SERVICE) 镜像到 $(IMAGE)...$(NC)"
	@kubectl set image deployment/$(SERVICE) $(SERVICE)=$(IMAGE) -n $(NAMESPACE)
	@kubectl rollout status deployment/$(SERVICE) -n $(NAMESPACE)
	@echo "$(GREEN)✅ $(SERVICE) 更新完成$(NC)"

rollback: ## 回滚指定服务 (使用: make rollback SERVICE=user-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make rollback SERVICE=user-service$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)⏪ 回滚 $(SERVICE)...$(NC)"
	@kubectl rollout undo deployment/$(SERVICE) -n $(NAMESPACE)
	@kubectl rollout status deployment/$(SERVICE) -n $(NAMESPACE)
	@echo "$(GREEN)✅ $(SERVICE) 回滚完成$(NC)"

debug: ## 调试模式 - 创建调试Pod
	@echo "$(CYAN)🐛 创建调试Pod...$(NC)"
	@kubectl run debug-pod --image=busybox --rm -it --restart=Never -n $(NAMESPACE) -- sh

describe: ## 查看指定资源详情 (使用: make describe RESOURCE=pod/user-service-xxx)
	@if [ -z "$(RESOURCE)" ]; then \
		echo "$(RED)❌ 请指定资源: make describe RESOURCE=pod/user-service-xxx$(NC)"; \
		exit 1; \
	fi
	@kubectl describe $(RESOURCE) -n $(NAMESPACE)

port-forward: ## 端口转发到本地 (使用: make port-forward SERVICE=api-gateway LOCAL_PORT=8080)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make port-forward SERVICE=api-gateway LOCAL_PORT=8080$(NC)"; \
		exit 1; \
	fi
	@LOCAL_PORT=$${LOCAL_PORT:-8080}; \
	echo "$(CYAN)🔗 端口转发 $(SERVICE) 到本地端口 $$LOCAL_PORT...$(NC)"; \
	kubectl port-forward service/$(SERVICE) $$LOCAL_PORT:80 -n $(NAMESPACE)

config: ## 显示当前配置
	@echo "$(CYAN)⚙️  当前配置:$(NC)"
	@echo "  项目名称: $(PROJECT_NAME)"
	@echo "  命名空间: $(NAMESPACE)"
	@echo "  镜像标签: $(IMAGE_TAG)"
	@echo "  默认副本数: $(REPLICAS)"
	@echo "  第一阶段项目路径: $(ECOMMERCE_BASIC_PATH)"

# 开发环境快捷命令
dev-deploy: build-images deploy ## 开发环境一键部署

dev-restart: ## 开发环境重启所有服务
	@for service in user-service product-service order-service notification-service; do \
		make restart SERVICE=$$service; \
	done

dev-logs: ## 开发环境查看所有服务日志
	@kubectl logs -f -l tier=backend -n $(NAMESPACE) --max-log-requests=10

# 生产环境命令
prod-check: ## 生产环境检查
	@echo "$(CYAN)🔍 生产环境检查...$(NC)"
	@echo "$(BLUE)检查资源限制...$(NC)"
	@kubectl get pods -n $(NAMESPACE) -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}' || echo "无Pod运行"
	@echo ""
	@echo "$(BLUE)检查健康探针...$(NC)"
	@kubectl get pods -n $(NAMESPACE) -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].livenessProbe.httpGet.path}{"\n"}{end}' || echo "无健康探针"

version: ## 显示版本信息
	@echo "$(CYAN)📋 版本信息:$(NC)"
	@echo "  项目版本: 1.0.0"
	@echo "  Kubernetes版本: $$(kubectl version --short --client 2>/dev/null || echo '未知')"
	@echo "  Docker版本: $$(docker --version 2>/dev/null || echo '未安装')"
	@if command -v minikube >/dev/null 2>&1; then \
		echo "  Minikube版本: $$(minikube version --short 2>/dev/null || echo '未运行')"; \
	fi