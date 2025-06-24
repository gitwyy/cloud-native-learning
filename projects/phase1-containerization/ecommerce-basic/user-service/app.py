"""
用户管理服务
提供用户注册、登录、认证、个人信息管理等功能
"""

import os
import logging
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from marshmallow import Schema, fields, ValidationError
import redis
import pika
import json

# 应用初始化
app = Flask(__name__)

# 配置
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:ecommerce123@localhost:5432/ecommerce_users')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'user-service-secret-key')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

# 扩展初始化
db = SQLAlchemy(app)
migrate = Migrate(app, db)
jwt = JWTManager(app)
CORS(app)

# Redis连接
redis_client = redis.from_url(os.getenv('REDIS_URL', 'redis://localhost:6379/0'))

# RabbitMQ连接
rabbitmq_url = os.getenv('RABBITMQ_URL', 'amqp://admin:rabbitmq123@localhost:5672/')

# 日志配置
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 数据模型
class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(50))
    last_name = db.Column(db.String(50))
    phone = db.Column(db.String(20))
    is_active = db.Column(db.Boolean, default=True)
    is_admin = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'phone': self.phone,
            'is_active': self.is_active,
            'is_admin': self.is_admin,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

# 数据验证Schema
class UserRegistrationSchema(Schema):
    username = fields.Str(required=True, validate=lambda x: len(x) >= 3)
    email = fields.Email(required=True)
    password = fields.Str(required=True, validate=lambda x: len(x) >= 6)
    first_name = fields.Str(required=True)
    last_name = fields.Str(required=True)
    phone = fields.Str()

class UserLoginSchema(Schema):
    username = fields.Str(required=True)
    password = fields.Str(required=True)

class UserUpdateSchema(Schema):
    first_name = fields.Str()
    last_name = fields.Str()
    phone = fields.Str()
    email = fields.Email()

# 消息队列发布器
def publish_event(event_type, data):
    """发布事件到消息队列"""
    try:
        connection = pika.BlockingConnection(pika.URLParameters(rabbitmq_url))
        channel = connection.channel()
        
        # 声明交换机
        channel.exchange_declare(exchange='user.events', exchange_type='topic')
        
        message = {
            'event_type': event_type,
            'timestamp': datetime.utcnow().isoformat(),
            'data': data
        }
        
        channel.basic_publish(
            exchange='user.events',
            routing_key=event_type,
            body=json.dumps(message),
            properties=pika.BasicProperties(
                content_type='application/json',
                delivery_mode=2  # 持久化消息
            )
        )
        
        connection.close()
        logger.info(f"Published event: {event_type}")
        
    except Exception as e:
        logger.error(f"Failed to publish event: {e}")

# API路由
@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    try:
        # 检查数据库连接
        db.session.execute(db.text('SELECT 1'))
        db_status = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = "unhealthy"
    
    try:
        # 检查Redis连接
        redis_client.ping()
        redis_status = "healthy"
    except Exception as e:
        logger.error(f"Redis health check failed: {e}")
        redis_status = "unhealthy"
    
    return jsonify({
        'status': 'healthy' if db_status == 'healthy' and redis_status == 'healthy' else 'unhealthy',
        'service': 'user-service',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat(),
        'components': {
            'database': db_status,
            'redis': redis_status
        }
    })

@app.route('/api/v1/register', methods=['POST'])
def register():
    """用户注册"""
    schema = UserRegistrationSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    # 检查用户名和邮箱是否已存在
    if User.query.filter_by(username=data['username']).first():
        return jsonify({'error': 'Username already exists'}), 409
    
    if User.query.filter_by(email=data['email']).first():
        return jsonify({'error': 'Email already exists'}), 409
    
    # 创建新用户
    user = User(
        username=data['username'],
        email=data['email'],
        first_name=data['first_name'],
        last_name=data['last_name'],
        phone=data.get('phone')
    )
    user.set_password(data['password'])
    
    try:
        db.session.add(user)
        db.session.commit()
        
        # 发布用户注册事件
        publish_event('user.registered', {
            'user_id': user.id,
            'username': user.username,
            'email': user.email
        })
        
        # 缓存用户信息
        user_cache_key = f"user:{user.id}"
        redis_client.setex(user_cache_key, 3600, json.dumps(user.to_dict()))
        
        logger.info(f"User registered: {user.username}")
        
        return jsonify({
            'message': 'User registered successfully',
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Registration failed: {e}")
        return jsonify({'error': 'Registration failed'}), 500

@app.route('/api/v1/login', methods=['POST'])
def login():
    """用户登录"""
    schema = UserLoginSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    user = User.query.filter_by(username=data['username']).first()
    
    if not user or not user.check_password(data['password']):
        return jsonify({'error': 'Invalid username or password'}), 401
    
    if not user.is_active:
        return jsonify({'error': 'Account is deactivated'}), 401
    
    # 创建访问令牌
    access_token = create_access_token(
        identity=user.id,
        additional_claims={'username': user.username, 'is_admin': user.is_admin}
    )
    
    # 缓存用户会话
    session_key = f"session:{user.id}"
    session_data = {
        'user_id': user.id,
        'username': user.username,
        'login_time': datetime.utcnow().isoformat()
    }
    redis_client.setex(session_key, 86400, json.dumps(session_data))  # 24小时过期
    
    # 发布登录事件
    publish_event('user.logged_in', {
        'user_id': user.id,
        'username': user.username,
        'login_time': datetime.utcnow().isoformat()
    })
    
    logger.info(f"User logged in: {user.username}")
    
    return jsonify({
        'message': 'Login successful',
        'access_token': access_token,
        'user': user.to_dict()
    })

@app.route('/api/v1/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """获取用户个人信息"""
    user_id = get_jwt_identity()
    
    # 先从缓存中获取
    user_cache_key = f"user:{user_id}"
    cached_user = redis_client.get(user_cache_key)
    
    if cached_user:
        user_data = json.loads(cached_user)
        return jsonify({'user': user_data})
    
    # 从数据库获取
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    # 更新缓存
    redis_client.setex(user_cache_key, 3600, json.dumps(user.to_dict()))
    
    return jsonify({'user': user.to_dict()})

@app.route('/api/v1/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    """更新用户个人信息"""
    user_id = get_jwt_identity()
    schema = UserUpdateSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    # 如果更新邮箱，检查是否已被其他用户使用
    if 'email' in data and data['email'] != user.email:
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': 'Email already exists'}), 409
    
    # 更新用户信息
    for field in ['first_name', 'last_name', 'phone', 'email']:
        if field in data:
            setattr(user, field, data[field])
    
    user.updated_at = datetime.utcnow()
    
    try:
        db.session.commit()
        
        # 更新缓存
        user_cache_key = f"user:{user_id}"
        redis_client.setex(user_cache_key, 3600, json.dumps(user.to_dict()))
        
        # 发布用户更新事件
        publish_event('user.profile_updated', {
            'user_id': user.id,
            'username': user.username,
            'updated_fields': list(data.keys())
        })
        
        logger.info(f"User profile updated: {user.username}")
        
        return jsonify({
            'message': 'Profile updated successfully',
            'user': user.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Profile update failed: {e}")
        return jsonify({'error': 'Profile update failed'}), 500

@app.route('/api/v1/users/<int:user_id>', methods=['GET'])
@jwt_required()
def get_user_by_id(user_id):
    """根据ID获取用户信息（仅管理员或本人）"""
    current_user_id = get_jwt_identity()
    current_user = User.query.get(current_user_id)
    
    # 检查权限：只有管理员或本人可以查看
    if current_user_id != user_id and not current_user.is_admin:
        return jsonify({'error': 'Permission denied'}), 403
    
    # 先从缓存获取
    user_cache_key = f"user:{user_id}"
    cached_user = redis_client.get(user_cache_key)
    
    if cached_user:
        user_data = json.loads(cached_user)
        return jsonify({'user': user_data})
    
    # 从数据库获取
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    # 更新缓存
    redis_client.setex(user_cache_key, 3600, json.dumps(user.to_dict()))
    
    return jsonify({'user': user.to_dict()})

@app.route('/api/v1/logout', methods=['POST'])
@jwt_required()
def logout():
    """用户退出登录"""
    user_id = get_jwt_identity()
    
    # 清除会话缓存
    session_key = f"session:{user_id}"
    redis_client.delete(session_key)
    
    # 发布退出登录事件
    user = User.query.get(user_id)
    if user:
        publish_event('user.logged_out', {
            'user_id': user.id,
            'username': user.username,
            'logout_time': datetime.utcnow().isoformat()
        })
        
        logger.info(f"User logged out: {user.username}")
    
    return jsonify({'message': 'Logout successful'})

@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """获取用户服务统计信息"""
    try:
        total_users = User.query.count()
        active_users = User.query.filter_by(is_active=True).count()
        admin_users = User.query.filter_by(is_admin=True).count()
        
        return jsonify({
            'total_users': total_users,
            'active_users': active_users,
            'admin_users': admin_users,
            'inactive_users': total_users - active_users
        })
    except Exception as e:
        logger.error(f"Failed to get stats: {e}")
        return jsonify({'error': 'Failed to get statistics'}), 500

# 错误处理
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Resource not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return jsonify({'error': 'Internal server error'}), 500

@jwt.expired_token_loader
def expired_token_callback(jwt_header, jwt_payload):
    return jsonify({'error': 'Token has expired'}), 401

@jwt.invalid_token_loader
def invalid_token_callback(error):
    return jsonify({'error': 'Invalid token'}), 401

# 应用启动
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        
        # 创建默认管理员用户
        admin = User.query.filter_by(username='admin').first()
        if not admin:
            admin = User(
                username='admin',
                email='admin@ecommerce.local',
                first_name='System',
                last_name='Administrator',
                is_admin=True
            )
            admin.set_password('admin123')
            db.session.add(admin)
            db.session.commit()
            logger.info("Default admin user created")
    
    app.run(host='0.0.0.0', port=5001, debug=os.getenv('FLASK_ENV') == 'development')