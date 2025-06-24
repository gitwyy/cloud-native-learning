.PHONY: help dev-up prod-up down status logs clean build test migrate seed backup restore

# 默认目标
help:
	@echo "Todo List Plus - Docker管理命令"
	@echo ""
	@echo "开发命令:"
	@echo "  dev-up      启动开发环境"
	@echo "  down        停止所有服务"
	@echo "  restart     重启所有服务"
	@echo "  build       重新构建所有镜像"
	@echo ""
	@echo "监控命令:"
	@echo "  status      查看服务状态"
	@echo "  logs        查看服务日志"
	@echo "  logs-f      实时查看服务日志"
	@echo ""
	@echo "数据库命令:"
	@echo "  migrate     运行数据库迁移"
	@echo "  seed        载入种子数据"
	@echo "  backup      备份数据库"
	@echo "  restore     恢复数据库"
	@echo ""
	@echo "维护命令:"
	@echo "  clean       清理容器和镜像"
	@echo "  test        运行测试"


# Project setup and initialization
setup: db-init
	@echo "🔧 初始化项目..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ 请先安装Docker"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "❌ 请启动Docker服务"; exit 1; }
	@echo "项目初始化完成"

# 开发环境管理
dev-up:
	@echo "🚀 启动开发环境..."
	@cp -n .env.example .env 2>/dev/null || true
	@mkdir -p logs/{nginx,backend,database} data/{postgres,redis,uploads} backups
	@docker-compose up -d
	@echo "✅ 开发环境已启动"
	@echo "🌐 前端: http://localhost:3000"
	@echo "🔧 后端API: http://localhost:8000"
	@echo "📖 API文档: http://localhost:8000/docs"

prod-up:
	@echo "🚀 启动生产环境..."
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
	@echo "✅ 生产环境已启动"

down:
	@echo "🛑 停止所有服务..."
	@docker-compose down
	@echo "✅ 所有服务已停止"

restart:
	@echo "🔄 重启所有服务..."
	@docker-compose restart
	@echo "✅ 所有服务已重启"

# 构建和更新
build:
	@echo "🔨 重新构建所有镜像..."
	@docker-compose build --no-cache
	@echo "✅ 镜像构建完成"

build-frontend:
	@echo "🔨 重新构建前端镜像..."
	@docker-compose build --no-cache frontend
	@echo "✅ 前端镜像构建完成"

build-backend:
	@echo "🔨 重新构建后端镜像..."
	@docker-compose build --no-cache backend
	@echo "✅ 后端镜像构建完成"

# 监控和调试
status:
	@echo "📊 服务状态:"
	@docker-compose ps

logs:
	@docker-compose logs

logs-f:
	@docker-compose logs -f

logs-frontend:
	@docker-compose logs -f frontend

logs-backend:
	@docker-compose logs -f backend

logs-database:
	@docker-compose logs -f database

logs-redis:
	@docker-compose logs -f redis

logs-nginx:
	@docker-compose logs -f nginx

# 数据库操作
migrate:
	@echo "🗃️ 运行数据库迁移..."
	@docker-compose exec backend alembic upgrade head
	@echo "✅ 数据库迁移完成"

migrate-create:
	@echo "🗃️ 创建新的迁移文件..."
	@read -p "迁移名称: " name; \
	docker-compose exec backend alembic revision --autogenerate -m "$$name"

seed:
	@echo "🌱 载入种子数据..."
	@docker-compose exec backend python -c "from app.db.init_db import init_db; init_db()"
	@echo "✅ 种子数据载入完成"

# 备份和恢复
backup:
	@echo "💾 备份数据库..."
	@mkdir -p backups
	@docker-compose exec database pg_dump -U postgres todo_db > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "✅ 数据库备份完成"

restore:
	@echo "🔄 恢复数据库..."
	@read -p "备份文件路径: " backup_file; \
	docker-compose exec -T database psql -U postgres todo_db < "$$backup_file"
	@echo "✅ 数据库恢复完成"

# 测试
test:
	@echo "🧪 运行测试..."
	@docker-compose exec backend python -m pytest tests/ -v
	@echo "✅ 测试完成"

test-frontend:
	@echo "🧪 运行前端测试..."
	@docker-compose exec frontend npm test
	@echo "✅ 前端测试完成"

test-backend:
	@echo "🧪 运行后端测试..."
	@docker-compose exec backend python -m pytest tests/ -v --cov=app
	@echo "✅ 后端测试完成"

# 维护和清理
clean:
	@echo "🧹 清理资源..."
	@docker-compose down -v
	@docker system prune -f
	@docker volume prune -f
	@echo "✅ 清理完成"

clean-all:
	@echo "🧹 完全清理..."
	@docker-compose down -v --rmi all
	@docker system prune -af
	@docker volume prune -f
	@echo "✅ 完全清理完成"



# 开发工具
shell-backend:
	@docker-compose exec backend /bin/bash

shell-frontend:
	@docker-compose exec frontend /bin/sh

shell-database:
	@docker-compose exec database psql -U postgres todo_db

shell-redis:
	@docker-compose exec redis redis-cli -a redis123

# 健康检查
health:
	@echo "🏥 检查服务健康状态..."
	@echo "Frontend: $$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo "❌ 无法连接")"
	@echo "Backend: $$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health || echo "❌ 无法连接")"
	@echo "Database: $$(docker-compose exec -T database pg_isready -U postgres -d todo_db && echo "✅ 健康" || echo "❌ 异常")"
	@echo "Redis: $$(docker-compose exec -T redis redis-cli -a redis123 ping && echo "✅ 健康" || echo "❌ 异常")"