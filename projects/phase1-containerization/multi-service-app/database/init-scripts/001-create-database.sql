-- ==============================================================================
-- 数据库初始化脚本
-- 创建Todo List Plus数据库和基本配置
-- ==============================================================================

-- 创建数据库（如果不存在）
SELECT 'CREATE DATABASE todo_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'todo_db')\gexec

-- 连接到数据库
\c todo_db;

-- 创建扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- 设置时区
SET timezone = 'Asia/Shanghai';

-- 创建自定义函数：更新时间戳
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建自定义函数：生成短ID
CREATE OR REPLACE FUNCTION generate_short_id(length INTEGER DEFAULT 8)
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    result TEXT := '';
    i INTEGER := 0;
BEGIN
    FOR i IN 1..length LOOP
        result := result || substr(chars, floor(random() * length(chars))::int + 1, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 创建自定义函数：搜索权重计算
CREATE OR REPLACE FUNCTION calculate_search_weight(
    title TEXT,
    description TEXT,
    search_term TEXT
) RETURNS FLOAT AS $$
DECLARE
    weight FLOAT := 0;
BEGIN
    -- 标题匹配权重更高
    IF title ILIKE '%' || search_term || '%' THEN
        weight := weight + 2.0;
    END IF;
    
    -- 描述匹配权重较低
    IF description ILIKE '%' || search_term || '%' THEN
        weight := weight + 1.0;
    END IF;
    
    -- 使用pg_trgm计算相似度
    weight := weight + similarity(title || ' ' || COALESCE(description, ''), search_term);
    
    RETURN weight;
END;
$$ LANGUAGE plpgsql;

-- 创建枚举类型
DO $$ 
BEGIN
    -- 任务状态枚举
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status') THEN
        CREATE TYPE task_status AS ENUM (
            'pending',
            'in_progress', 
            'completed',
            'cancelled',
            'archived'
        );
    END IF;
    
    -- 任务优先级枚举
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_priority') THEN
        CREATE TYPE task_priority AS ENUM (
            'low',
            'medium',
            'high', 
            'urgent'
        );
    END IF;
    
    -- 通知类型枚举
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
        CREATE TYPE notification_type AS ENUM (
            'task_created',
            'task_updated',
            'task_completed',
            'task_overdue',
            'task_due_soon',
            'task_assigned',
            'task_commented',
            'system_maintenance',
            'system_update',
            'security_alert',
            'welcome',
            'reminder'
        );
    END IF;
    
    -- 通知优先级枚举
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_priority') THEN
        CREATE TYPE notification_priority AS ENUM (
            'low',
            'medium',
            'high',
            'urgent'
        );
    END IF;
    
    -- 通知状态枚举
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_status') THEN
        CREATE TYPE notification_status AS ENUM (
            'pending',
            'sent',
            'delivered',
            'read',
            'failed',
            'cancelled'
        );
    END IF;
END $$;

-- 创建序列
CREATE SEQUENCE IF NOT EXISTS user_id_seq START 1000;
CREATE SEQUENCE IF NOT EXISTS task_id_seq START 1000;
CREATE SEQUENCE IF NOT EXISTS notification_id_seq START 1000;

-- 设置数据库参数
ALTER DATABASE todo_db SET timezone TO 'Asia/Shanghai';
ALTER DATABASE todo_db SET log_statement TO 'mod';
ALTER DATABASE todo_db SET log_min_duration_statement TO 1000;

-- 创建角色和权限
DO $$
BEGIN
    -- 创建只读角色
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'todo_readonly') THEN
        CREATE ROLE todo_readonly;
        GRANT CONNECT ON DATABASE todo_db TO todo_readonly;
        GRANT USAGE ON SCHEMA public TO todo_readonly;
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO todo_readonly;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO todo_readonly;
    END IF;
    
    -- 创建应用角色
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'todo_app') THEN
        CREATE ROLE todo_app;
        GRANT CONNECT ON DATABASE todo_db TO todo_app;
        GRANT USAGE, CREATE ON SCHEMA public TO todo_app;
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO todo_app;
        GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO todo_app;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO todo_app;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO todo_app;
    END IF;
END $$;

-- 创建索引（在表创建后会通过迁移添加）
-- 这里预定义一些常用的索引创建语句，供参考

/*
-- 用户表索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_is_active ON users(is_active);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_created_at ON users(created_at);

-- 任务表索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_owner_id ON tasks(owner_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_category ON tasks(category);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_is_archived ON tasks(is_archived);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_is_deleted ON tasks(is_deleted);

-- 复合索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_owner_status ON tasks(owner_id, status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_owner_due_date ON tasks(owner_id, due_date);

-- 全文搜索索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_search ON tasks USING gin(to_tsvector('simple', title || ' ' || COALESCE(description, '')));

-- 通知表索引
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_type ON notifications(notification_type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_status ON notifications(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
*/

-- 创建视图
CREATE OR REPLACE VIEW user_task_stats AS
SELECT 
    u.id as user_id,
    u.username,
    COUNT(t.id) as total_tasks,
    COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed_tasks,
    COUNT(CASE WHEN t.status = 'pending' THEN 1 END) as pending_tasks,
    COUNT(CASE WHEN t.status = 'in_progress' THEN 1 END) as in_progress_tasks,
    COUNT(CASE WHEN t.due_date < CURRENT_TIMESTAMP AND t.status NOT IN ('completed', 'cancelled') THEN 1 END) as overdue_tasks,
    ROUND(
        CASE 
            WHEN COUNT(t.id) > 0 THEN 
                COUNT(CASE WHEN t.status = 'completed' THEN 1 END)::DECIMAL / COUNT(t.id) * 100 
            ELSE 0 
        END, 2
    ) as completion_rate
FROM users u
LEFT JOIN tasks t ON u.id = t.owner_id AND t.is_deleted = false
WHERE u.is_active = true
GROUP BY u.id, u.username;

-- 创建任务概览视图
CREATE OR REPLACE VIEW task_overview AS
SELECT 
    t.*,
    u.username as owner_name,
    u.avatar_url as owner_avatar,
    CASE 
        WHEN t.due_date < CURRENT_TIMESTAMP AND t.status NOT IN ('completed', 'cancelled', 'archived') 
        THEN true 
        ELSE false 
    END as is_overdue,
    CASE 
        WHEN t.due_date BETWEEN CURRENT_TIMESTAMP AND CURRENT_TIMESTAMP + INTERVAL '24 hours' 
            AND t.status NOT IN ('completed', 'cancelled', 'archived')
        THEN true 
        ELSE false 
    END as is_due_soon
FROM tasks t
JOIN users u ON t.owner_id = u.id
WHERE t.is_deleted = false;

-- 打印初始化完成信息
DO $$
BEGIN
    RAISE NOTICE '=== Todo List Plus Database Initialized ===';
    RAISE NOTICE 'Database: todo_db';
    RAISE NOTICE 'Extensions: uuid-ossp, pg_trgm, btree_gin, unaccent';
    RAISE NOTICE 'Custom Functions: update_updated_at_column, generate_short_id, calculate_search_weight';
    RAISE NOTICE 'Enums: task_status, task_priority, notification_type, notification_priority, notification_status';
    RAISE NOTICE 'Views: user_task_stats, task_overview';
    RAISE NOTICE 'Roles: todo_readonly, todo_app';
    RAISE NOTICE '=== Initialization Complete ===';
END $$;