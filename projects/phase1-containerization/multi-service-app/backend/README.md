# Todo List Plus 后端服务

## 项目概述
提供任务管理、用户认证和通知功能的RESTful API服务，使用FastAPI框架构建。

## 技术栈
- Python 3.10
- FastAPI
- SQLAlchemy (异步)
- PostgreSQL
- Redis
- Alembic (数据库迁移)

## 项目结构
```
backend/
├── app/                  # 应用核心代码
│   ├── api/              # API路由
│   ├── core/             # 配置和工具类
│   ├── models/           # 数据库模型
│   ├── schemas/          # Pydantic模型
│   ├── services/         # 业务逻辑
│   └── main.py           # 应用入口
├── tests/                # 单元测试
├── alembic/              # 数据库迁移脚本
├── Dockerfile            # 容器化配置
└── requirements.txt      # 依赖列表
```

## 运行指南

### 本地开发
```bash
# 安装依赖
pip install -r requirements.txt

# 设置环境变量
export DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/todo_db
export REDIS_URL=redis://localhost:6379

# 启动服务
uvicorn app.main:app --reload --port 8000
```

### Docker容器运行
```bash
# 构建镜像
docker build -t todo-backend .

# 运行容器
docker run -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://user:password@db:5432/todo_db \
  -e REDIS_URL=redis://redis:6379 \
  todo-backend
```

## API文档
启动服务后访问：http://localhost:8000/docs

### 认证方式
使用Bearer Token认证：
1. 通过`/api/v1/auth/login`获取访问令牌
2. 在请求头中添加：`Authorization: Bearer <token>`

## 开发指南

### 数据库迁移
```bash
# 创建新迁移
alembic revision -m "migration_description"

# 执行迁移
alembic upgrade head
```

### 运行测试
```bash
pytest tests/
```

## 贡献
欢迎提交Pull Request，请确保：
1. 添加相应的单元测试
2. 更新相关文档
3. 通过代码格式化检查