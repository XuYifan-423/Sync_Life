# N8N 数据库用户信息

## 基本信息
- **用户名**: n8n_reader
- **密码**: n8n_reader_password
- **数据库**: postgres
- **主机**: 127.0.0.1
- **端口**: 54322

## 权限设置
- **连接权限**: 允许连接到postgres数据库
- **Schema权限**: 允许使用public schema
- **表权限**:
  - `users`表: 只读权限 (SELECT)
  - `n8n_chat_histories`表: 读写权限 (INSERT, SELECT)

## 创建命令
```sql
-- 创建只读用户
CREATE USER n8n_reader WITH PASSWORD 'n8n_reader_password';

-- 授予连接数据库的权限
GRANT CONNECT ON DATABASE postgres TO n8n_reader;

-- 授予使用public schema的权限
GRANT USAGE ON SCHEMA public TO n8n_reader;

-- 授予对users表的只读权限
GRANT SELECT ON users TO n8n_reader;

-- 授予对n8n_chat_histories表的读写权限
GRANT INSERT, SELECT ON n8n_chat_histories TO n8n_reader;
```

## 使用场景
- **N8N工作流**: 用于查询用户信息和存储聊天历史
- **权限限制**: 只能读取用户信息，不能修改，确保数据安全
- **聊天历史**: 可以写入和读取聊天历史记录

## 安全注意事项
- 定期更新密码
- 限制用户权限，只授予必要的权限
- 不要将密码提交到版本控制系统
- 定期检查用户活动，确保没有异常操作
