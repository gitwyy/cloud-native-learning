#!/usr/bin/env python3
"""
用户服务 - 微服务示例应用
包含日志记录和分布式链路追踪功能
"""

import os
import json
import time
import random
import logging
import requests
from datetime import datetime
from flask import Flask, request, jsonify
from jaeger_client import Config
from opentracing.ext import tags
from opentracing.propagation import Format
import opentracing

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s - trace_id=%(trace_id)s - span_id=%(span_id)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/var/log/user-service.log')
    ]
)

class TraceContextFilter(logging.Filter):
    """添加追踪上下文到日志记录"""
    def filter(self, record):
        span = opentracing.tracer.active_span
        if span:
            record.trace_id = format(span.context.trace_id, 'x')
            record.span_id = format(span.context.span_id, 'x')
        else:
            record.trace_id = 'none'
            record.span_id = 'none'
        return True

# 添加追踪上下文过滤器
logger = logging.getLogger(__name__)
logger.addFilter(TraceContextFilter())

app = Flask(__name__)

# 初始化 Jaeger 追踪器
def init_tracer(service_name='user-service'):
    """初始化 Jaeger 追踪器"""
    config = Config(
        config={
            'sampler': {
                'type': 'const',
                'param': 1,  # 100% 采样用于演示
            },
            'logging': True,
            'reporter_batch_size': 1,
        },
        service_name=service_name,
        validate=True,
    )
    return config.initialize_tracer()

# 初始化追踪器
tracer = init_tracer()
opentracing.tracer = tracer

# 模拟用户数据
USERS = [
    {"id": 1, "name": "Alice", "email": "alice@example.com", "status": "active"},
    {"id": 2, "name": "Bob", "email": "bob@example.com", "status": "active"},
    {"id": 3, "name": "Charlie", "email": "charlie@example.com", "status": "inactive"},
    {"id": 4, "name": "Diana", "email": "diana@example.com", "status": "active"},
    {"id": 5, "name": "Eve", "email": "eve@example.com", "status": "pending"},
]

def get_trace_headers():
    """获取当前追踪上下文的 HTTP 头"""
    span = opentracing.tracer.active_span
    if span:
        headers = {}
        opentracing.tracer.inject(
            span.context,
            Format.HTTP_HEADERS,
            headers
        )
        return headers
    return {}

@app.before_request
def before_request():
    """请求前处理 - 提取追踪上下文"""
    span_ctx = opentracing.tracer.extract(
        Format.HTTP_HEADERS,
        request.headers
    )
    span_tags = {
        tags.HTTP_METHOD: request.method,
        tags.HTTP_URL: request.url,
        tags.COMPONENT: 'user-service',
        'service.name': 'user-service',
        'service.version': '1.0.0'
    }
    
    span = opentracing.tracer.start_span(
        operation_name=f"{request.method} {request.path}",
        child_of=span_ctx,
        tags=span_tags
    )
    
    # 将 span 存储在请求上下文中
    request.span = span
    
    # 记录请求日志
    logger.info(f"Incoming request: {request.method} {request.path}")

@app.after_request
def after_request(response):
    """请求后处理 - 完成追踪 span"""
    if hasattr(request, 'span'):
        request.span.set_tag(tags.HTTP_STATUS_CODE, response.status_code)
        if response.status_code >= 400:
            request.span.set_tag(tags.ERROR, True)
            request.span.log_kv({'error.message': f'HTTP {response.status_code}'})
        
        # 记录响应日志
        logger.info(f"Response: {response.status_code} for {request.method} {request.path}")
        
        request.span.finish()
    
    return response

@app.route('/health')
def health():
    """健康检查端点"""
    return jsonify({"status": "healthy", "service": "user-service", "timestamp": datetime.now().isoformat()})

@app.route('/api/users')
def get_users():
    """获取用户列表"""
    with opentracing.tracer.start_span('get_users', child_of=request.span) as span:
        span.set_tag('operation', 'get_users')
        span.set_tag('user.count', len(USERS))
        
        # 模拟数据库查询延迟
        query_delay = random.uniform(0.01, 0.1)
        time.sleep(query_delay)
        span.set_tag('db.query_time', query_delay)
        
        logger.info(f"Retrieved {len(USERS)} users")
        
        # 随机模拟错误
        if random.random() < 0.05:  # 5% 错误率
            logger.error("Database connection error")
            span.set_tag(tags.ERROR, True)
            span.log_kv({'error.message': 'Database connection timeout'})
            return jsonify({"error": "Internal server error"}), 500
        
        return jsonify({
            "users": USERS,
            "total": len(USERS),
            "timestamp": datetime.now().isoformat()
        })

@app.route('/api/users/<int:user_id>')
def get_user(user_id):
    """获取特定用户信息"""
    with opentracing.tracer.start_span('get_user_by_id', child_of=request.span) as span:
        span.set_tag('operation', 'get_user_by_id')
        span.set_tag('user.id', user_id)
        
        logger.info(f"Looking up user with ID: {user_id}")
        
        # 查找用户
        user = next((u for u in USERS if u['id'] == user_id), None)
        
        if user:
            span.set_tag('user.found', True)
            span.set_tag('user.name', user['name'])
            span.set_tag('user.status', user['status'])
            
            logger.info(f"Found user: {user['name']}")
            return jsonify(user)
        else:
            span.set_tag('user.found', False)
            span.set_tag(tags.ERROR, True)
            span.log_kv({'error.message': f'User {user_id} not found'})
            
            logger.warning(f"User not found: {user_id}")
            return jsonify({"error": "User not found"}), 404

@app.route('/api/users/<int:user_id>/orders')
def get_user_orders(user_id):
    """获取用户订单 - 调用订单服务"""
    with opentracing.tracer.start_span('get_user_orders', child_of=request.span) as span:
        span.set_tag('operation', 'get_user_orders')
        span.set_tag('user.id', user_id)
        
        # 首先验证用户是否存在
        user = next((u for u in USERS if u['id'] == user_id), None)
        if not user:
            span.set_tag(tags.ERROR, True)
            span.log_kv({'error.message': f'User {user_id} not found'})
            logger.warning(f"User not found: {user_id}")
            return jsonify({"error": "User not found"}), 404
        
        # 调用订单服务
        try:
            order_service_url = os.getenv('ORDER_SERVICE_URL', 'http://order-service:8080')
            headers = get_trace_headers()
            
            with opentracing.tracer.start_span('call_order_service', child_of=span) as call_span:
                call_span.set_tag('http.url', f"{order_service_url}/api/orders/user/{user_id}")
                call_span.set_tag('component', 'http-client')
                
                logger.info(f"Calling order service for user {user_id}")
                
                response = requests.get(
                    f"{order_service_url}/api/orders/user/{user_id}",
                    headers=headers,
                    timeout=5
                )
                
                call_span.set_tag('http.status_code', response.status_code)
                
                if response.status_code == 200:
                    orders = response.json()
                    span.set_tag('orders.count', len(orders.get('orders', [])))
                    logger.info(f"Retrieved {len(orders.get('orders', []))} orders for user {user_id}")
                    return jsonify(orders)
                else:
                    call_span.set_tag(tags.ERROR, True)
                    call_span.log_kv({'error.message': f'Order service returned {response.status_code}'})
                    logger.error(f"Order service error: {response.status_code}")
                    return jsonify({"error": "Failed to retrieve orders"}), 502
                    
        except requests.exceptions.RequestException as e:
            span.set_tag(tags.ERROR, True)
            span.log_kv({'error.message': str(e)})
            logger.error(f"Failed to call order service: {str(e)}")
            return jsonify({"error": "Order service unavailable"}), 503

@app.route('/api/users', methods=['POST'])
def create_user():
    """创建新用户"""
    with opentracing.tracer.start_span('create_user', child_of=request.span) as span:
        span.set_tag('operation', 'create_user')
        
        data = request.get_json()
        if not data or 'name' not in data or 'email' not in data:
            span.set_tag(tags.ERROR, True)
            span.log_kv({'error.message': 'Invalid request data'})
            logger.warning("Invalid user creation request")
            return jsonify({"error": "Name and email are required"}), 400
        
        # 创建新用户
        new_user = {
            "id": max(u['id'] for u in USERS) + 1,
            "name": data['name'],
            "email": data['email'],
            "status": "active"
        }
        
        USERS.append(new_user)
        
        span.set_tag('user.id', new_user['id'])
        span.set_tag('user.name', new_user['name'])
        
        logger.info(f"Created new user: {new_user['name']} (ID: {new_user['id']})")
        
        return jsonify(new_user), 201

@app.route('/metrics')
def metrics():
    """Prometheus 指标端点"""
    # 简单的指标示例
    metrics_data = f"""# HELP user_service_requests_total Total number of requests
# TYPE user_service_requests_total counter
user_service_requests_total{{method="GET",endpoint="/api/users"}} {random.randint(100, 1000)}
user_service_requests_total{{method="GET",endpoint="/api/users/id"}} {random.randint(50, 500)}
user_service_requests_total{{method="POST",endpoint="/api/users"}} {random.randint(10, 100)}

# HELP user_service_response_time_seconds Response time in seconds
# TYPE user_service_response_time_seconds histogram
user_service_response_time_seconds_bucket{{le="0.1"}} {random.randint(80, 120)}
user_service_response_time_seconds_bucket{{le="0.5"}} {random.randint(150, 200)}
user_service_response_time_seconds_bucket{{le="1.0"}} {random.randint(180, 220)}
user_service_response_time_seconds_bucket{{le="+Inf"}} {random.randint(200, 250)}

# HELP user_service_users_total Total number of users
# TYPE user_service_users_total gauge
user_service_users_total {len(USERS)}
"""
    return metrics_data, 200, {'Content-Type': 'text/plain'}

if __name__ == '__main__':
    logger.info("Starting User Service...")
    app.run(host='0.0.0.0', port=8080, debug=False)
