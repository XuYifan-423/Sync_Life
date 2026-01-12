import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'pages/body_movement_page.dart';
import 'pages/smart_agent_page.dart';
import 'pages/three_d_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const MainScreen(),
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

  final List<Widget> _pages = [
    const BodyMovementPage(),
    const SmartAgentPage(),
    const ThreeDPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
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