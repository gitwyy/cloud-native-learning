# 🧪 Todo List Plus API 测试指南

## 📋 测试准备

### 环境要求
- Python 3.11+
- PostgreSQL 15+
- Redis 7+
- 或者使用 Docker Compose

### 启动服务
```bash
# 使用 Docker Compose 启动所有服务
docker-compose up -d

# 或者手动启动后端服务
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### API 基础信息
- **Base URL**: `http://localhost:8000`
- **API Documentation**: `http://localhost:8000/docs`
- **Health Check**: `http://localhost:8000/health`

## 🔐 认证API测试

### 1. 用户注册
```bash
curl -X POST "http://localhost:8000/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "TestPass123",
    "full_name": "Test User",
    "bio": "I am a test user"
  }'
```

**预期响应**:
```json
{
  "id": 1,
  "username": "testuser",
  "email": "test@example.com",
  "full_name": "Test User",
  "bio": "I am a test user",
  "is_active": true,
  "is_verified": false,
  "timezone": "Asia/Shanghai",
  "language": "zh-CN",
  "theme": "light",
  "created_at": "2025-06-05T03:17:31.123456"
}
```

### 2. 用户登录
```bash
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "TestPass123",
    "remember_me": true
  }'
```

**预期响应**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800,
  "user": {
    "id": 1,
    "username": "testuser",
    "email": "test@example.com",
    "full_name": "Test User"
  }
}
```

### 3. 获取当前用户信息
```bash
# 保存登录返回的 access_token
TOKEN="your_access_token_here"

curl -X GET "http://localhost:8000/api/v1/auth/me" \
  -H "Authorization: Bearer $TOKEN"
```

## 📝 任务管理API测试

### 1. 创建任务
```bash
curl -X POST "http://localhost:8000/api/v1/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "完成API文档",
    "description": "编写Todo List Plus的API测试文档",
    "priority": "high",
    "category": "开发",
    "due_date": "2025-06-10T18:00:00",
    "estimated_hours": 4,
    "tags": ["文档", "API", "测试"]
  }'
```

**预期响应**:
```json
{
  "id": 1,
  "title": "完成API文档",
  "description": "编写Todo List Plus的API测试文档",
  "status": "pending",
  "priority": "high",
  "category": "开发",
  "due_date": "2025-06-10T18:00:00",
  "progress": 0,
  "estimated_hours": 4,
  "tags": ["文档", "API", "测试"],
  "owner_id": 1,
  "created_at": "2025-06-05T03:17:31.123456"
}
```

### 2. 获取任务列表
```bash
# 获取所有任务
curl -X GET "http://localhost:8000/api/v1/tasks" \
  -H "Authorization: Bearer $TOKEN"

# 带筛选条件的查询
curl -X GET "http://localhost:8000/api/v1/tasks?status=pending&priority=high&page=1&page_size=10" \
  -H "Authorization: Bearer $TOKEN"

# 搜索任务
curl -X GET "http://localhost:8000/api/v1/tasks?search=API&sort_by=created_at&sort_order=desc" \
  -H "Authorization: Bearer $TOKEN"
```

### 3. 更新任务
```bash
curl -X PUT "http://localhost:8000/api/v1/tasks/1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress",
    "progress": 25,
    "notes": "已开始编写文档大纲"
  }'
```

### 4. 批量更新任务
```bash
curl -X POST "http://localhost:8000/api/v1/tasks/batch/update" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task_ids": [1, 2, 3],
    "status": "in_progress",
    "priority": "medium"
  }'
```

### 5. 获取任务统计
```bash
curl -X GET "http://localhost:8000/api/v1/tasks/stats/summary" \
  -H "Authorization: Bearer $TOKEN"
```

**预期响应**:
```json
{
  "total_tasks": 5,
  "pending_tasks": 2,
  "in_progress_tasks": 2,
  "completed_tasks": 1,
  "cancelled_tasks": 0,
  "archived_tasks": 0,
  "overdue_tasks": 1,
  "due_soon_tasks": 2,
  "starred_tasks": 1,
  "low_priority_tasks": 1,
  "medium_priority_tasks": 2,
  "high_priority_tasks": 2,
  "urgent_priority_tasks": 0
}
```

## 🔔 通知系统API测试

### 1. 创建通知
```bash
curl -X POST "http://localhost:8000/api/v1/notifications" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "任务即将到期",
    "message": "您的任务「完成API文档」将在2小时后到期，请及时处理。",
    "notification_type": "task_due_soon",
    "priority": "high",
    "resource_type": "task",
    "resource_id": 1,
    "action_url": "/tasks/1",
    "action_text": "查看任务"
  }'
```

### 2. 获取通知列表
```bash
# 获取所有通知
curl -X GET "http://localhost:8000/api/v1/notifications" \
  -H "Authorization: Bearer $TOKEN"

# 筛选未读通知
curl -X GET "http://localhost:8000/api/v1/notifications?is_read=false&page=1&page_size=10" \
  -H "Authorization: Bearer $TOKEN"

# 按类型筛选
curl -X GET "http://localhost:8000/api/v1/notifications?notification_type=task_due_soon&priority=high" \
  -H "Authorization: Bearer $TOKEN"
```

### 3. 标记通知为已读
```bash
# 标记单个通知已读
curl -X PUT "http://localhost:8000/api/v1/notifications/1/read" \
  -H "Authorization: Bearer $TOKEN"

# 标记所有通知已读
curl -X PUT "http://localhost:8000/api/v1/notifications/read-all" \
  -H "Authorization: Bearer $TOKEN"
```

### 4. 发送通知
```bash
curl -X POST "http://localhost:8000/api/v1/notifications/send" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "系统维护通知",
    "message": "系统将在今晚22:00进行维护，预计耗时30分钟。",
    "priority": "medium",
    "channels": ["email", "push"]
  }'
```

### 5. 获取通知统计
```bash
curl -X GET "http://localhost:8000/api/v1/notifications/stats/summary" \
  -H "Authorization: Bearer $TOKEN"
```

## 🧪 完整测试流程脚本

### bash测试脚本
```bash
#!/bin/bash

# Todo List Plus API 完整测试脚本
BASE_URL="http://localhost:8000"
CONTENT_TYPE="Content-Type: application/json"

echo "🚀 开始 Todo List Plus API 测试"

# 1. 健康检查
echo "📊 检查服务健康状态..."
curl -s "$BASE_URL/health" | jq '.'

# 2. 用户注册
echo "👤 注册新用户..."
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "$CONTENT_TYPE" \
  -d '{
    "username": "apitest",
    "email": "apitest@example.com",
    "password": "TestPass123",
    "full_name": "API Test User"
  }')

echo $REGISTER_RESPONSE | jq '.'

# 3. 用户登录
echo "🔐 用户登录..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "$CONTENT_TYPE" \
  -d '{
    "username": "apitest",
    "password": "TestPass123"
  }')

# 提取访问令牌
TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.access_token')
echo "🎫 获得访问令牌: ${TOKEN:0:20}..."

# 4. 创建任务
echo "📝 创建测试任务..."
TASK_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "$CONTENT_TYPE" \
  -d '{
    "title": "API测试任务",
    "description": "这是一个通过API创建的测试任务",
    "priority": "high",
    "category": "测试"
  }')

TASK_ID=$(echo $TASK_RESPONSE | jq -r '.id')
echo "✅ 创建任务成功，ID: $TASK_ID"

# 5. 更新任务状态
echo "🔄 更新任务状态..."
curl -s -X PUT "$BASE_URL/api/v1/tasks/$TASK_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "$CONTENT_TYPE" \
  -d '{
    "status": "in_progress",
    "progress": 50
  }' | jq '.'

# 6. 创建通知
echo "🔔 创建测试通知..."
curl -s -X POST "$BASE_URL/api/v1/notifications" \
  -H "Authorization: Bearer $TOKEN" \
  -H "$CONTENT_TYPE" \
  -d '{
    "title": "API测试通知",
    "message": "这是一个通过API创建的测试通知",
    "notification_type": "reminder",
    "priority": "medium"
  }' | jq '.'

# 7. 获取统计信息
echo "📊 获取任务统计..."
curl -s -X GET "$BASE_URL/api/v1/tasks/stats/summary" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo "📊 获取通知统计..."
curl -s -X GET "$BASE_URL/api/v1/notifications/stats/summary" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo "🎉 API测试完成！"
```

### Python测试脚本
```python
#!/usr/bin/env python3
"""
Todo List Plus API 测试脚本
使用 requests 库进行 API 测试
"""

import requests
import json
from datetime import datetime, timedelta

BASE_URL = "http://localhost:8000"

class TodoListPlusAPITest:
    def __init__(self):
        self.base_url = BASE_URL
        self.token = None
        self.user_id = None
        
    def register_user(self):
        """注册用户"""
        url = f"{self.base_url}/api/v1/auth/register"
        data = {
            "username": "pytest_user",
            "email": "pytest@example.com",
            "password": "TestPass123",
            "full_name": "PyTest User"
        }
        
        response = requests.post(url, json=data)
        if response.status_code == 200:
            self.user_id = response.json()["id"]
            print(f"✅ 用户注册成功，ID: {self.user_id}")
        else:
            print(f"❌ 用户注册失败: {response.text}")
        return response
    
    def login_user(self):
        """用户登录"""
        url = f"{self.base_url}/api/v1/auth/login"
        data = {
            "username": "pytest_user",
            "password": "TestPass123"
        }
        
        response = requests.post(url, json=data)
        if response.status_code == 200:
            self.token = response.json()["access_token"]
            print(f"✅ 登录成功，获得令牌")
        else:
            print(f"❌ 登录失败: {response.text}")
        return response
    
    def get_headers(self):
        """获取认证头"""
        return {"Authorization": f"Bearer {self.token}"}
    
    def create_task(self):
        """创建任务"""
        url = f"{self.base_url}/api/v1/tasks"
        data = {
            "title": "Python API测试任务",
            "description": "使用Python requests库创建的测试任务",
            "priority": "high",
            "category": "自动化测试",
            "due_date": (datetime.now() + timedelta(days=7)).isoformat(),
            "tags": ["测试", "自动化", "Python"]
        }
        
        response = requests.post(url, json=data, headers=self.get_headers())
        if response.status_code == 200:
            task_id = response.json()["id"]
            print(f"✅ 任务创建成功，ID: {task_id}")
            return task_id
        else:
            print(f"❌ 任务创建失败: {response.text}")
        return None
    
    def get_task_stats(self):
        """获取任务统计"""
        url = f"{self.base_url}/api/v1/tasks/stats/summary"
        response = requests.get(url, headers=self.get_headers())
        
        if response.status_code == 200:
            stats = response.json()
            print(f"📊 任务统计: 总计 {stats['total_tasks']} 个任务")
            return stats
        else:
            print(f"❌ 获取统计失败: {response.text}")
        return None
    
    def run_full_test(self):
        """运行完整测试"""
        print("🚀 开始 Python API 测试")
        
        # 1. 检查健康状态
        health_response = requests.get(f"{self.base_url}/health")
        if health_response.status_code == 200:
            print("✅ 服务健康检查通过")
        
        # 2. 注册用户
        self.register_user()
        
        # 3. 用户登录
        self.login_user()
        
        # 4. 创建任务
        task_id = self.create_task()
        
        # 5. 获取统计
        self.get_task_stats()
        
        print("🎉 Python API 测试完成！")

if __name__ == "__main__":
    test = TodoListPlusAPITest()
    test.run_full_test()
```

## 📊 性能测试

### 使用 Apache Bench (ab) 进行压力测试
```bash
# 安装 ab
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpd                   # macOS

# 健康检查接口压力测试
ab -n 1000 -c 10 http://localhost:8000/health

# 认证接口压力测试
ab -n 100 -c 5 -p register.json -T application/json http://localhost:8000/api/v1/auth/register
```

### 使用 wrk 进行负载测试
```bash
# 安装 wrk
git clone https://github.com/wg/wrk.git
cd wrk && make

# 基础负载测试
wrk -t4 -c100 -d30s http://localhost:8000/health

# 带认证的接口测试
wrk -t4 -c50 -d30s -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8000/api/v1/tasks
```

## 🔍 故障排查

### 常见问题

1. **连接拒绝 (Connection refused)**
   ```bash
   # 检查服务是否启动
   docker-compose ps
   curl http://localhost:8000/health
   ```

2. **认证失败 (401 Unauthorized)**
   ```bash
   # 检查令牌是否有效
   echo $TOKEN | cut -d'.' -f2 | base64 -d | jq '.'
   ```

3. **数据库连接失败**
   ```bash
   # 检查数据库状态
   docker-compose logs postgres
   ```

4. **Redis连接失败**
   ```bash
   # 检查Redis状态
   docker-compose logs redis
   ```

### 调试技巧

1. **查看详细日志**
   ```bash
   docker-compose logs -f backend
   ```

2. **进入容器调试**
   ```bash
   docker-compose exec backend bash
   docker-compose exec postgres psql -U postgres
   ```

3. **检查API文档**
   - 访问 `http://localhost:8000/docs`
   - 查看交互式API文档

---

## 📝 测试总结

通过以上测试，您可以验证 Todo List Plus API 的以下功能：

✅ **用户认证系统** - 注册、登录、令牌管理  
✅ **任务管理功能** - CRUD操作、搜索筛选、批量操作  
✅ **通知系统** - 通知创建、管理、统计  
✅ **安全防护** - 认证授权、速率限制  
✅ **性能表现** - 响应时间、并发处理  

这套完整的API为前端开发和移动端应用提供了强大的后端支持！