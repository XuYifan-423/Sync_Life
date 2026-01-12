import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
      return Scaffold(
          appBar: AppBar(
            title: const Text('个人中心'),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: Stack(
          children: [
           Image(image: AssetImage('assets/background.png'), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
            ListView(
            padding: const EdgeInsets.all(16),
            children: [
              //设备及状态
               Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.wifi_tethering, color: Color(0xFF4A90E2)),
                  title: const Text('我的设备'),
                  subtitle: const Text('intelligent-001          已连接'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {},
                ),
              ),
              // 联系方式
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.phone, color: Color(0xFF4A90E2)),
                  title: const Text('联系方式'),
                  subtitle: const Text('13800138000'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {},
                ),
              ),
              // 退出登录
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('退出登录'),
                  textColor: Colors.red,
                  onTap: () {
                    // 退出登录逻辑
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('退出登录'),
                        content: const Text('确定要退出登录吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              // 执行退出登录操作
                              Navigator.pop(context);
                            },
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          ]
        ),
      );
  }
}