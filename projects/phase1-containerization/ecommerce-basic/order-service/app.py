"""
订单服务
提供订单创建、支付处理、订单状态管理等功能
"""

import os
import logging
from datetime import datetime
from enum import Enum
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_cors import CORS
from marshmallow import Schema, fields, ValidationError
import redis
import pika
import json
import requests
from decimal import Decimal

# 应用初始化
app = Flask(__name__)

# 配置
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:ecommerce123@localhost:5432/ecommerce_orders')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 扩展初始化
db = SQLAlchemy(app)
migrate = Migrate(app, db)
CORS(app)

# Redis连接
redis_client = redis.from_url(os.getenv('REDIS_URL', 'redis://localhost:6379/2'))

# RabbitMQ连接
rabbitmq_url = os.getenv('RABBITMQ_URL', 'amqp://admin:rabbitmq123@localhost:5672/')

# 外部服务URL
USER_SERVICE_URL = os.getenv('USER_SERVICE_URL', 'http://localhost:5001')
PRODUCT_SERVICE_URL = os.getenv('PRODUCT_SERVICE_URL', 'http://localhost:5002')

# 日志配置
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 枚举定义
class OrderStatus(Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    PAID = "paid"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"

class PaymentStatus(Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"

# 数据模型
class Order(db.Model):
    __tablename__ = 'orders'
    
    id = db.Column(db.Integer, primary_key=True)
    order_number = db.Column(db.String(50), unique=True, nullable=False)
    user_id = db.Column(db.Integer, nullable=False)
    status = db.Column(db.Enum(OrderStatus), default=OrderStatus.PENDING)
    total_amount = db.Column(db.Numeric(10, 2), nullable=False)
    subtotal = db.Column(db.Numeric(10, 2), nullable=False)
    tax_amount = db.Column(db.Numeric(10, 2), default=0)
    shipping_amount = db.Column(db.Numeric(10, 2), default=0)
    discount_amount = db.Column(db.Numeric(10, 2), default=0)
    
    # 收货信息
    shipping_address = db.Column(db.Text)
    shipping_city = db.Column(db.String(100))
    shipping_state = db.Column(db.String(100))
    shipping_zip = db.Column(db.String(20))
    shipping_country = db.Column(db.String(100))
    recipient_name = db.Column(db.String(100))
    recipient_phone = db.Column(db.String(20))
    
    # 时间戳
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    confirmed_at = db.Column(db.DateTime)
    shipped_at = db.Column(db.DateTime)
    delivered_at = db.Column(db.DateTime)
    cancelled_at = db.Column(db.DateTime)
    
    # 关系
    items = db.relationship('OrderItem', backref='order', lazy=True, cascade='all, delete-orphan')
    payments = db.relationship('Payment', backref='order', lazy=True, cascade='all, delete-orphan')
    
    def generate_order_number(self):
        """生成订单号"""
        timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
        return f"ORD{timestamp}{self.id:06d}"
    
    def to_dict(self):
        return {
            'id': self.id,
            'order_number': self.order_number,
            'user_id': self.user_id,
            'status': self.status.value if self.status else None,
            'total_amount': float(self.total_amount) if self.total_amount else 0,
            'subtotal': float(self.subtotal) if self.subtotal else 0,
            'tax_amount': float(self.tax_amount) if self.tax_amount else 0,
            'shipping_amount': float(self.shipping_amount) if self.shipping_amount else 0,
            'discount_amount': float(self.discount_amount) if self.discount_amount else 0,
            'shipping_address': self.shipping_address,
            'shipping_city': self.shipping_city,
            'shipping_state': self.shipping_state,
            'shipping_zip': self.shipping_zip,
            'shipping_country': self.shipping_country,
            'recipient_name': self.recipient_name,
            'recipient_phone': self.recipient_phone,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'confirmed_at': self.confirmed_at.isoformat() if self.confirmed_at else None,
            'shipped_at': self.shipped_at.isoformat() if self.shipped_at else None,
            'delivered_at': self.delivered_at.isoformat() if self.delivered_at else None,
            'cancelled_at': self.cancelled_at.isoformat() if self.cancelled_at else None,
            'items': [item.to_dict() for item in self.items],
            'payments': [payment.to_dict() for payment in self.payments]
        }

class OrderItem(db.Model):
    __tablename__ = 'order_items'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    product_id = db.Column(db.Integer, nullable=False)
    product_name = db.Column(db.String(200), nullable=False)
    product_sku = db.Column(db.String(50), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    unit_price = db.Column(db.Numeric(10, 2), nullable=False)
    total_price = db.Column(db.Numeric(10, 2), nullable=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'order_id': self.order_id,
            'product_id': self.product_id,
            'product_name': self.product_name,
            'product_sku': self.product_sku,
            'quantity': self.quantity,
            'unit_price': float(self.unit_price) if self.unit_price else 0,
            'total_price': float(self.total_price) if self.total_price else 0
        }

class Payment(db.Model):
    __tablename__ = 'payments'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    payment_method = db.Column(db.String(50), nullable=False)  # card, wechat, alipay, etc.
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    status = db.Column(db.Enum(PaymentStatus), default=PaymentStatus.PENDING)
    transaction_id = db.Column(db.String(100))
    gateway_response = db.Column(db.Text)  # JSON格式的支付网关响应
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    completed_at = db.Column(db.DateTime)
    
    def to_dict(self):
        return {
            'id': self.id,
            'order_id': self.order_id,
            'payment_method': self.payment_method,
            'amount': float(self.amount) if self.amount else 0,
            'status': self.status.value if self.status else None,
            'transaction_id': self.transaction_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'completed_at': self.completed_at.isoformat() if self.completed_at else None
        }

# 数据验证Schema
class OrderItemSchema(Schema):
    product_id = fields.Int(required=True)
    quantity = fields.Int(required=True, validate=lambda x: x > 0)

class OrderCreateSchema(Schema):
    items = fields.List(fields.Nested(OrderItemSchema), required=True, validate=lambda x: len(x) > 0)
    shipping_address = fields.Str(required=True)
    shipping_city = fields.Str(required=True)
    shipping_state = fields.Str()
    shipping_zip = fields.Str()
    shipping_country = fields.Str(required=True)
    recipient_name = fields.Str(required=True)
    recipient_phone = fields.Str(required=True)

class PaymentCreateSchema(Schema):
    payment_method = fields.Str(required=True, validate=lambda x: x in ['card', 'wechat', 'alipay'])
    amount = fields.Decimal(required=True, places=2, validate=lambda x: x > 0)

# 消息队列发布器
def publish_event(event_type, data):
    """发布事件到消息队列"""
    try:
        connection = pika.BlockingConnection(pika.URLParameters(rabbitmq_url))
        channel = connection.channel()
        
        # 声明交换机
        channel.exchange_declare(exchange='order.events', exchange_type='topic')
        
        message = {
            'event_type': event_type,
            'timestamp': datetime.utcnow().isoformat(),
            'data': data
        }
        
        channel.basic_publish(
            exchange='order.events',
            routing_key=event_type,
            body=json.dumps(message),
            properties=pika.BasicProperties(
                content_type='application/json',
                delivery_mode=2
            )
        )
        
        connection.close()
        logger.info(f"Published event: {event_type}")
        
    except Exception as e:
        logger.error(f"Failed to publish event: {e}")

# 外部服务调用
def get_user_info(user_id):
    """从用户服务获取用户信息"""
    try:
        response = requests.get(f"{USER_SERVICE_URL}/api/v1/users/{user_id}", timeout=5)
        if response.status_code == 200:
            return response.json().get('user')
        return None
    except Exception as e:
        logger.error(f"Failed to get user info: {e}")
        return None

def get_product_info(product_id):
    """从商品服务获取商品信息"""
    try:
        response = requests.get(f"{PRODUCT_SERVICE_URL}/api/v1/products/{product_id}", timeout=5)
        if response.status_code == 200:
            return response.json().get('product')
        return None
    except Exception as e:
        logger.error(f"Failed to get product info: {e}")
        return None

def update_product_stock(product_id, quantity_change, operation='reserve'):
    """更新商品库存"""
    try:
        payload = {
            'quantity_change': quantity_change,
            'operation': operation
        }
        response = requests.post(
            f"{PRODUCT_SERVICE_URL}/api/v1/products/{product_id}/stock",
            json=payload,
            timeout=5
        )
        return response.status_code == 200
    except Exception as e:
        logger.error(f"Failed to update product stock: {e}")
        return False

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
    
    # 检查外部服务连接
    try:
        user_service_response = requests.get(f"{USER_SERVICE_URL}/health", timeout=3)
        user_service_status = "healthy" if user_service_response.status_code == 200 else "unhealthy"
    except:
        user_service_status = "unhealthy"
    
    try:
        product_service_response = requests.get(f"{PRODUCT_SERVICE_URL}/health", timeout=3)
        product_service_status = "healthy" if product_service_response.status_code == 200 else "unhealthy"
    except:
        product_service_status = "unhealthy"
    
    overall_status = "healthy" if all([
        db_status == "healthy",
        redis_status == "healthy",
        user_service_status == "healthy",
        product_service_status == "healthy"
    ]) else "unhealthy"
    
    return jsonify({
        'status': overall_status,
        'service': 'order-service',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat(),
        'components': {
            'database': db_status,
            'redis': redis_status,
            'user_service': user_service_status,
            'product_service': product_service_status
        }
    })

@app.route('/api/v1/orders', methods=['POST'])
def create_order():
    """创建订单"""
    schema = OrderCreateSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    # 这里应该从JWT token中获取用户ID，简化处理直接从请求中获取
    user_id = request.json.get('user_id')
    if not user_id:
        return jsonify({'error': 'User ID is required'}), 400
    
    # 验证用户是否存在
    user_info = get_user_info(user_id)
    if not user_info:
        return jsonify({'error': 'User not found'}), 404
    
    try:
        # 验证商品信息并计算总价
        order_items_data = []
        subtotal = Decimal('0.00')
        
        for item_data in data['items']:
            product_info = get_product_info(item_data['product_id'])
            if not product_info:
                return jsonify({'error': f'Product {item_data["product_id"]} not found'}), 404
            
            if not product_info['is_active']:
                return jsonify({'error': f'Product {product_info["name"]} is not available'}), 400
            
            if product_info['stock_quantity'] < item_data['quantity']:
                return jsonify({'error': f'Insufficient stock for {product_info["name"]}'}), 400
            
            unit_price = Decimal(str(product_info['price']))
            total_price = unit_price * item_data['quantity']
            subtotal += total_price
            
            order_items_data.append({
                'product_id': item_data['product_id'],
                'product_name': product_info['name'],
                'product_sku': product_info['sku'],
                'quantity': item_data['quantity'],
                'unit_price': unit_price,
                'total_price': total_price
            })
        
        # 计算税费和运费（简化计算）
        tax_rate = Decimal('0.08')  # 8% 税率
        tax_amount = subtotal * tax_rate
        shipping_amount = Decimal('10.00') if subtotal < 100 else Decimal('0.00')  # 满100免运费
        total_amount = subtotal + tax_amount + shipping_amount
        
        # 创建订单
        order = Order(
            user_id=user_id,
            subtotal=subtotal,
            tax_amount=tax_amount,
            shipping_amount=shipping_amount,
            total_amount=total_amount,
            shipping_address=data['shipping_address'],
            shipping_city=data['shipping_city'],
            shipping_state=data.get('shipping_state'),
            shipping_zip=data.get('shipping_zip'),
            shipping_country=data['shipping_country'],
            recipient_name=data['recipient_name'],
            recipient_phone=data['recipient_phone']
        )
        
        db.session.add(order)
        db.session.flush()  # 获取订单ID
        
        # 生成订单号
        order.order_number = order.generate_order_number()
        
        # 创建订单项
        for item_data in order_items_data:
            order_item = OrderItem(
                order_id=order.id,
                **item_data
            )
            db.session.add(order_item)
        
        db.session.commit()
        
        # 预留库存
        for item_data in data['items']:
            update_product_stock(item_data['product_id'], item_data['quantity'], 'reserve')
        
        # 发布订单创建事件
        publish_event('order.created', {
            'order_id': order.id,
            'order_number': order.order_number,
            'user_id': user_id,
            'total_amount': float(total_amount),
            'items': [{'product_id': item['product_id'], 'quantity': item['quantity']} for item in data['items']]
        })
        
        logger.info(f"Order created: {order.order_number}")
        
        return jsonify({
            'message': 'Order created successfully',
            'order': order.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Order creation failed: {e}")
        return jsonify({'error': 'Order creation failed'}), 500

@app.route('/api/v1/orders', methods=['GET'])
def get_orders():
    """获取订单列表"""
    try:
        # 这里应该从JWT token中获取用户ID
        user_id = request.args.get('user_id', type=int)
        if not user_id:
            return jsonify({'error': 'User ID is required'}), 400
        
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)
        status = request.args.get('status')
        
        # 构建查询
        query = Order.query.filter_by(user_id=user_id)
        
        if status:
            try:
                status_enum = OrderStatus(status)
                query = query.filter(Order.status == status_enum)
            except ValueError:
                return jsonify({'error': 'Invalid status'}), 400
        
        # 分页查询
        orders_pagination = query.order_by(Order.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        orders_data = [order.to_dict() for order in orders_pagination.items]
        
        return jsonify({
            'orders': orders_data,
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': orders_pagination.total,
                'pages': orders_pagination.pages,
                'has_next': orders_pagination.has_next,
                'has_prev': orders_pagination.has_prev
            }
        })
        
    except Exception as e:
        logger.error(f"Failed to get orders: {e}")
        return jsonify({'error': 'Failed to get orders'}), 500

@app.route('/api/v1/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    """获取订单详情"""
    try:
        order = Order.query.get(order_id)
        if not order:
            return jsonify({'error': 'Order not found'}), 404
        
        # 这里应该验证用户权限
        user_id = request.args.get('user_id', type=int)
        if user_id and order.user_id != user_id:
            return jsonify({'error': 'Permission denied'}), 403
        
        return jsonify({'order': order.to_dict()})
        
    except Exception as e:
        logger.error(f"Failed to get order: {e}")
        return jsonify({'error': 'Failed to get order'}), 500

@app.route('/api/v1/orders/<int:order_id>/pay', methods=['POST'])
def pay_order():
    """支付订单"""
    schema = PaymentCreateSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    order = Order.query.get(order_id)
    if not order:
        return jsonify({'error': 'Order not found'}), 404
    
    if order.status != OrderStatus.PENDING:
        return jsonify({'error': 'Order cannot be paid'}), 400
    
    if data['amount'] != order.total_amount:
        return jsonify({'error': 'Payment amount does not match order total'}), 400
    
    try:
        # 创建支付记录
        payment = Payment(
            order_id=order.id,
            payment_method=data['payment_method'],
            amount=data['amount'],
            status=PaymentStatus.PROCESSING
        )
        
        db.session.add(payment)
        db.session.flush()
        
        # 模拟支付处理（实际应该调用支付网关）
        import uuid
        transaction_id = str(uuid.uuid4())
        
        # 模拟支付成功
        payment.status = PaymentStatus.COMPLETED
        payment.transaction_id = transaction_id
        payment.completed_at = datetime.utcnow()
        payment.gateway_response = json.dumps({
            'status': 'success',
            'transaction_id': transaction_id,
            'amount': float(data['amount']),
            'currency': 'CNY'
        })
        
        # 更新订单状态
        order.status = OrderStatus.PAID
        
        db.session.commit()
        
        # 发布支付完成事件
        publish_event('order.paid', {
            'order_id': order.id,
            'order_number': order.order_number,
            'user_id': order.user_id,
            'payment_id': payment.id,
            'amount': float(data['amount']),
            'payment_method': data['payment_method']
        })
        
        logger.info(f"Order paid: {order.order_number}")
        
        return jsonify({
            'message': 'Payment processed successfully',
            'payment': payment.to_dict(),
            'order': order.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Payment processing failed: {e}")
        return jsonify({'error': 'Payment processing failed'}), 500

@app.route('/api/v1/orders/<int:order_id>/cancel', methods=['POST'])
def cancel_order():
    """取消订单"""
    try:
        order = Order.query.get(order_id)
        if not order:
            return jsonify({'error': 'Order not found'}), 404
        
        if order.status not in [OrderStatus.PENDING, OrderStatus.CONFIRMED]:
            return jsonify({'error': 'Order cannot be cancelled'}), 400
        
        # 释放库存
        for item in order.items:
            update_product_stock(item.product_id, item.quantity, 'release')
        
        # 更新订单状态
        order.status = OrderStatus.CANCELLED
        order.cancelled_at = datetime.utcnow()
        
        db.session.commit()
        
        # 发布订单取消事件
        publish_event('order.cancelled', {
            'order_id': order.id,
            'order_number': order.order_number,
            'user_id': order.user_id,
            'cancelled_at': order.cancelled_at.isoformat()
        })
        
        logger.info(f"Order cancelled: {order.order_number}")
        
        return jsonify({
            'message': 'Order cancelled successfully',
            'order': order.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Order cancellation failed: {e}")
        return jsonify({'error': 'Order cancellation failed'}), 500

@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """获取订单服务统计信息"""
    try:
        total_orders = Order.query.count()
        pending_orders = Order.query.filter_by(status=OrderStatus.PENDING).count()
        paid_orders = Order.query.filter_by(status=OrderStatus.PAID).count()
        completed_orders = Order.query.filter(Order.status.in_([OrderStatus.DELIVERED])).count()
        
        # 计算总收入
        total_revenue = db.session.query(db.func.sum(Order.total_amount)).filter(
            Order.status.in_([OrderStatus.PAID, OrderStatus.SHIPPED, OrderStatus.DELIVERED])
        ).scalar() or 0
        
        return jsonify({
            'total_orders': total_orders,
            'pending_orders': pending_orders,
            'paid_orders': paid_orders,
            'completed_orders': completed_orders,
            'total_revenue': float(total_revenue)
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
    
    app.run(host='0.0.0.0', port=5003, debug=os.getenv('FLASK_ENV') == 'development')