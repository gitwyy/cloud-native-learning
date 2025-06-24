"""
用户相关的Pydantic模式
用于API请求和响应数据验证
"""

from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional, List
from datetime import datetime


class UserBase(BaseModel):
    """用户基础模式"""
    username: str = Field(..., min_length=3, max_length=50, description="用户名")
    email: EmailStr = Field(..., description="邮箱地址")
    full_name: Optional[str] = Field(None, max_length=100, description="真实姓名")
    bio: Optional[str] = Field(None, max_length=500, description="个人简介")
    timezone: str = Field("Asia/Shanghai", description="时区")
    language: str = Field("zh-CN", description="语言")
    theme: str = Field("light", description="主题")


class UserCreate(UserBase):
    """创建用户模式"""
    password: str = Field(..., min_length=8, max_length=128, description="密码")
    
    @validator('password')
    def validate_password(cls, v):
        """验证密码强度"""
        if len(v) < 8:
            raise ValueError('密码长度至少8位')
        
        has_upper = any(c.isupper() for c in v)
        has_lower = any(c.islower() for c in v)
        has_digit = any(c.isdigit() for c in v)
        
        if not (has_upper and has_lower and has_digit):
            raise ValueError('密码必须包含大写字母、小写字母和数字')
        
        return v
    
    @validator('username')
    def validate_username(cls, v):
        """验证用户名"""
        if not v.isalnum() and '_' not in v and '-' not in v:
            raise ValueError('用户名只能包含字母、数字、下划线和连字符')
        return v


class UserUpdate(BaseModel):
    """更新用户模式"""
    full_name: Optional[str] = Field(None, max_length=100)
    bio: Optional[str] = Field(None, max_length=500)
    avatar_url: Optional[str] = Field(None, max_length=255)
    timezone: Optional[str] = None
    language: Optional[str] = None
    theme: Optional[str] = None
    email_notifications: Optional[bool] = None
    push_notifications: Optional[bool] = None


class UserResponse(BaseModel):
    """用户响应模式"""
    id: int
    username: str
    email: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    is_active: bool
    is_verified: bool
    last_login: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    timezone: str
    language: str
    theme: str
    email_notifications: bool
    push_notifications: bool
    
    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat() if v else None
        }


class UserLogin(BaseModel):
    """用户登录模式"""
    username: str = Field(..., description="用户名或邮箱")
    password: str = Field(..., description="密码")
    remember_me: bool = Field(False, description="记住我")


class TokenResponse(BaseModel):
    """令牌响应模式"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


class PasswordChange(BaseModel):
    """修改密码模式"""
    current_password: str = Field(..., description="当前密码")
    new_password: str = Field(..., min_length=8, max_length=128, description="新密码")
    
    @validator('new_password')
    def validate_new_password(cls, v):
        """验证新密码强度"""
        if len(v) < 8:
            raise ValueError('密码长度至少8位')
        
        has_upper = any(c.isupper() for c in v)
        has_lower = any(c.islower() for c in v)
        has_digit = any(c.isdigit() for c in v)
        
        if not (has_upper and has_lower and has_digit):
            raise ValueError('密码必须包含大写字母、小写字母和数字')
        
        return v


class UserProfile(BaseModel):
    """用户资料模式"""
    username: str
    email: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    timezone: str
    language: str
    theme: str
    created_at: datetime
    last_login: Optional[datetime] = None
    
    # 统计信息
    total_tasks: int = 0
    completed_tasks: int = 0
    pending_tasks: int = 0
    
    class Config:
        from_attributes = True


class UserSettings(BaseModel):
    """用户设置模式"""
    email_notifications: bool = True
    push_notifications: bool = True
    timezone: str = "Asia/Shanghai"
    language: str = "zh-CN"
    theme: str = "light"
    
    # 隐私设置
    profile_public: bool = True
    show_email: bool = False
    show_last_login: bool = False
    
    # 安全设置
    two_factor_enabled: bool = False
    login_notifications: bool = True
    
    class Config:
        from_attributes = True


class UserList(BaseModel):
    """用户列表模式"""
    users: List[UserResponse]
    total: int
    page: int
    size: int
    pages: int


class UserSearch(BaseModel):
    """用户搜索模式"""
    query: Optional[str] = Field(None, min_length=1, max_length=100, description="搜索关键词")
    is_active: Optional[bool] = Field(None, description="是否激活")
    is_verified: Optional[bool] = Field(None, description="是否已验证")
    created_after: Optional[datetime] = Field(None, description="创建时间起始")
    created_before: Optional[datetime] = Field(None, description="创建时间结束")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat() if v else None
        }


class UserStats(BaseModel):
    """用户统计模式"""
    user_id: int
    total_tasks: int
    completed_tasks: int
    pending_tasks: int
    in_progress_tasks: int
    overdue_tasks: int
    
    # 时间统计
    tasks_this_week: int
    tasks_this_month: int
    completed_this_week: int
    completed_this_month: int
    
    # 完成率
    completion_rate: float
    on_time_rate: float
    
    class Config:
        from_attributes = True


class EmailVerification(BaseModel):
    """邮箱验证模式"""
    email: EmailStr
    verification_code: str = Field(..., min_length=6, max_length=6)


class PasswordReset(BaseModel):
    """密码重置模式"""
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    """确认密码重置模式"""
    reset_token: str
    new_password: str = Field(..., min_length=8, max_length=128)
    
    @validator('new_password')
    def validate_new_password(cls, v):
        """验证新密码强度"""
        if len(v) < 8:
            raise ValueError('密码长度至少8位')
        
        has_upper = any(c.isupper() for c in v)
        has_lower = any(c.islower() for c in v)
        has_digit = any(c.isdigit() for c in v)
        
        if not (has_upper and has_lower and has_digit):
            raise ValueError('密码必须包含大写字母、小写字母和数字')
        
        return v


class UserActivity(BaseModel):
    """用户活动模式"""
    id: int
    activity_type: str
    description: str
    resource_type: Optional[str] = None
    resource_id: Optional[int] = None
    created_at: datetime
    metadata: Optional[dict] = None
    
    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat() if v else None
        }


class UserSession(BaseModel):
    """用户会话模式"""
    id: int
    session_id: str
    device_type: Optional[str] = None
    device_name: Optional[str] = None
    browser: Optional[str] = None
    ip_address: Optional[str] = None
    created_at: datetime
    last_activity: datetime
    expires_at: datetime
    is_active: bool
    
    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat() if v else None
        }