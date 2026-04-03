import psycopg

try:
    # 使用postgres用户连接数据库
    conn = psycopg.connect(
        host='127.0.0.1',
        port=54322,
        dbname='postgres',
        user='postgres',
        password='postgres'
    )
    
    cursor = conn.cursor()
    
    # 为n8n_reader用户授予posture_user表的SELECT权限
    cursor.execute("GRANT SELECT ON posture_user TO n8n_reader;")
    print("已授予n8n_reader用户posture_user表的SELECT权限")
    
    # 为n8n_reader用户授予posture_posturerecord表的SELECT权限（如果需要）
    cursor.execute("GRANT SELECT ON posture_posturerecord TO n8n_reader;")
    print("已授予n8n_reader用户posture_posturerecord表的SELECT权限")
    
    # 验证权限
    cursor.execute("SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE table_name = 'posture_user' AND grantee = 'n8n_reader';")
    permissions = cursor.fetchall()
    print("n8n_reader用户对posture_user表的权限:")
    for permission in permissions:
        print(f"- {permission[0]}: {permission[1]}")
    
    conn.commit()
    cursor.close()
    conn.close()
    print("权限授予成功！")
except Exception as e:
    print(f"执行失败: {e}")
