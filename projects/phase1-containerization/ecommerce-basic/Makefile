# ==============================================================================
# 电商应用基础版 - Makefile
# 项目管理和部署自动化
# ==============================================================================

.PHONY: help build up down restart logs clean test health setup

# 默认目标
.DEFAULT_GOAL := help

# 项目配置
PROJECT_NAME := ecommerce-basic
COMPOSE_FILE := docker-compose.yml
ENV_FILE := .env

# 颜色定义
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

help: ## 显示帮助信息
	@echo "$(CYAN)电商应用基础版 - 项目管理命令$(NC)"
	@echo "=================================="
	@echo ""
	@echo "$(YELLOW)基础命令:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)使用示例:$(NC)"
	@echo "  make setup     # 初始化项目环境"
	@echo "  make up        # 启动所有服务"
	@echo "  make logs      # 查看服务日志"
	@echo "  make health    # 检查服务健康状态"
	@echo "  make down      # 停止所有服务"

setup: ## 初始化项目环境
	@echo "$(CYAN)📁 初始化项目环境...$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		cp .env.example $(ENV_FILE); \
		echo "$(GREEN)✅ 已创建 .env 文件$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  .env 文件已存在$(NC)"; \
	fi
	@mkdir -p data/{postgres,redis,rabbitmq}
	@mkdir -p logs/{user-service,product-service,order-service,notification-service,nginx}
	@mkdir -p data/static data/product-images
	@echo "$(GREEN)✅ 目录结构创建完成$(NC)"
	@echo "$(CYAN)💡 请编辑 .env 文件配置必要的环境变量$(NC)"

build: setup ## 构建所有服务镜像
	@echo "$(CYAN)🔨 构建服务镜像...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) build --no-cache
	@echo "$(GREEN)✅ 镜像构建完成$(NC)"

up: setup ## 启动所有服务
	@echo "$(CYAN)🚀 启动所有服务...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✅ 服务启动完成$(NC)"
	@echo ""
	@echo "$(YELLOW)📋 访问地址:$(NC)"
	@echo "  🌐 应用入口: http://localhost"
	@echo "  👤 用户服务: http://localhost:5001"
	@echo "  📦 商品服务: http://localhost:5002"
	@echo "  📋 订单服务: http://localhost:5003"
	@echo "  📬 通知服务: http://localhost:5004"
	@echo "  🐰 RabbitMQ管理: http://localhost:15672"
	@echo ""
	@echo "$(CYAN)💡 运行 'make health' 检查服务状态$(NC)"

up-build: ## 构建并启动所有服务
	@echo "$(CYAN)🔨 构建并启动所有服务...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) up -d --build
	@echo "$(GREEN)✅ 服务启动完成$(NC)"

down: ## 停止所有服务
	@echo "$(CYAN)🛑 停止所有服务...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)✅ 服务已停止$(NC)"

down-clean: ## 停止服务并清理数据卷
	@echo "$(RED)🗑️  停止服务并清理数据卷...$(NC)"
	@echo "$(YELLOW)⚠️  警告：这将删除所有数据！$(NC)"
	@read -p "确认继续？[y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker-compose -f $(COMPOSE_FILE) down -v
	@docker system prune -f
	@echo "$(GREEN)✅ 清理完成$(NC)"

restart: ## 重启所有服务
	@echo "$(CYAN)🔄 重启所有服务...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) restart
	@echo "$(GREEN)✅ 服务重启完成$(NC)"

restart-service: ## 重启指定服务 (使用: make restart-service SERVICE=user-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make restart-service SERVICE=user-service$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)🔄 重启服务: $(SERVICE)$(NC)"
	@docker-compose -f $(COMPOSE_FILE) restart $(SERVICE)
	@echo "$(GREEN)✅ 服务 $(SERVICE) 重启完成$(NC)"

logs: ## 查看所有服务日志
	@echo "$(CYAN)📋 查看服务日志...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) logs -f

logs-service: ## 查看指定服务日志 (使用: make logs-service SERVICE=user-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make logs-service SERVICE=user-service$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)📋 查看 $(SERVICE) 服务日志...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) logs -f $(SERVICE)

status: ## 查看服务状态
	@echo "$(CYAN)📊 服务状态:$(NC)"
	@docker-compose -f $(COMPOSE_FILE) ps

health: ## 检查服务健康状态
	@echo "$(CYAN)🏥 检查服务健康状态...$(NC)"
	@echo ""
	@echo "$(YELLOW)📋 容器状态:$(NC)"
	@docker-compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "$(YELLOW)🔍 健康检查:$(NC)"
	@for service in user product order notification; do \
		echo -n "  $$service-service: "; \
		if curl -sf http://localhost/health/$$service > /dev/null 2>&1; then \
			echo "$(GREEN)✅ 健康$(NC)"; \
		else \
			echo "$(RED)❌ 异常$(NC)"; \
		fi; \
	done
	@echo ""
	@echo "$(YELLOW)📊 基础设施服务:$(NC)"
	@echo -n "  PostgreSQL: "
	@if docker-compose -f $(COMPOSE_FILE) exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then \
		echo "$(GREEN)✅ 健康$(NC)"; \
	else \
		echo "$(RED)❌ 异常$(NC)"; \
	fi
	@echo -n "  Redis: "
	@if docker-compose -f $(COMPOSE_FILE) exec -T redis redis-cli ping > /dev/null 2>&1; then \
		echo "$(GREEN)✅ 健康$(NC)"; \
	else \
		echo "$(RED)❌ 异常$(NC)"; \
	fi
	@echo -n "  RabbitMQ: "
	@if docker-compose -f $(COMPOSE_FILE) exec -T rabbitmq rabbitmq-diagnostics ping > /dev/null 2>&1; then \
		echo "$(GREEN)✅ 健康$(NC)"; \
	else \
		echo "$(RED)❌ 异常$(NC)"; \
	fi

test: ## 运行API测试
	@echo "$(CYAN)🧪 运行API测试...$(NC)"
	@echo "$(YELLOW)测试用户服务...$(NC)"
	@curl -sf http://localhost/health/user > /dev/null || (echo "$(RED)❌ 用户服务不可用$(NC)" && exit 1)
	@echo "$(GREEN)✅ 用户服务健康$(NC)"
	@echo "$(YELLOW)测试商品服务...$(NC)"
	@curl -sf http://localhost/health/product > /dev/null || (echo "$(RED)❌ 商品服务不可用$(NC)" && exit 1)
	@echo "$(GREEN)✅ 商品服务健康$(NC)"
	@echo "$(YELLOW)测试订单服务...$(NC)"
	@curl -sf http://localhost/health/order > /dev/null || (echo "$(RED)❌ 订单服务不可用$(NC)" && exit 1)
	@echo "$(GREEN)✅ 订单服务健康$(NC)"
	@echo "$(YELLOW)测试通知服务...$(NC)"
	@curl -sf http://localhost/health/notification > /dev/null || (echo "$(RED)❌ 通知服务不可用$(NC)" && exit 1)
	@echo "$(GREEN)✅ 通知服务健康$(NC)"
	@echo "$(GREEN)🎉 所有服务测试通过$(NC)"

stats: ## 查看服务统计信息
	@echo "$(CYAN)📊 服务统计信息:$(NC)"
	@echo ""
	@echo "$(YELLOW)👤 用户服务统计:$(NC)"
	@curl -s http://localhost/stats/user | python3 -m json.tool 2>/dev/null || echo "  服务不可用"
	@echo ""
	@echo "$(YELLOW)📦 商品服务统计:$(NC)"
	@curl -s http://localhost/stats/product | python3 -m json.tool 2>/dev/null || echo "  服务不可用"
	@echo ""
	@echo "$(YELLOW)📋 订单服务统计:$(NC)"
	@curl -s http://localhost/stats/order | python3 -m json.tool 2>/dev/null || echo "  服务不可用"
	@echo ""
	@echo "$(YELLOW)📬 通知服务统计:$(NC)"
	@curl -s http://localhost/stats/notification | python3 -m json.tool 2>/dev/null || echo "  服务不可用"

clean: ## 清理Docker资源
	@echo "$(CYAN)🧹 清理Docker资源...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) down
	@docker system prune -f
	@docker volume prune -f
	@echo "$(GREEN)✅ 清理完成$(NC)"

shell: ## 进入指定服务容器 (使用: make shell SERVICE=user-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ 请指定服务名称: make shell SERVICE=user-service$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)🐚 进入 $(SERVICE) 容器...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) exec $(SERVICE) /bin/bash

db-backup: ## 备份数据库
	@echo "$(CYAN)💾 备份数据库...$(NC)"
	@mkdir -p database/backups
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	docker-compose -f $(COMPOSE_FILE) exec -T postgres pg_dumpall -U postgres > database/backups/backup_$$timestamp.sql
	@echo "$(GREEN)✅ 数据库备份完成$(NC)"

db-restore: ## 恢复数据库 (使用: make db-restore BACKUP=backup_20240101_120000.sql)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)❌ 请指定备份文件: make db-restore BACKUP=backup_20240101_120000.sql$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "database/backups/$(BACKUP)" ]; then \
		echo "$(RED)❌ 备份文件不存在: database/backups/$(BACKUP)$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)⚠️  警告：这将覆盖现有数据库！$(NC)"
	@read -p "确认继续？[y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "$(CYAN)📥 恢复数据库...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) exec -T postgres psql -U postgres < database/backups/$(BACKUP)
	@echo "$(GREEN)✅ 数据库恢复完成$(NC)"

update: ## 拉取最新镜像并重启服务
	@echo "$(CYAN)🔄 更新服务...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) pull
	@docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✅ 服务更新完成$(NC)"

env: ## 显示环境变量
	@echo "$(CYAN)🔧 环境变量:$(NC)"
	@if [ -f $(ENV_FILE) ]; then \
		cat $(ENV_FILE) | grep -v '^#' | grep -v '^$$'; \
	else \
		echo "$(RED)❌ .env 文件不存在$(NC)"; \
	fi

version: ## 显示版本信息
	@echo "$(CYAN)📋 版本信息:$(NC)"
	@echo "  项目名称: $(PROJECT_NAME)"
	@echo "  版本: 1.0.0"
	@echo "  Docker Compose: $$(docker-compose --version)"
	@echo "  Docker: $$(docker --version)"

# 开发环境命令
dev-setup: ## 设置开发环境
	@echo "$(CYAN)🛠️  设置开发环境...$(NC)"
	@make setup
	@echo "FLASK_ENV=development" >> $(ENV_FILE)
	@echo "LOG_LEVEL=DEBUG" >> $(ENV_FILE)
	@echo "$(GREEN)✅ 开发环境设置完成$(NC)"

dev-up: ## 启动开发环境
	@echo "$(CYAN)🚀 启动开发环境...$(NC)"
	@FLASK_ENV=development docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✅ 开发环境启动完成$(NC)"