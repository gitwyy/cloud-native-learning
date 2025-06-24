"""
通知服务
提供邮件通知、短信通知、消息队列处理等功能
"""

import os
import logging
import smtplib
import threading
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_cors import CORS
from marshmallow import Schema, fields, ValidationError
import redis
import pika
import json
from enum import Enum

# 应用初始化
app = Flask(__name__)

# 配置
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:ecommerce123@localhost:5432/ecommerce_notifications')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 扩展初始化
db = SQLAlchemy(app)
migrate = Migrate(app, db)
CORS(app)

# Redis连接
redis_client = redis.from_url(os.getenv('REDIS_URL', 'redis://localhost:6379/3'))

# RabbitMQ连接
rabbitmq_url = os.getenv('RABBITMQ_URL', 'amqp://admin:rabbitmq123@localhost:5672/')

# 邮件配置
EMAIL_SMTP_HOST = os.getenv('EMAIL_SMTP_HOST', 'smtp.gmail.com')
EMAIL_SMTP_PORT = int(os.getenv('EMAIL_SMTP_PORT', '587'))
EMAIL_USERNAME = os.getenv('EMAIL_USERNAME', '')
EMAIL_PASSWORD = os.getenv('EMAIL_PASSWORD', '')

# 日志配置
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 枚举定义
class NotificationType(Enum):
    EMAIL = "email"
    SMS = "sms"
    PUSH = "push"

class NotificationStatus(Enum):
    PENDING = "pending"
    SENDING = "sending"
    SENT = "sent"
    FAILED = "failed"
    DELIVERED = "delivered"

# 数据模型
class NotificationTemplate(db.Model):
    __tablename__ = 'notification_templates'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    type = db.Column(db.Enum(NotificationType), nullable=False)
    subject = db.Column(db.String(200))  # 邮件主题或短信标题
    content = db.Column(db.Text, nullable=False)  # 模板内容，支持变量替换
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'type': self.type.value if self.type else None,
            'subject': self.subject,
            'content': self.content,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class Notification(db.Model):
    __tablename__ = 'notifications'
    
    id = db.Column(db.Integer, primary_key=True)
    type = db.Column(db.Enum(NotificationType), nullable=False)
    recipient = db.Column(db.String(200), nullable=False)  # 邮箱地址或手机号
    subject = db.Column(db.String(200))
    content = db.Column(db.Text, nullable=False)
    status = db.Column(db.Enum(NotificationStatus), default=NotificationStatus.PENDING)
    template_id = db.Column(db.Integer, db.ForeignKey('notification_templates.id'))
    user_id = db.Column(db.Integer)  # 接收用户ID
    related_id = db.Column(db.String(100))  # 相关业务ID（如订单ID）
    related_type = db.Column(db.String(50))  # 相关业务类型（如order、user）
    extra_data = db.Column(db.Text)  # JSON格式的额外数据
    error_message = db.Column(db.Text)
    sent_at = db.Column(db.DateTime)
    delivered_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # 关系
    template = db.relationship('NotificationTemplate', backref='notifications')
    
    def to_dict(self):
        return {
            'id': self.id,
            'type': self.type.value if self.type else None,
            'recipient': self.recipient,
            'subject': self.subject,
            'content': self.content,
            'status': self.status.value if self.status else None,
            'template_id': self.template_id,
            'user_id': self.user_id,
            'related_id': self.related_id,
            'related_type': self.related_type,
            'metadata': json.loads(self.extra_data) if self.extra_data else None,
            'error_message': self.error_message,
            'sent_at': self.sent_at.isoformat() if self.sent_at else None,
            'delivered_at': self.delivered_at.isoformat() if self.delivered_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

# 数据验证Schema
class NotificationCreateSchema(Schema):
    type = fields.Str(required=True, validate=lambda x: x in ['email', 'sms', 'push'])
    recipient = fields.Str(required=True)
    subject = fields.Str()
    content = fields.Str(required=True)
    template_id = fields.Int()
    user_id = fields.Int()
    related_id = fields.Str()
    related_type = fields.Str()
    metadata = fields.Dict()

class TemplateCreateSchema(Schema):
    name = fields.Str(required=True)
    type = fields.Str(required=True, validate=lambda x: x in ['email', 'sms', 'push'])
    subject = fields.Str()
    content = fields.Str(required=True)

# 邮件发送器
class EmailSender:
    def __init__(self):
        self.smtp_host = EMAIL_SMTP_HOST
        self.smtp_port = EMAIL_SMTP_PORT
        self.username = EMAIL_USERNAME
        self.password = EMAIL_PASSWORD
    
    def send_email(self, to_email, subject, content, content_type='html'):
        """发送邮件"""
        if not self.username or not self.password:
            logger.warning("Email credentials not configured")
            return False, "Email credentials not configured"
        
        try:
            # 创建邮件对象
            msg = MIMEMultipart()
            msg['From'] = self.username
            msg['To'] = to_email
            msg['Subject'] = subject
            
            # 添加邮件内容
            msg.attach(MIMEText(content, content_type, 'utf-8'))
            
            # 连接SMTP服务器并发送
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)
            
            logger.info(f"Email sent successfully to {to_email}")
            return True, "Email sent successfully"
            
        except Exception as e:
            error_msg = f"Failed to send email: {str(e)}"
            logger.error(error_msg)
            return False, error_msg

# 短信发送器（模拟实现）
class SMSSender:
    def __init__(self):
        self.api_key = os.getenv('SMS_API_KEY', '')
    
    def send_sms(self, phone_number, content):
        """发送短信"""
        if not self.api_key:
            logger.warning("SMS API key not configured")
            return False, "SMS API key not configured"
        
        try:
            # 这里应该调用实际的短信API
            # 现在只是模拟发送
            logger.info(f"SMS would be sent to {phone_number}: {content}")
            return True, "SMS sent successfully (simulated)"
            
        except Exception as e:
            error_msg = f"Failed to send SMS: {str(e)}"
            logger.error(error_msg)
            return False, error_msg

# 通知处理器
class NotificationProcessor:
    def __init__(self):
        self.email_sender = EmailSender()
        self.sms_sender = SMSSender()
    
    def process_notification(self, notification_id):
        """处理通知发送"""
        try:
            notification = Notification.query.get(notification_id)
            if not notification:
                logger.error(f"Notification {notification_id} not found")
                return
            
            # 更新状态为发送中
            notification.status = NotificationStatus.SENDING
            db.session.commit()
            
            success = False
            error_message = None
            
            if notification.type == NotificationType.EMAIL:
                success, error_message = self.email_sender.send_email(
                    notification.recipient,
                    notification.subject or "通知",
                    notification.content
                )
            elif notification.type == NotificationType.SMS:
                success, error_message = self.sms_sender.send_sms(
                    notification.recipient,
                    notification.content
                )
            elif notification.type == NotificationType.PUSH:
                # 推送通知处理
                success, error_message = True, "Push notification sent (simulated)"
            
            # 更新发送结果
            if success:
                notification.status = NotificationStatus.SENT
                notification.sent_at = datetime.utcnow()
            else:
                notification.status = NotificationStatus.FAILED
                notification.error_message = error_message
            
            db.session.commit()
            
        except Exception as e:
            logger.error(f"Failed to process notification {notification_id}: {e}")
            # 更新失败状态
            try:
                notification = Notification.query.get(notification_id)
                if notification:
                    notification.status = NotificationStatus.FAILED
                    notification.error_message = str(e)
                    db.session.commit()
            except:
                pass

# 消息队列消费者
def start_message_consumer():
    """启动消息队列消费者"""
    def callback(ch, method, properties, body):
        try:
            message = json.loads(body)
            event_type = message.get('event_type')
            data = message.get('data', {})
            
            logger.info(f"Received event: {event_type}")
            
            # 根据事件类型处理不同的通知
            processor = NotificationProcessor()
            
            if event_type == 'user.registered':
                # 用户注册欢迎邮件
                create_welcome_notification(data)
            elif event_type == 'order.created':
                # 订单创建确认
                create_order_confirmation_notification(data)
            elif event_type == 'order.paid':
                # 支付成功通知
                create_payment_confirmation_notification(data)
            elif event_type == 'order.shipped':
                # 发货通知
                create_shipping_notification(data)
            
            ch.basic_ack(delivery_tag=method.delivery_tag)
            
        except Exception as e:
            logger.error(f"Failed to process message: {e}")
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
    
    try:
        connection = pika.BlockingConnection(pika.URLParameters(rabbitmq_url))
        channel = connection.channel()
        
        # 声明队列
        channel.queue_declare(queue='notification.tasks', durable=True)
        
        # 绑定到各种事件交换机
        exchanges = ['user.events', 'order.events', 'product.events']
        for exchange in exchanges:
            channel.exchange_declare(exchange=exchange, exchange_type='topic')
            channel.queue_bind(exchange=exchange, queue='notification.tasks', routing_key='#')
        
        channel.basic_qos(prefetch_count=1)
        channel.basic_consume(queue='notification.tasks', on_message_callback=callback)
        
        logger.info("Started message consumer")
        channel.start_consuming()
        
    except Exception as e:
        logger.error(f"Failed to start message consumer: {e}")

# 通知创建辅助函数
def create_welcome_notification(data):
    """创建欢迎通知"""
    try:
        template = NotificationTemplate.query.filter_by(name='user_welcome_email').first()
        if not template:
            return
        
        content = template.content.format(
            username=data.get('username', ''),
            email=data.get('email', '')
        )
        
        notification = Notification(
            type=NotificationType.EMAIL,
            recipient=data.get('email', ''),
            subject=template.subject,
            content=content,
            template_id=template.id,
            user_id=data.get('user_id'),
            related_id=str(data.get('user_id')),
            related_type='user'
        )
        
        db.session.add(notification)
        db.session.commit()
        
        # 异步处理发送
        processor = NotificationProcessor()
        threading.Thread(target=processor.process_notification, args=(notification.id,)).start()
        
    except Exception as e:
        logger.error(f"Failed to create welcome notification: {e}")

def create_order_confirmation_notification(data):
    """创建订单确认通知"""
    try:
        # 这里应该获取用户邮箱，简化处理
        user_email = "user@example.com"  # 实际应该从用户服务获取
        
        template = NotificationTemplate.query.filter_by(name='order_confirmation_email').first()
        if not template:
            return
        
        content = template.content.format(
            order_number=data.get('order_number', ''),
            total_amount=data.get('total_amount', 0)
        )
        
        notification = Notification(
            type=NotificationType.EMAIL,
            recipient=user_email,
            subject=template.subject,
            content=content,
            template_id=template.id,
            user_id=data.get('user_id'),
            related_id=str(data.get('order_id')),
            related_type='order'
        )
        
        db.session.add(notification)
        db.session.commit()
        
        # 异步处理发送
        processor = NotificationProcessor()
        threading.Thread(target=processor.process_notification, args=(notification.id,)).start()
        
    except Exception as e:
        logger.error(f"Failed to create order confirmation notification: {e}")

def create_payment_confirmation_notification(data):
    """创建支付确认通知"""
    try:
        user_email = "user@example.com"  # 实际应该从用户服务获取
        
        template = NotificationTemplate.query.filter_by(name='payment_confirmation_email').first()
        if not template:
            return
        
        content = template.content.format(
            order_number=data.get('order_number', ''),
            amount=data.get('amount', 0),
            payment_method=data.get('payment_method', '')
        )
        
        notification = Notification(
            type=NotificationType.EMAIL,
            recipient=user_email,
            subject=template.subject,
            content=content,
            template_id=template.id,
            user_id=data.get('user_id'),
            related_id=str(data.get('order_id')),
            related_type='payment'
        )
        
        db.session.add(notification)
        db.session.commit()
        
        # 异步处理发送
        processor = NotificationProcessor()
        threading.Thread(target=processor.process_notification, args=(notification.id,)).start()
        
    except Exception as e:
        logger.error(f"Failed to create payment confirmation notification: {e}")

# API路由
@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    try:
        db.session.execute(db.text('SELECT 1'))
        db_status = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = "unhealthy"
    
    try:
        redis_client.ping()
        redis_status = "healthy"
    except Exception as e:
        logger.error(f"Redis health check failed: {e}")
        redis_status = "unhealthy"
    
    return jsonify({
        'status': 'healthy' if db_status == 'healthy' and redis_status == 'healthy' else 'unhealthy',
        'service': 'notification-service',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat(),
        'components': {
            'database': db_status,
            'redis': redis_status,
            'email_configured': bool(EMAIL_USERNAME and EMAIL_PASSWORD)
        }
    })

@app.route('/api/v1/notifications', methods=['POST'])
def create_notification():
    """创建通知"""
    schema = NotificationCreateSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    try:
        notification = Notification(
            type=NotificationType(data['type']),
            recipient=data['recipient'],
            subject=data.get('subject'),
            content=data['content'],
            template_id=data.get('template_id'),
            user_id=data.get('user_id'),
            related_id=data.get('related_id'),
            related_type=data.get('related_type'),
            extra_data=json.dumps(data.get('metadata')) if data.get('metadata') else None
        )
        
        db.session.add(notification)
        db.session.commit()
        
        # 异步处理发送
        processor = NotificationProcessor()
        threading.Thread(target=processor.process_notification, args=(notification.id,)).start()
        
        logger.info(f"Notification created: {notification.id}")
        
        return jsonify({
            'message': 'Notification created successfully',
            'notification': notification.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Notification creation failed: {e}")
        return jsonify({'error': 'Notification creation failed'}), 500

@app.route('/api/v1/notifications', methods=['GET'])
def get_notifications():
    """获取通知列表"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)
        user_id = request.args.get('user_id', type=int)
        status = request.args.get('status')
        type_filter = request.args.get('type')
        
        # 构建查询
        query = Notification.query
        
        if user_id:
            query = query.filter(Notification.user_id == user_id)
        
        if status:
            try:
                status_enum = NotificationStatus(status)
                query = query.filter(Notification.status == status_enum)
            except ValueError:
                return jsonify({'error': 'Invalid status'}), 400
        
        if type_filter:
            try:
                type_enum = NotificationType(type_filter)
                query = query.filter(Notification.type == type_enum)
            except ValueError:
                return jsonify({'error': 'Invalid type'}), 400
        
        # 分页查询
        notifications_pagination = query.order_by(Notification.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        notifications_data = [notification.to_dict() for notification in notifications_pagination.items]
        
        return jsonify({
            'notifications': notifications_data,
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': notifications_pagination.total,
                'pages': notifications_pagination.pages,
                'has_next': notifications_pagination.has_next,
                'has_prev': notifications_pagination.has_prev
            }
        })
        
    except Exception as e:
        logger.error(f"Failed to get notifications: {e}")
        return jsonify({'error': 'Failed to get notifications'}), 500

@app.route('/api/v1/templates', methods=['POST'])
def create_template():
    """创建通知模板"""
    schema = TemplateCreateSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    # 检查模板名称是否已存在
    if NotificationTemplate.query.filter_by(name=data['name']).first():
        return jsonify({'error': 'Template name already exists'}), 409
    
    try:
        template = NotificationTemplate(
            name=data['name'],
            type=NotificationType(data['type']),
            subject=data.get('subject'),
            content=data['content']
        )
        
        db.session.add(template)
        db.session.commit()
        
        logger.info(f"Template created: {template.name}")
        
        return jsonify({
            'message': 'Template created successfully',
            'template': template.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Template creation failed: {e}")
        return jsonify({'error': 'Template creation failed'}), 500

@app.route('/api/v1/templates', methods=['GET'])
def get_templates():
    """获取模板列表"""
    try:
        templates = NotificationTemplate.query.filter_by(is_active=True).all()
        templates_data = [template.to_dict() for template in templates]
        
        return jsonify({'templates': templates_data})
        
    except Exception as e:
        logger.error(f"Failed to get templates: {e}")
        return jsonify({'error': 'Failed to get templates'}), 500

@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """获取通知服务统计信息"""
    try:
        total_notifications = Notification.query.count()
        sent_notifications = Notification.query.filter_by(status=NotificationStatus.SENT).count()
        failed_notifications = Notification.query.filter_by(status=NotificationStatus.FAILED).count()
        pending_notifications = Notification.query.filter_by(status=NotificationStatus.PENDING).count()
        
        return jsonify({
            'total_notifications': total_notifications,
            'sent_notifications': sent_notifications,
            'failed_notifications': failed_notifications,
            'pending_notifications': pending_notifications,
            'success_rate': round((sent_notifications / total_notifications * 100), 2) if total_notifications > 0 else 0
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

# 应用启动
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        
        # 创建默认通知模板
        if NotificationTemplate.query.count() == 0:
            default_templates = [
                {
                    'name': 'user_welcome_email',
                    'type': NotificationType.EMAIL,
                    'subject': '欢迎注册我们的电商平台！',
                    'content': '''
                    <h2>欢迎 {username}！</h2>
                    <p>感谢您注册我们的电商平台！您的账户已成功创建。</p>
                    <p>邮箱：{email}</p>
                    <p>现在您可以开始浏览和购买商品了。</p>
                    <p>祝您购物愉快！</p>
                    '''
                },
                {
                    'name': 'order_confirmation_email',
                    'type': NotificationType.EMAIL,
                    'subject': '订单确认 - {order_number}',
                    'content': '''
                    <h2>订单确认</h2>
                    <p>您的订单已成功创建！</p>
                    <p>订单号：{order_number}</p>
                    <p>订单金额：¥{total_amount}</p>
                    <p>我们会尽快为您处理订单。</p>
                    '''
                },
                {
                    'name': 'payment_confirmation_email',
                    'type': NotificationType.EMAIL,
                    'subject': '支付确认 - {order_number}',
                    'content': '''
                    <h2>支付成功</h2>
                    <p>您的支付已成功完成！</p>
                    <p>订单号：{order_number}</p>
                    <p>支付金额：¥{amount}</p>
                    <p>支付方式：{payment_method}</p>
                    <p>我们会尽快为您发货。</p>
                    '''
                }
            ]
            
            for template_data in default_templates:
                template = NotificationTemplate(**template_data)
                db.session.add(template)
            
            db.session.commit()
            logger.info("Default notification templates created")
    
    # 启动消息队列消费者（在生产环境中应该用独立的worker进程）
    consumer_thread = threading.Thread(target=start_message_consumer, daemon=True)
    consumer_thread.start()
    
    app.run(host='0.0.0.0', port=5004, debug=os.getenv('FLASK_ENV') == 'development')