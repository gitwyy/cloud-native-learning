"""
商品管理服务
提供商品展示、搜索、库存管理等功能
"""

import os
import logging
from datetime import datetime
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_cors import CORS
from marshmallow import Schema, fields, ValidationError
import redis
import pika
import json
from decimal import Decimal

# 应用初始化
app = Flask(__name__)

# 配置
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:ecommerce123@localhost:5432/ecommerce_products')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 扩展初始化
db = SQLAlchemy(app)
migrate = Migrate(app, db)
CORS(app)

# Redis连接
redis_client = redis.from_url(os.getenv('REDIS_URL', 'redis://localhost:6379/1'))

# RabbitMQ连接
rabbitmq_url = os.getenv('RABBITMQ_URL', 'amqp://admin:rabbitmq123@localhost:5672/')

# 日志配置
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 数据模型
class Category(db.Model):
    __tablename__ = 'categories'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # 关系
    products = db.relationship('Product', backref='category', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Product(db.Model):
    __tablename__ = 'products'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    stock_quantity = db.Column(db.Integer, default=0)
    sku = db.Column(db.String(50), unique=True, nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'))
    image_url = db.Column(db.String(500))
    is_active = db.Column(db.Boolean, default=True)
    weight = db.Column(db.Numeric(8, 2))  # kg
    dimensions = db.Column(db.String(100))  # 长x宽x高
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'price': float(self.price) if self.price else 0,
            'stock_quantity': self.stock_quantity,
            'sku': self.sku,
            'category_id': self.category_id,
            'category': self.category.to_dict() if self.category else None,
            'image_url': self.image_url,
            'is_active': self.is_active,
            'weight': float(self.weight) if self.weight else None,
            'dimensions': self.dimensions,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

# 数据验证Schema
class CategorySchema(Schema):
    name = fields.Str(required=True, validate=lambda x: len(x.strip()) > 0)
    description = fields.Str()

class ProductSchema(Schema):
    name = fields.Str(required=True, validate=lambda x: len(x.strip()) > 0)
    description = fields.Str()
    price = fields.Decimal(required=True, places=2, validate=lambda x: x > 0)
    stock_quantity = fields.Int(validate=lambda x: x >= 0)
    sku = fields.Str(required=True)
    category_id = fields.Int(required=True)
    image_url = fields.Url()
    weight = fields.Decimal(places=2, validate=lambda x: x > 0)
    dimensions = fields.Str()

class ProductUpdateSchema(Schema):
    name = fields.Str(validate=lambda x: len(x.strip()) > 0)
    description = fields.Str()
    price = fields.Decimal(places=2, validate=lambda x: x > 0)
    stock_quantity = fields.Int(validate=lambda x: x >= 0)
    category_id = fields.Int()
    image_url = fields.Url()
    is_active = fields.Bool()
    weight = fields.Decimal(places=2, validate=lambda x: x > 0)
    dimensions = fields.Str()

# 消息队列发布器
def publish_event(event_type, data):
    """发布事件到消息队列"""
    try:
        connection = pika.BlockingConnection(pika.URLParameters(rabbitmq_url))
        channel = connection.channel()
        
        # 声明交换机
        channel.exchange_declare(exchange='product.events', exchange_type='topic')
        
        message = {
            'event_type': event_type,
            'timestamp': datetime.utcnow().isoformat(),
            'data': data
        }
        
        channel.basic_publish(
            exchange='product.events',
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
        'service': 'product-service',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat(),
        'components': {
            'database': db_status,
            'redis': redis_status
        }
    })

# 分类管理API
@app.route('/api/v1/categories', methods=['GET'])
def get_categories():
    """获取所有分类"""
    try:
        # 先从缓存获取
        cache_key = "categories:all"
        cached_categories = redis_client.get(cache_key)
        
        if cached_categories:
            categories_data = json.loads(cached_categories)
            return jsonify({'categories': categories_data})
        
        # 从数据库获取
        categories = Category.query.order_by(Category.name).all()
        categories_data = [category.to_dict() for category in categories]
        
        # 缓存结果
        redis_client.setex(cache_key, 3600, json.dumps(categories_data))
        
        return jsonify({'categories': categories_data})
        
    except Exception as e:
        logger.error(f"Failed to get categories: {e}")
        return jsonify({'error': 'Failed to get categories'}), 500

@app.route('/api/v1/categories', methods=['POST'])
def create_category():
    """创建新分类"""
    schema = CategorySchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    # 检查分类名是否已存在
    if Category.query.filter_by(name=data['name']).first():
        return jsonify({'error': 'Category name already exists'}), 409
    
    category = Category(
        name=data['name'],
        description=data.get('description')
    )
    
    try:
        db.session.add(category)
        db.session.commit()
        
        # 清除分类缓存
        redis_client.delete("categories:all")
        
        logger.info(f"Category created: {category.name}")
        
        return jsonify({
            'message': 'Category created successfully',
            'category': category.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Category creation failed: {e}")
        return jsonify({'error': 'Category creation failed'}), 500

# 商品管理API
@app.route('/api/v1/products', methods=['GET'])
def get_products():
    """获取商品列表"""
    try:
        # 查询参数
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)
        category_id = request.args.get('category_id', type=int)
        search = request.args.get('search', '').strip()
        is_active = request.args.get('is_active', 'true').lower() == 'true'
        
        # 构建查询
        query = Product.query
        
        if category_id:
            query = query.filter(Product.category_id == category_id)
        
        if search:
            query = query.filter(
                db.or_(
                    Product.name.ilike(f'%{search}%'),
                    Product.description.ilike(f'%{search}%'),
                    Product.sku.ilike(f'%{search}%')
                )
            )
        
        if is_active:
            query = query.filter(Product.is_active == True)
        
        # 分页查询
        products_pagination = query.order_by(Product.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        products_data = [product.to_dict() for product in products_pagination.items]
        
        return jsonify({
            'products': products_data,
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': products_pagination.total,
                'pages': products_pagination.pages,
                'has_next': products_pagination.has_next,
                'has_prev': products_pagination.has_prev
            }
        })
        
    except Exception as e:
        logger.error(f"Failed to get products: {e}")
        return jsonify({'error': 'Failed to get products'}), 500

@app.route('/api/v1/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    """获取单个商品详情"""
    try:
        # 先从缓存获取
        cache_key = f"product:{product_id}"
        cached_product = redis_client.get(cache_key)
        
        if cached_product:
            product_data = json.loads(cached_product)
            return jsonify({'product': product_data})
        
        # 从数据库获取
        product = Product.query.get(product_id)
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        product_data = product.to_dict()
        
        # 缓存结果
        redis_client.setex(cache_key, 1800, json.dumps(product_data))
        
        return jsonify({'product': product_data})
        
    except Exception as e:
        logger.error(f"Failed to get product: {e}")
        return jsonify({'error': 'Failed to get product'}), 500

@app.route('/api/v1/products', methods=['POST'])
def create_product():
    """创建新商品"""
    schema = ProductSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    # 检查SKU是否已存在
    if Product.query.filter_by(sku=data['sku']).first():
        return jsonify({'error': 'SKU already exists'}), 409
    
    # 检查分类是否存在
    category = Category.query.get(data['category_id'])
    if not category:
        return jsonify({'error': 'Category not found'}), 404
    
    product = Product(
        name=data['name'],
        description=data.get('description'),
        price=data['price'],
        stock_quantity=data.get('stock_quantity', 0),
        sku=data['sku'],
        category_id=data['category_id'],
        image_url=data.get('image_url'),
        weight=data.get('weight'),
        dimensions=data.get('dimensions')
    )
    
    try:
        db.session.add(product)
        db.session.commit()
        
        # 发布商品创建事件
        publish_event('product.created', {
            'product_id': product.id,
            'name': product.name,
            'sku': product.sku,
            'price': float(product.price),
            'stock_quantity': product.stock_quantity
        })
        
        logger.info(f"Product created: {product.name} ({product.sku})")
        
        return jsonify({
            'message': 'Product created successfully',
            'product': product.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Product creation failed: {e}")
        return jsonify({'error': 'Product creation failed'}), 500

@app.route('/api/v1/products/<int:product_id>', methods=['PUT'])
def update_product(product_id):
    """更新商品信息"""
    schema = ProductUpdateSchema()
    
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'error': 'Validation failed', 'messages': err.messages}), 400
    
    product = Product.query.get(product_id)
    if not product:
        return jsonify({'error': 'Product not found'}), 404
    
    # 检查分类是否存在
    if 'category_id' in data:
        category = Category.query.get(data['category_id'])
        if not category:
            return jsonify({'error': 'Category not found'}), 404
    
    # 记录库存变化
    old_stock = product.stock_quantity
    
    # 更新商品信息
    for field in ['name', 'description', 'price', 'stock_quantity', 'category_id', 
                  'image_url', 'is_active', 'weight', 'dimensions']:
        if field in data:
            setattr(product, field, data[field])
    
    product.updated_at = datetime.utcnow()
    
    try:
        db.session.commit()
        
        # 清除商品缓存
        cache_key = f"product:{product_id}"
        redis_client.delete(cache_key)
        
        # 如果库存发生变化，发布库存更新事件
        if 'stock_quantity' in data and data['stock_quantity'] != old_stock:
            publish_event('product.stock_updated', {
                'product_id': product.id,
                'sku': product.sku,
                'old_stock': old_stock,
                'new_stock': product.stock_quantity,
                'stock_change': product.stock_quantity - old_stock
            })
        
        # 发布商品更新事件
        publish_event('product.updated', {
            'product_id': product.id,
            'sku': product.sku,
            'updated_fields': list(data.keys())
        })
        
        logger.info(f"Product updated: {product.name} ({product.sku})")
        
        return jsonify({
            'message': 'Product updated successfully',
            'product': product.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Product update failed: {e}")
        return jsonify({'error': 'Product update failed'}), 500

@app.route('/api/v1/products/<int:product_id>/stock', methods=['POST'])
def update_stock(product_id):
    """更新商品库存"""
    try:
        data = request.json
        quantity_change = data.get('quantity_change', 0)
        operation = data.get('operation', 'adjust')  # adjust, reserve, release
        
        if not isinstance(quantity_change, int):
            return jsonify({'error': 'quantity_change must be an integer'}), 400
        
        product = Product.query.get(product_id)
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        old_stock = product.stock_quantity
        
        if operation == 'adjust':
            # 直接调整库存
            product.stock_quantity = max(0, old_stock + quantity_change)
        elif operation == 'reserve':
            # 预留库存（减少可用库存）
            if old_stock < abs(quantity_change):
                return jsonify({'error': 'Insufficient stock'}), 400
            product.stock_quantity = old_stock - abs(quantity_change)
        elif operation == 'release':
            # 释放库存（增加可用库存）
            product.stock_quantity = old_stock + abs(quantity_change)
        else:
            return jsonify({'error': 'Invalid operation'}), 400
        
        product.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        # 清除商品缓存
        cache_key = f"product:{product_id}"
        redis_client.delete(cache_key)
        
        # 发布库存更新事件
        publish_event('product.stock_updated', {
            'product_id': product.id,
            'sku': product.sku,
            'operation': operation,
            'old_stock': old_stock,
            'new_stock': product.stock_quantity,
            'quantity_change': quantity_change
        })
        
        logger.info(f"Stock updated for {product.sku}: {old_stock} -> {product.stock_quantity}")
        
        return jsonify({
            'message': 'Stock updated successfully',
            'old_stock': old_stock,
            'new_stock': product.stock_quantity,
            'product': product.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Stock update failed: {e}")
        return jsonify({'error': 'Stock update failed'}), 500

@app.route('/api/v1/products/search', methods=['GET'])
def search_products():
    """商品搜索"""
    try:
        query_text = request.args.get('q', '').strip()
        category_id = request.args.get('category_id', type=int)
        min_price = request.args.get('min_price', type=float)
        max_price = request.args.get('max_price', type=float)
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 20, type=int), 100)
        
        if not query_text and not category_id:
            return jsonify({'error': 'Search query or category is required'}), 400
        
        # 构建查询
        query = Product.query.filter(Product.is_active == True)
        
        if query_text:
            query = query.filter(
                db.or_(
                    Product.name.ilike(f'%{query_text}%'),
                    Product.description.ilike(f'%{query_text}%'),
                    Product.sku.ilike(f'%{query_text}%')
                )
            )
        
        if category_id:
            query = query.filter(Product.category_id == category_id)
        
        if min_price is not None:
            query = query.filter(Product.price >= min_price)
        
        if max_price is not None:
            query = query.filter(Product.price <= max_price)
        
        # 分页查询
        products_pagination = query.order_by(Product.name).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        products_data = [product.to_dict() for product in products_pagination.items]
        
        return jsonify({
            'products': products_data,
            'search_query': query_text,
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': products_pagination.total,
                'pages': products_pagination.pages,
                'has_next': products_pagination.has_next,
                'has_prev': products_pagination.has_prev
            }
        })
        
    except Exception as e:
        logger.error(f"Product search failed: {e}")
        return jsonify({'error': 'Product search failed'}), 500

@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """获取商品服务统计信息"""
    try:
        total_products = Product.query.count()
        active_products = Product.query.filter_by(is_active=True).count()
        total_categories = Category.query.count()
        low_stock_products = Product.query.filter(Product.stock_quantity < 10).count()
        
        return jsonify({
            'total_products': total_products,
            'active_products': active_products,
            'inactive_products': total_products - active_products,
            'total_categories': total_categories,
            'low_stock_products': low_stock_products
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
        
        # 创建默认分类
        if Category.query.count() == 0:
            default_categories = [
                {'name': '电子产品', 'description': '手机、电脑、数码产品等'},
                {'name': '服装鞋帽', 'description': '男装、女装、童装、鞋类等'},
                {'name': '家居用品', 'description': '家具、装饰、日用品等'},
                {'name': '图书音像', 'description': '图书、音乐、影视等'},
                {'name': '运动户外', 'description': '运动器材、户外用品等'}
            ]
            
            for cat_data in default_categories:
                category = Category(**cat_data)
                db.session.add(category)
            
            db.session.commit()
            logger.info("Default categories created")
        
        # 创建示例商品
        if Product.query.count() == 0:
            electronics_cat = Category.query.filter_by(name='电子产品').first()
            if electronics_cat:
                sample_products = [
                    {
                        'name': 'iPhone 15 Pro',
                        'description': '苹果最新旗舰手机，A17 Pro芯片，钛金属机身',
                        'price': Decimal('7999.00'),
                        'stock_quantity': 50,
                        'sku': 'APPLE-IPHONE15PRO-128GB',
                        'category_id': electronics_cat.id,
                        'weight': Decimal('0.187')
                    },
                    {
                        'name': 'MacBook Air M2',
                        'description': '轻薄笔记本电脑，M2芯片，13.6英寸Liquid Retina显示屏',
                        'price': Decimal('8999.00'),
                        'stock_quantity': 30,
                        'sku': 'APPLE-MACBOOK-AIR-M2-256GB',
                        'category_id': electronics_cat.id,
                        'weight': Decimal('1.24')
                    }
                ]
                
                for prod_data in sample_products:
                    product = Product(**prod_data)
                    db.session.add(product)
                
                db.session.commit()
                logger.info("Sample products created")
    
    app.run(host='0.0.0.0', port=5002, debug=os.getenv('FLASK_ENV') == 'development')