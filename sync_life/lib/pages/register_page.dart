import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _illsController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingCode = false;
  int _countdown = 0;
  String _errorMessage = '';

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
        _startCountdown();
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    final String email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _errorMessage = '请输入邮箱地址';
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendCodeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('验证码已发送到您的邮箱')),
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? '发送验证码失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络错误，请稍后重试';
      });
    } finally {
      setState(() {
        _isSendingCode = false;
      });
    }
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final String phone = _phoneController.text.trim();
    final String email = _emailController.text.trim();
    final String verificationCode = _verificationCodeController.text.trim();
    final String password = _passwordController.text.trim();
    final String ageStr = _ageController.text.trim();
    final String weightStr = _weightController.text.trim();
    final String heightStr = _heightController.text.trim();
    final String identity = _identityController.text.trim();
    final String ills = _illsController.text.trim();

    if (phone.isEmpty || email.isEmpty || verificationCode.isEmpty || password.isEmpty || ageStr.isEmpty || weightStr.isEmpty || heightStr.isEmpty) {
      setState(() {
        _errorMessage = '请填写所有必填字段';
        _isLoading = false;
      });
      return;
    }

    int age;
    double weight;
    double height;

    try {
      age = int.parse(ageStr);
      weight = double.parse(weightStr);
      height = double.parse(heightStr);
    } catch (e) {
      setState(() {
        _errorMessage = '请输入有效的年龄、体重和身高';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'email': email,
          'password': password,
          'verification_code': verificationCode,
          'age': age,
          'weight': weight,
          'height': height,
          'identity': identity,
          'ills': ills,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        // 注册成功，保存登录状态到本地存储
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userIdentifier', phone);
        
        // 跳转到主页
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        setState(() {
          _errorMessage = data['error'] ?? '注册失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络错误，请稍后重试';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '注册',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '手机号（必填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '邮箱（必填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _verificationCodeController,
                        decoration: const InputDecoration(
                          labelText: '验证码（必填）',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.code),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: (_isSendingCode || _countdown > 0) ? null : _sendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                        ),
                        child: _isSendingCode
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码（必填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: '年龄（必填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: '体重（kg，必填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.line_weight),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: '身高（cm，必填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.height),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _identityController,
                  decoration: const InputDecoration(
                    labelText: '身份（选填，如：学生、教师等）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _illsController,
                  decoration: const InputDecoration(
                    labelText: '疾病史（选填，无则不填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_hospital),
                  ),
                ),
                const SizedBox(height: 24),
                
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '注册',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text(
                    '已有账号？立即登录',
                    style: TextStyle(color: Color(0xFF4A90E2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}