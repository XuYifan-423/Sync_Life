import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/body_movement_page.dart';
import 'pages/smart_agent_page.dart';
import 'pages/three_d_page.dart';
import 'pages/profile_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 检查登录状态的方法
  Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '身体运动状况',
      theme: ThemeData(
        primaryColor: const Color(0xFF4A90E2),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      home: FutureBuilder<bool>(
        future: checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 显示加载指示器
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasData && snapshot.data!) {
            // 已登录，直接进入主页
            return const MainScreen();
          } else {
            // 未登录，显示登录页面
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => const MainScreen(),
        '/three_d': (context) => const ThreeDPage(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _smartAgentInitialMessage;
  SmartAgentPage? _smartAgentPage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 接收路由参数，切换到指定选项卡
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final tabIndex = args['tabIndex'];
      if (tabIndex is int) {
        setState(() {
          _currentIndex = tabIndex;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根据当前索引返回对应的页面
    Widget currentPage;
    switch (_currentIndex) {
      case 0:
        currentPage = BodyMovementPage(
          onGenerateReport: (reportType) {
            // 切换到智能服务页面并传递初始消息
            setState(() {
              _smartAgentInitialMessage = '生成$reportType';
              _currentIndex = 1; // 智能服务页面的索引
            });
          },
        );
        break;
      case 1:
        // 只在需要时创建SmartAgentPage实例
        if (_smartAgentPage == null || _smartAgentInitialMessage != null) {
          _smartAgentPage = SmartAgentPage(initialMessage: _smartAgentInitialMessage);
          // 重置初始消息，避免重复发送
          _smartAgentInitialMessage = null;
        }
        currentPage = _smartAgentPage!;
        break;
      case 2:
        currentPage = const ThreeDPage();
        break;
      case 3:
        // 每次都创建新的ProfilePage实例，确保重新加载用户信息
        currentPage = ProfilePage();
        break;
      default:
        currentPage = BodyMovementPage(
          onGenerateReport: (reportType) {
            setState(() {
              _smartAgentInitialMessage = '生成$reportType';
              _currentIndex = 1;
            });
          },
        );
    }
    
    return Scaffold(
      body: currentPage,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: '智能服务',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '模型展示',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '个人中心',
          ),
        ],
        selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }
}