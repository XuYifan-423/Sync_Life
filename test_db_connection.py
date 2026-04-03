import psycopg2

try:
    # 尝试连接数据库
    conn = psycopg2.connect(
        host='127.0.0.1',
        port=54322,
        database='postgres',
        user='postgres',
        password='postgres'
    )
    print("数据库连接成功！")
    
    # 测试n8n_reader用户
    try:
        conn_n8n = psycopg2.connect(
            host='127.0.0.1',
            port=54322,
            database='postgres',
            user='n8n_reader',
            password='n8n_reader_password'
        )
        print("n8n_reader用户连接成功！")
        conn_n8n.close()
    except Exception as e:
        print(f"n8n_reader用户连接失败: {e}")
    
    conn.close()
except Exception as e:
    print(f"数据库连接失败: {e}")
