-- 为n8n_reader用户授予posture_user表的SELECT权限
GRANT SELECT ON posture_user TO n8n_reader;

-- 为n8n_reader用户授予posture_posturerecord表的SELECT权限（如果需要）
GRANT SELECT ON posture_posturerecord TO n8n_reader;

-- 验证权限
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name = 'posture_user' AND grantee = 'n8n_reader';
