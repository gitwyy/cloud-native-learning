-- ==============================================================================
-- 电商应用基础版 - 数据库初始化脚本
-- 为各个微服务创建独立的数据库
-- ==============================================================================

-- 创建用户服务数据库
CREATE DATABASE IF NOT EXISTS ecommerce_users;
GRANT ALL PRIVILEGES ON DATABASE ecommerce_users TO postgres;

-- 创建商品服务数据库
CREATE DATABASE IF NOT EXISTS ecommerce_products;
GRANT ALL PRIVILEGES ON DATABASE ecommerce_products TO postgres;

-- 创建订单服务数据库
CREATE DATABASE IF NOT EXISTS ecommerce_orders;
GRANT ALL PRIVILEGES ON DATABASE ecommerce_orders TO postgres;

-- 创建通知服务数据库
CREATE DATABASE IF NOT EXISTS ecommerce_notifications;
GRANT ALL PRIVILEGES ON DATABASE ecommerce_notifications TO postgres;

-- 打印创建结果
\echo '数据库初始化完成'
\echo '- ecommerce_users: 用户服务数据库'
\echo '- ecommerce_products: 商品服务数据库'
\echo '- ecommerce_orders: 订单服务数据库'
\echo '- ecommerce_notifications: 通知服务数据库'