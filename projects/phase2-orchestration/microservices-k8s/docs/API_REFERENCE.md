# 微服务API参考文档

## 📋 概述

本文档详细描述了电商微服务平台的所有API端点。所有API都通过API网关统一访问，支持RESTful风格的HTTP请求。

## 🌐 基础信息

### API基础URL
- **开发环境**: `http://localhost:8080`
- **Minikube**: `http://<minikube-ip>:30080`
- **生产环境**: `https://ecommerce.yourdomain.com`

### 通用响应格式

#### 成功响应
```json
{
  "success": true,
  "data": {},
  "message": "操作成功",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 错误响应
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "错误描述",
    "details": {}
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### 认证方式

使用JWT Bearer Token进行认证：
```http
Authorization: Bearer <jwt_token>
```

### 状态码说明

| 状态码 | 说明 |
|--------|------|
| 200 | 请求成功 |
| 201 | 创建成功 |
| 400 | 请求参数错误 |
| 401 | 未认证 |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 409 | 资源冲突 |
| 500 | 服务器内部错误 |

## 👤 用户服务 API

### 用户注册

**POST** `/api/v1/register`

注册新用户账户。

#### 请求参数
```json
{
  "email": "user@example.com",
  "password": "password123",
  "name": "用户姓名",
  "phone": "13800138000"
}
```

#### 响应示例
```json
{
  "success": true,
  "data": {
    "user_id": 123,
    "email": "user@example.com",
    "name": "用户姓名",
    "created_at": "2024-01-01T12:00:00Z"
  },
  "message": "注册成功"
}
```

### 用户登录

**POST** `/api/v1/login`

用户登录获取访问令牌。

#### 请求参数
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

#### 响应示例
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 86400,
    "user": {
      "user_id": 123,
      "email": "user@example.com",
      "name": "用户姓名"
    }
  },
  "message": "登录成功"
}
```

### 获取用户信息

**GET** `/api/v1/profile`

获取当前用户的详细信息。

#### 请求头
```http
Authorization: Bearer <jwt_token>
```

#### 响应示例
```json
{
  "success": true,
  "data": {
    "user_id": 123,
    "email": "user@example.com",
    "name": "用户姓名",
    "phone": "13800138000",
    "avatar": "https://example.com/avatar.jpg",
    "created_at": "2024-01-01T12:00:00Z",
    "updated_at": "2024-01-01T12:00:00Z"
  }
}
```

### 更新用户信息

**PUT** `/api/v1/profile`

更新当前用户的信息。

#### 请求参数
```json
{
  "name": "新用户姓名",
  "phone": "13900139000",
  "avatar": "https://example.com/new-avatar.jpg"
}
```

### 用户登出

**POST** `/api/v1/logout`

用户登出，使当前令牌失效。

#### 请求头
```http
Authorization: Bearer <jwt_token>
```

## 📦 商品服务 API

### 获取商品列表

**GET** `/api/v1/products`

获取商品列表，支持分页和筛选。

#### 查询参数
| 参数 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| page | int | 页码 | 1 |
| limit | int | 每页数量 | 20 |
| category_id | int | 分类ID | - |
| keyword | string | 搜索关键词 | - |
| min_price | float | 最低价格 | - |
| max_price | float | 最高价格 | - |
| sort | string | 排序方式 | created_at |

#### 响应示例
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "product_id": 1,
        "name": "商品名称",
        "description": "商品描述",
        "price": 99.99,
        "category_id": 1,
        "category_name": "分类名称",
        "stock": 100,
        "images": ["https://example.com/image1.jpg"],
        "created_at": "2024-01-01T12:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 100,
      "pages": 5
    }
  }
}
```

### 获取商品详情

**GET** `/api/v1/products/{product_id}`

获取指定商品的详细信息。

#### 路径参数
- `product_id`: 商品ID

#### 响应示例
```json
{
  "success": true,
  "data": {
    "product_id": 1,
    "name": "商品名称",
    "description": "详细商品描述",
    "price": 99.99,
    "category_id": 1,
    "category_name": "分类名称",
    "stock": 100,
    "images": [
      "https://example.com/image1.jpg",
      "https://example.com/image2.jpg"
    ],
    "attributes": {
      "color": "红色",
      "size": "L",
      "weight": "1kg"
    },
    "created_at": "2024-01-01T12:00:00Z",
    "updated_at": "2024-01-01T12:00:00Z"
  }
}
```

### 商品搜索

**GET** `/api/v1/products/search`

搜索商品。

#### 查询参数
| 参数 | 类型 | 说明 | 必填 |
|------|------|------|------|
| q | string | 搜索关键词 | 是 |
| page | int | 页码 | 否 |
| limit | int | 每页数量 | 否 |

### 获取分类列表

**GET** `/api/v1/categories`

获取所有商品分类。

#### 响应示例
```json
{
  "success": true,
  "data": [
    {
      "category_id": 1,
      "name": "电子产品",
      "description": "各类电子设备",
      "parent_id": null,
      "children": [
        {
          "category_id": 2,
          "name": "手机",
          "parent_id": 1
        }
      ]
    }
  ]
}
```

### 创建商品（管理员）

**POST** `/api/v1/products`

创建新商品（需要管理员权限）。

#### 请求参数
```json
{
  "name": "商品名称",
  "description": "商品描述",
  "price": 99.99,
  "category_id": 1,
  "stock": 100,
  "images": ["https://example.com/image1.jpg"],
  "attributes": {
    "color": "红色",
    "size": "L"
  }
}
```

## 📋 订单服务 API

### 创建订单

**POST** `/api/v1/orders`

创建新订单。

#### 请求参数
```json
{
  "items": [
    {
      "product_id": 1,
      "quantity": 2,
      "price": 99.99
    }
  ],
  "shipping_address": {
    "name": "收货人姓名",
    "phone": "13800138000",
    "address": "详细地址",
    "city": "城市",
    "province": "省份",
    "postal_code": "100000"
  },
  "payment_method": "alipay",
  "notes": "订单备注"
}
```

#### 响应示例
```json
{
  "success": true,
  "data": {
    "order_id": "ORD20240101001",
    "user_id": 123,
    "status": "pending",
    "total_amount": 199.98,
    "items": [
      {
        "product_id": 1,
        "product_name": "商品名称",
        "quantity": 2,
        "price": 99.99,
        "subtotal": 199.98
      }
    ],
    "shipping_address": {
      "name": "收货人姓名",
      "phone": "13800138000",
      "address": "详细地址"
    },
    "created_at": "2024-01-01T12:00:00Z"
  }
}
```

### 获取订单列表

**GET** `/api/v1/orders`

获取当前用户的订单列表。

#### 查询参数
| 参数 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| page | int | 页码 | 1 |
| limit | int | 每页数量 | 20 |
| status | string | 订单状态 | - |

#### 响应示例
```json
{
  "success": true,
  "data": {
    "orders": [
      {
        "order_id": "ORD20240101001",
        "status": "pending",
        "total_amount": 199.98,
        "item_count": 2,
        "created_at": "2024-01-01T12:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 10,
      "pages": 1
    }
  }
}
```

### 获取订单详情

**GET** `/api/v1/orders/{order_id}`

获取指定订单的详细信息。

### 支付订单

**POST** `/api/v1/orders/{order_id}/pay`

支付指定订单。

#### 请求参数
```json
{
  "payment_method": "alipay",
  "payment_info": {
    "return_url": "https://example.com/return",
    "notify_url": "https://example.com/notify"
  }
}
```

### 取消订单

**PUT** `/api/v1/orders/{order_id}/cancel`

取消指定订单。

#### 请求参数
```json
{
  "reason": "取消原因"
}
```

## 📬 通知服务 API

### 获取通知列表

**GET** `/api/v1/notifications`

获取当前用户的通知列表。

#### 查询参数
| 参数 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| page | int | 页码 | 1 |
| limit | int | 每页数量 | 20 |
| type | string | 通知类型 | - |
| read | boolean | 是否已读 | - |

#### 响应示例
```json
{
  "success": true,
  "data": {
    "notifications": [
      {
        "notification_id": 1,
        "type": "order_status",
        "title": "订单状态更新",
        "content": "您的订单已发货",
        "read": false,
        "created_at": "2024-01-01T12:00:00Z"
      }
    ],
    "unread_count": 5,
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 50,
      "pages": 3
    }
  }
}
```

### 标记通知已读

**PUT** `/api/v1/notifications/{notification_id}/read`

标记指定通知为已读。

### 发送通知（系统内部）

**POST** `/api/v1/notifications`

发送通知（仅限系统内部调用）。

#### 请求参数
```json
{
  "user_id": 123,
  "type": "order_status",
  "title": "通知标题",
  "content": "通知内容",
  "data": {
    "order_id": "ORD20240101001"
  }
}
```

### 获取通知模板

**GET** `/api/v1/templates`

获取通知模板列表（管理员）。

### 创建通知模板

**POST** `/api/v1/templates`

创建新的通知模板（管理员）。

## 🏥 健康检查 API

### API网关健康检查

**GET** `/health`

检查API网关状态。

#### 响应示例
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00Z",
  "version": "1.0.0",
  "services": {
    "user-service": "healthy",
    "product-service": "healthy",
    "order-service": "healthy",
    "notification-service": "healthy"
  }
}
```

### 服务健康检查

**GET** `/health/{service}`

检查特定服务状态。

- `/health/user` - 用户服务
- `/health/product` - 商品服务
- `/health/order` - 订单服务
- `/health/notification` - 通知服务

## 📊 统计 API

### 用户统计

**GET** `/stats/user`

获取用户相关统计信息。

### 商品统计

**GET** `/stats/product`

获取商品相关统计信息。

### 订单统计

**GET** `/stats/order`

获取订单相关统计信息。

## 🔧 错误代码参考

| 错误代码 | 说明 |
|----------|------|
| AUTH_001 | 无效的认证令牌 |
| AUTH_002 | 令牌已过期 |
| AUTH_003 | 权限不足 |
| USER_001 | 用户不存在 |
| USER_002 | 邮箱已被注册 |
| USER_003 | 密码错误 |
| PRODUCT_001 | 商品不存在 |
| PRODUCT_002 | 库存不足 |
| ORDER_001 | 订单不存在 |
| ORDER_002 | 订单状态不允许此操作 |
| PAYMENT_001 | 支付失败 |
| SYSTEM_001 | 系统内部错误 |

## 📝 使用示例

### JavaScript/Fetch
```javascript
// 用户登录
const response = await fetch('/api/v1/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'password123'
  })
});

const data = await response.json();
const token = data.data.token;

// 获取用户信息
const userResponse = await fetch('/api/v1/profile', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

### cURL
```bash
# 用户登录
curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# 获取商品列表
curl -X GET "http://localhost:8080/api/v1/products?page=1&limit=10"

# 创建订单
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"items":[{"product_id":1,"quantity":2}]}'
```

---

## 📞 支持

如有API使用问题，请：
1. 查看错误代码参考
2. 检查请求格式和参数
3. 确认认证令牌有效性
4. 联系技术支持团队

**API版本**: v1.0  
**最后更新**: 2024-01-01
