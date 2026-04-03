import psycopg

try:
    # 尝试使用n8n_reader用户连接数据库
    conn = psycopg.connect(
        host='127.0.0.1',
        port=54322,
        dbname='postgres',
        user='n8n_reader',
        password='n8n_reader_password'
    )
    print("n8n_reader用户连接成功！")
    
    # 查询数据库中的所有表
    cursor = conn.cursor()
    cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
    tables = cursor.fetchall()
    print("数据库中的表:")
    for table in tables:
        print(f"- {table[0]}")
    
    # 测试查询用户信息（使用正确的表名）
    try:
        cursor.execute("SELECT id, age, weight, height, identity, ills FROM posture_user LIMIT 1")
        user = cursor.fetchone()
        if user:
            print(f"查询到用户信息: ID={user[0]}, 年龄={user[1]}, 体重={user[2]}, 身高={user[3]}, 身份={user[4]}, 健康状况={user[5]}")
        else:
            print("未查询到用户信息")
    except Exception as e:
        print(f"查询用户信息失败: {e}")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"连接失败: {e}")
