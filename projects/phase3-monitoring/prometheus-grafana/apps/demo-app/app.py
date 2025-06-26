#!/usr/bin/env python3
"""
演示应用 - 用于展示 Prometheus 监控功能
提供 HTTP API 和自定义指标
"""

import time
import random
import logging
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import threading

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 创建 Flask 应用
app = Flask(__name__)

# Prometheus 指标定义
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

ACTIVE_CONNECTIONS = Gauge(
    'active_connections',
    'Number of active connections'
)

BUSINESS_METRIC = Counter(
    'business_operations_total',
    'Total business operations',
    ['operation_type', 'status']
)

CPU_USAGE = Gauge(
    'app_cpu_usage_percent',
    'Application CPU usage percentage'
)

MEMORY_USAGE = Gauge(
    'app_memory_usage_bytes',
    'Application memory usage in bytes'
)

ERROR_RATE = Gauge(
    'app_error_rate',
    'Application error rate'
)

# 全局变量
active_connections = 0
error_count = 0
total_requests = 0

def update_system_metrics():
    """更新系统指标的后台任务"""
    while True:
        try:
            # 模拟 CPU 使用率
            cpu_percent = random.uniform(10, 90)
            CPU_USAGE.set(cpu_percent)
            
            # 模拟内存使用量
            memory_bytes = random.randint(100_000_000, 500_000_000)  # 100MB - 500MB
            MEMORY_USAGE.set(memory_bytes)
            
            # 计算错误率
            if total_requests > 0:
                error_rate = (error_count / total_requests) * 100
                ERROR_RATE.set(error_rate)
            
            time.sleep(10)  # 每10秒更新一次
        except Exception as e:
            logger.error(f"Error updating system metrics: {e}")

# 启动后台指标更新线程
metrics_thread = threading.Thread(target=update_system_metrics, daemon=True)
metrics_thread.start()

@app.before_request
def before_request():
    """请求前处理"""
    global active_connections
    active_connections += 1
    ACTIVE_CONNECTIONS.set(active_connections)
    request.start_time = time.time()

@app.after_request
def after_request(response):
    """请求后处理"""
    global active_connections, total_requests
    
    # 更新连接数
    active_connections -= 1
    ACTIVE_CONNECTIONS.set(active_connections)
    
    # 记录请求指标
    duration = time.time() - request.start_time
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown'
    ).observe(duration)
    
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status_code=response.status_code
    ).inc()
    
    total_requests += 1
    
    return response

@app.route('/')
def home():
    """首页"""
    return jsonify({
        'message': 'Demo Application for Prometheus Monitoring',
        'version': '1.0.0',
        'endpoints': [
            '/health',
            '/metrics',
            '/api/users',
            '/api/orders',
            '/simulate/load',
            '/simulate/error'
        ]
    })

@app.route('/health')
def health():
    """健康检查端点"""
    return jsonify({
        'status': 'healthy',
        'timestamp': time.time(),
        'uptime': time.time() - app.start_time
    })

@app.route('/metrics')
def metrics():
    """Prometheus 指标端点"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/api/users')
def get_users():
    """获取用户列表 API"""
    # 模拟业务操作
    BUSINESS_METRIC.labels(operation_type='get_users', status='success').inc()
    
    # 模拟处理时间
    time.sleep(random.uniform(0.1, 0.5))
    
    users = [
        {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'},
        {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'},
        {'id': 3, 'name': 'Charlie', 'email': 'charlie@example.com'}
    ]
    
    return jsonify({'users': users, 'count': len(users)})

@app.route('/api/orders')
def get_orders():
    """获取订单列表 API"""
    # 模拟业务操作
    BUSINESS_METRIC.labels(operation_type='get_orders', status='success').inc()
    
    # 模拟处理时间
    time.sleep(random.uniform(0.2, 0.8))
    
    orders = [
        {'id': 1, 'user_id': 1, 'amount': 99.99, 'status': 'completed'},
        {'id': 2, 'user_id': 2, 'amount': 149.99, 'status': 'pending'},
        {'id': 3, 'user_id': 1, 'amount': 79.99, 'status': 'completed'}
    ]
    
    return jsonify({'orders': orders, 'count': len(orders)})

@app.route('/simulate/load')
def simulate_load():
    """模拟高负载"""
    # 模拟 CPU 密集型操作
    start_time = time.time()
    while time.time() - start_time < random.uniform(1, 3):
        _ = sum(i * i for i in range(1000))
    
    BUSINESS_METRIC.labels(operation_type='simulate_load', status='success').inc()
    
    return jsonify({
        'message': 'Load simulation completed',
        'duration': time.time() - start_time
    })

@app.route('/simulate/error')
def simulate_error():
    """模拟错误"""
    global error_count
    error_count += 1
    
    BUSINESS_METRIC.labels(operation_type='simulate_error', status='error').inc()
    
    # 随机返回不同类型的错误
    error_types = [400, 500, 503]
    status_code = random.choice(error_types)
    
    error_messages = {
        400: 'Bad Request - Invalid parameters',
        500: 'Internal Server Error - Something went wrong',
        503: 'Service Unavailable - System overloaded'
    }
    
    return jsonify({
        'error': error_messages[status_code],
        'timestamp': time.time()
    }), status_code

@app.route('/api/stats')
def get_stats():
    """获取应用统计信息"""
    return jsonify({
        'total_requests': total_requests,
        'error_count': error_count,
        'active_connections': active_connections,
        'uptime': time.time() - app.start_time,
        'error_rate': (error_count / total_requests * 100) if total_requests > 0 else 0
    })

if __name__ == '__main__':
    # 记录应用启动时间
    app.start_time = time.time()
    
    logger.info("Starting Demo Application...")
    logger.info("Metrics available at: http://localhost:5000/metrics")
    logger.info("Health check at: http://localhost:5000/health")
    
    # 启动应用
    app.run(host='0.0.0.0', port=5000, debug=False)
