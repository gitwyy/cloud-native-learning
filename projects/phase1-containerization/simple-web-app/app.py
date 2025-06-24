#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
简单的Flask Web应用
用于演示Docker容器化的基本概念

作者: 云原生学习者
"""

from flask import Flask, render_template, jsonify
import os
import socket
import datetime
import json

# 创建Flask应用实例
app = Flask(__name__)

# 配置应用
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
app.config['DEBUG'] = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

@app.route('/')
def index():
    """
    主页路由
    返回应用的主页面
    """
    return render_template('index.html')

@app.route('/api/info')
def api_info():
    """
    API信息接口
    返回容器和应用的详细信息
    """
    try:
        hostname = socket.gethostname()
        current_time = datetime.datetime.now().isoformat()
        
        info = {
            'message': '这是来自Flask容器内的API响应',
            'timestamp': current_time,
            'hostname': hostname,
            'python_version': os.sys.version.split()[0],
            'flask_version': '2.3.3',
            'environment': os.environ.get('FLASK_ENV', 'production'),
            'container_info': {
                'image': os.environ.get('DOCKER_IMAGE', 'unknown'),
                'build_date': os.environ.get('BUILD_DATE', 'unknown')
            },
            'system_info': {
                'platform': os.name,
                'cpu_count': os.cpu_count() if hasattr(os, 'cpu_count') else 'unknown'
            }
        }
        
        return jsonify(info)
    except Exception as e:
        return jsonify({
            'error': '获取系统信息时发生错误',
            'details': str(e)
        }), 500

@app.route('/health')
def health_check():
    """
    健康检查接口
    用于Docker容器健康状态监控
    """
    try:
        # 简单的健康检查逻辑
        health_status = {
            'status': 'healthy',
            'timestamp': datetime.datetime.now().isoformat(),
            'checks': {
                'database': 'not_applicable',  # 这个示例应用不使用数据库
                'disk_space': 'ok',
                'memory': 'ok'
            }
        }
        
        return jsonify(health_status), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'timestamp': datetime.datetime.now().isoformat(),
            'error': str(e)
        }), 503

@app.route('/api/stats')
def get_stats():
    """
    获取应用统计信息
    """
    try:
        # 模拟一些统计数据
        stats = {
            'uptime': '运行中',
            'requests_count': 100,  # 在实际应用中，这应该从某种存储中获取
            'memory_usage': '约50MB',
            'last_restart': '2024-01-01T00:00:00'
        }
        
        return jsonify(stats)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    """
    404错误处理
    """
    return jsonify({
        'error': '页面未找到',
        'status_code': 404,
        'timestamp': datetime.datetime.now().isoformat()
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """
    500错误处理
    """
    return jsonify({
        'error': '服务器内部错误',
        'status_code': 500,
        'timestamp': datetime.datetime.now().isoformat()
    }), 500

if __name__ == '__main__':
    # 获取环境变量配置
    host = os.environ.get('FLASK_HOST', '0.0.0.0')
    port = int(os.environ.get('FLASK_PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    
    print(f"🚀 Flask应用启动中...")
    print(f"🌐 访问地址: http://{host}:{port}")
    print(f"📊 健康检查: http://{host}:{port}/health")
    print(f"🔧 API接口: http://{host}:{port}/api/info")
    print(f"📈 统计信息: http://{host}:{port}/api/stats")
    print(f"🐛 调试模式: {'开启' if debug else '关闭'}")
    
    # 启动Flask应用
    app.run(
        host=host,
        port=port,
        debug=debug,
        threaded=True  # 启用多线程支持
    )