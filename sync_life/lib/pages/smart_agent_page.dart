import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';
import '../utils/training_plan_storage.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool hasCalendarOption;
  final bool isLoading; // 添加加载状态

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.hasCalendarOption = false,
    this.isLoading = false,
  });

  // 转换为Map以便存储
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'hasCalendarOption': hasCalendarOption,
    };
  }

  // 从Map创建Message
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      text: map['text'],
      isUser: map['isUser'],
      timestamp: DateTime.parse(map['timestamp']),
      hasCalendarOption: map['hasCalendarOption'] ?? false,
    );
  }
}

class SmartAgentPage extends StatefulWidget {
  final String? initialMessage;

  const SmartAgentPage({super.key, this.initialMessage});

  @override
  State<SmartAgentPage> createState() => _SmartAgentPageState();
}

class _SmartAgentPageState extends State<SmartAgentPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _showMessages = false; // 控制消息列表的显示
  int? _userId;
  String _sessionId = DateTime.now().toString();

  @override
  void initState() {
    super.initState();
    
    // 获取用户ID
    _getUserId();
    // 加载消息记录
    _loadMessages();
    
    // 如果有初始消息，自动发送
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      // 延迟一下，确保欢迎消息已显示
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _textController.text = widget.initialMessage!;
          _sendMessage();
        }
      });
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当依赖变化时（如从其他页面切换回来），滚动到底部
    // 直接调用，不使用延迟，避免闪烁
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        // 滚动到最新消息（底部）
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }
  
  // 获取用户ID
  Future<void> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId != null && mounted) {
        setState(() {
          _userId = userId;
        });
      }
    } catch (e) {
      print('获取用户ID失败: $e');
    }
  }
  


  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;

    String messageText = _textController.text.trim();
    setState(() {
      _messages.add(Message(
        text: messageText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      // 添加一个加载中的消息
      _messages.add(Message(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
      _textController.clear();
    });

    // 保存消息
    _saveMessages();
    
    // 滚动到底部
    _scrollToBottom();

    // 调用后端API处理消息
    print('发送消息到后端: $messageText');
    print('用户ID: $_userId');
    print('会话ID: $_sessionId');
    
    // 调用N8N处理消息
    _processMessageWithN8N(messageText);
  }
  
  // 检测消息是否包含特定关键词
  bool _containsKeyTopics(String message) {
    final keyTopics = [
      '训练计划',
      '健康餐馆',
      '健康建议',
      '姿势纠正',
      '姿态',
      '健康'
    ];
    
    for (final topic in keyTopics) {
      if (message.contains(topic)) {
        return true;
      }
    }
    return false;
  }

  // 调用后端API处理消息
  Future<void> _processMessageWithN8N(String messageText) async {
    if (_userId == null) {
      if (mounted) {
        setState(() {
          _messages.add(Message(
            text: '请先登录后再使用智能服务',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
      _saveMessages();
      _scrollToBottom();
      return;
    }
    
    try {
      // 获取用户信息
      final userInfo = await _getUserInfo();
      
      // 检测消息是否包含关键词，如果包含则获取姿态数据
      Map<String, dynamic>? postureData;
      String detailedMessage = messageText;
      
      if (_containsKeyTopics(messageText)) {
        postureData = await _getPostureDistribution();
        print('检测到关键词，获取姿态数据: $postureData');
        
        // 如果有姿态数据，添加到消息中
        if (postureData != null) {
          detailedMessage += '\n\n近一个月姿态占比：\n';
          if (postureData['posture_distribution'] != null) {
            for (var item in postureData['posture_distribution']) {
              detailedMessage += '- ${item['name']}：${item['value']}% (${item['hours']})\n';
            }
          }
          detailedMessage += '\n活动数据：\n';
          detailedMessage += '- 步数：${postureData['steps'] ?? 0}\n';
          detailedMessage += '- 卡路里：${postureData['calories'] ?? 0}\n';
          detailedMessage += '- 距离：${postureData['distance'] ?? 0}km\n';
          detailedMessage += '- 活动时间：${postureData['active_time'] ?? 0}min\n';
          
          // 添加活动趋势数据
          if (postureData['activity_trend'] != null) {
            detailedMessage += '\n每周活动趋势：\n';
            for (var item in postureData['activity_trend']) {
              detailedMessage += '- ${item['label']}：${item['steps']}步\n';
            }
          }
          
          // 添加姿态详细数据
          if (postureData['postures'] != null) {
            detailedMessage += '\n姿态详细数据：\n';
            for (var item in postureData['postures']) {
              detailedMessage += '- ${item['date'] ?? item['label']}：\n';
              if (item['sitting'] != null) detailedMessage += '  坐姿：${item['sitting']}小时\n';
              if (item['standing'] != null) detailedMessage += '  站姿：${item['standing']}小时\n';
              if (item['walking'] != null) detailedMessage += '  行走：${item['walking']}小时\n';
              if (item['running'] != null) detailedMessage += '  跑步：${item['running']}小时\n';
              if (item['lying'] != null) detailedMessage += '  躺姿：${item['lying']}小时\n';
            }
          }
          
          // 添加姿态角度数据
          if (postureData['posture_angles'] != null) {
            detailedMessage += '\n姿态角度数据：\n';
            // 添加年龄组定义
            detailedMessage += '年龄组定义：\n';
            detailedMessage += '- 青年组：11-24岁\n';
            detailedMessage += '- 壮年组：25-44岁\n';
            detailedMessage += '- 中年组：45-59岁\n';
            detailedMessage += '- 老年组：60岁及以上\n\n';
            // 添加角度范围定义
            detailedMessage += '角度范围定义：\n';
            detailedMessage += '- 正常：标准范围内的角度\n';
            detailedMessage += '- 轻微异常：偏离标准范围中点的偏差≤10度（老年组≤12度）\n';
            detailedMessage += '- 严重异常：偏离标准范围中点的偏差>10度（老年组>12度）\n\n';
            for (var item in postureData['posture_angles']) {
              detailedMessage += '- ${item['time'] ?? item['date'] ?? item['week'] ?? item['label']}：\n';
              if (item['angle'] != null) detailedMessage += '  前俯角：${item['angle']}\n';
              if (item['status'] != null) detailedMessage += '  状态：${item['status']}\n';
              if (item['normal'] != null) detailedMessage += '  正常：${item['normal']}小时\n';
              if (item['mild'] != null) detailedMessage += '  轻微异常：${item['mild']}小时\n';
              if (item['severe'] != null) detailedMessage += '  严重异常：${item['severe']}小时\n';
            }
          }
        }
      }
      
      print('开始调用N8N API');
      print('API URL: ${ApiConfig.n8nUrl}');
      print('详细消息: $detailedMessage');
      
      final response = await http.post(
        Uri.parse(ApiConfig.n8nUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': _userId,
          'message': detailedMessage,
          'session_id': _sessionId,
          'type': 'text',
          'user_info': userInfo,
          'posture_data': postureData,
        }),
      );
      
      print('API响应状态码: ${response.statusCode}');
      print('API响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('解析后的响应数据: $data');
        String aiResponse = data['response'] ?? '抱歉，我无法理解您的问题，请尝试换一种方式提问。';
        
        // 先检测是否包含训练计划JSON
        final trainingPlanResult = _extractAndFixTrainingPlan(aiResponse);
        final hasTrainingPlan = trainingPlanResult['hasTrainingPlan'] as bool;
        
        // 如果不包含训练计划，才过滤AI思考过程
        String finalResponse = aiResponse;
        if (!hasTrainingPlan) {
          finalResponse = _filterThinkingProcess(aiResponse);
        }
        
        if (mounted) {
          setState(() {
            // 移除加载中的消息
            _messages.removeWhere((message) => message.isLoading);
            // 添加实际的回复消息
            _messages.add(Message(
              text: finalResponse,
              isUser: false,
              timestamp: DateTime.now(),
              hasCalendarOption: hasTrainingPlan,
            ));
          });
        }
      } else {
        if (mounted) {
          setState(() {
            // 移除加载中的消息
            _messages.removeWhere((message) => message.isLoading);
            // 解析错误信息
            String errorMessage = '抱歉，服务暂时不可用，请稍后再试';
            try {
              final errorData = jsonDecode(response.body);
              if (errorData.containsKey('error')) {
                errorMessage = errorData['error'];
              }
            } catch (e) {
              print('解析错误信息失败: $e');
            }
            // 添加错误消息
            _messages.add(Message(
              text: errorMessage,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        }
      }
    } catch (e) {
      print('调用API失败: $e');
      if (mounted) {
        setState(() {
          // 移除加载中的消息
          _messages.removeWhere((message) => message.isLoading);
          // 添加错误消息
          _messages.add(Message(
            text: '网络错误，请检查网络连接后再试',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      // 保存消息
      _saveMessages();
      // 滚动到底部
      _scrollToBottom();
    }
  }

  // 加载消息记录
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString('chat_messages');
      
      if (messagesJson != null) {
        List<dynamic> messagesList = jsonDecode(messagesJson);
        if (mounted) {
          setState(() {
            _messages = messagesList.map((m) => Message.fromMap(m)).toList();
          });
        }
        
        // 加载后检查是否需要重置每日消息
        _checkAndResetDailyMessages();
        // 如果重置了消息，需要保存
        await _saveMessages();
      } else {
        // 添加欢迎消息
        final welcomeMessage = Message(
          text: '您好！我是您的智能健康助手，有什么可以帮您的吗？',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _messages.add(welcomeMessage);
        await _saveMessages();
      }
    } catch (e) {
      print('加载消息失败: $e');
      // 添加欢迎消息
      final welcomeMessage = Message(
        text: '您好！我是您的智能健康助手，有什么可以帮您的吗？',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(welcomeMessage);
    } finally {
      if (mounted) {
        // 先确保消息列表显示
        setState(() => _showMessages = true);
        // 对于reverse=true的SingleChildScrollView，初始位置就是在底部（最新消息）
        // 不需要额外的滚动操作，避免闪烁
      }
    }
  }

  // 保存消息记录（只保存当天的消息）
  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayMessages = _messages.where((msg) {
        return msg.timestamp.day == today.day &&
               msg.timestamp.month == today.month &&
               msg.timestamp.year == today.year;
      }).toList();
      
      final messagesList = todayMessages.map((msg) => msg.toMap()).toList();
      final messagesJson = jsonEncode(messagesList);
      await prefs.setString('chat_messages', messagesJson);
    } catch (e) {
      print('保存消息失败: $e');
    }
  }

  // 检查并重置每日消息
  void _checkAndResetDailyMessages() {
    if (_messages.isEmpty) return;
    
    final lastMessageDate = _messages.last.timestamp;
    final today = DateTime.now();
    
    // 检查是否是新的一天
    if (lastMessageDate.day != today.day || 
        lastMessageDate.month != today.month || 
        lastMessageDate.year != today.year) {
      // 不同天，清空所有记录，只添加新的欢迎消息
      final newWelcomeMessage = Message(
        text: '您好！我是您的智能健康助手，有什么可以帮您的吗？',
        isUser: false,
        timestamp: today,
      );
      
      // 更新消息列表并刷新UI
      if (mounted) {
        setState(() {
          _messages = [newWelcomeMessage];
        });
      } else {
        // 如果widget已经disposed，只更新数据，不刷新UI
        _messages = [newWelcomeMessage];
      }
    }
  }

  // 获取用户信息
  Future<Map<String, dynamic>?> _getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return null;
      
      // 调用后端API获取用户信息
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + '/posture/info/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('获取用户信息失败: $e');
      return null;
    }
  }

  // 获取姿态占比数据
  Future<Map<String, dynamic>?> _getPostureDistribution() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return null;
      
      // 调用后端API获取姿态占比数据（月视图）
      final response = await http.post(
        Uri.parse(ApiConfig.bodyMovementUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId, 'time_range': 'month'}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('获取姿态占比数据失败: $e');
      return null;
    }
  }

  // 获取当前位置
  Future<Map<String, double>?> _getCurrentLocation() async {
    try {
      print('开始获取位置...');
      
      // 直接请求权限
      LocationPermission permission = await Geolocator.requestPermission();
      print('权限状态: $permission');
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('定位权限被拒绝');
        return null;
      }

      print('权限检查通过，开始获取位置...');
      
      // 获取当前位置，使用Android原生LocationManager
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true,  // 强制使用Android原生定位
        timeLimit: const Duration(seconds: 30),
      );

      print('成功获取位置: 纬度=${position.latitude}, 经度=${position.longitude}');
      print('定位精度: ${position.accuracy}米');
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print('获取位置失败: $e');
      return null;
    }
  }

  // 过滤AI思考过程，只保留实际内容
  String _filterThinkingProcess(String aiResponse) {
    // 如果响应中包含分隔符，提取分隔符之间的内容
    if (aiResponse.contains('---')) {
      final parts = aiResponse.split('---');
      // 如果有多个分隔符，提取中间部分（实际报告）
      if (parts.length >= 2) {
        // 取第一个分隔符之后到最后一个分隔符之前的内容
        String report = '';
        for (int i = 1; i < parts.length - 1; i++) {
          report += parts[i];
          if (i < parts.length - 2) {
            report += '\n';
          }
        }
        if (report.trim().isNotEmpty) {
          return report.trim();
        }
        // 如果只有一个分隔符，返回分隔符之后的内容
        if (parts.length == 2) {
          return parts[1].trim();
        }
      }
    }
    
    // 如果包含标志性语句，从该语句开始提取
    final markers = [
      '以下是根据您提供的数据',
      '以下是针对你的',
      '当然可以！以下是',
      '以下是',
      '这份内容',
      '根据您的要求',
      '好的，',
      '好的!',
    ];
    
    for (var marker in markers) {
      if (aiResponse.contains(marker)) {
        final index = aiResponse.indexOf(marker);
        if (index >= 0) {
          String content = aiResponse.substring(index).trim();
          // 移除结尾的客套话
          final endMarkers = [
            '希望这份分享能够帮助',
            '如果需要调整或补充',
            '这份内容既专业又有针对性',
          ];
          for (var endMarker in endMarkers) {
            if (content.contains(endMarker)) {
              content = content.substring(0, content.indexOf(endMarker)).trim();
              break;
            }
          }
          return content;
        }
      }
    }
    
    // 如果没有找到分隔符，尝试移除思考过程的特征语句
    List<String> lines = aiResponse.split('\n');
    List<String> filteredLines = [];
    bool skipThinking = false;
    
    for (var line in lines) {
      // 跳过思考过程的特征语句
      if (line.contains('嗯，') ||
          line.contains('首先，') ||
          line.contains('接下来，') ||
          line.contains('我得') ||
          line.contains('用户是') ||
          line.contains('我需要理解') ||
          line.contains('现在把这些思考整合')) {
        skipThinking = true;
        continue;
      }
      
      // 如果遇到实际内容开始，停止跳过
      if (line.contains('【') ||
          line.contains('**') ||
          line.contains('#') ||
          line.contains('数据亮点') ||
          line.contains('健康洞察')) {
        skipThinking = false;
      }
      
      if (!skipThinking) {
        filteredLines.add(line);
      }
    }
    
    String filtered = filteredLines.join('\n').trim();
    
    // 如果过滤后内容太少，返回原始响应
    if (filtered.length < 50) {
      return aiResponse;
    }
    
    return filtered;
  }

  // 检测消息是否是报告类型
  bool _isReportMessage(String message) {
    final reportKeywords = [
      '日报',
      '周报',
      '月报',
      '数据亮点',
      '健康洞察',
      '改善建议',
      '激励语',
      '健康分享指南',
    ];
    
    for (var keyword in reportKeywords) {
      if (message.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  // 分享到小红书
  Future<void> _shareToXiaohongshu(String content) async {
    try {
      // 1. 复制内容到剪贴板
      await Clipboard.setData(ClipboardData(text: content));
      print('内容已复制到剪贴板');
      
      // 2. 尝试多种方式打开小红书发布页面
      final schemes = [
        'xiaohongshu://note',  // 发布笔记页面（优先尝试）
        'xhsdiscover://post?ignore_draft=true',  // 发布页面（忽略草稿）
        'xhsdiscover://post',  // 发布作品页面
        'xhsdiscover://home',  // 首页（备选）
        'xhsdiscover://',  // 基础协议（最后备选）
      ];
      
      bool launched = false;
      
      for (var scheme in schemes) {
        try {
          print('尝试打开: $scheme');
          final uri = Uri.parse(scheme);
          
          // 检查是否可以打开
          final canLaunch = await canLaunchUrl(uri);
          print('canLaunchUrl($scheme): $canLaunch');
          
          if (canLaunch) {
            // 尝试打开
            final result = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            print('launchUrl($scheme)结果: $result');
            
            if (result) {
              launched = true;
              // 稍微延迟一下，确保小红书已经打开
              await Future.delayed(Duration(milliseconds: 500));
              break;
            }
          }
        } catch (e) {
          print('尝试$scheme失败: $e');
        }
      }
      
      // 如果所有方式都失败，尝试通过包名打开
      if (!launched) {
        try {
          print('尝试通过包名打开小红书');
          final intentUri = Uri.parse('android-app://com.xingin.xhs');
          final result = await launchUrl(
            intentUri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          print('通过包名打开结果: $result');
          if (result) {
            launched = true;
          }
        } catch (e) {
          print('通过包名打开失败: $e');
        }
      }
      
      // 显示结果
      if (mounted) {
        if (launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('内容已复制，小红书发布页面已打开，请粘贴发布'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('内容已复制到剪贴板，请手动打开小红书粘贴'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('分享异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分享失败: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 检测AI响应中是否包含训练计划
  bool _detectTrainingPlan(String aiResponse) {
    try {
      print('开始检测训练计划...');
      
      // 清理响应内容，移除多余的空白字符和换行
      String cleanedResponse = aiResponse.trim();
      
      // 尝试找到JSON对象的开始
      int startIndex = cleanedResponse.indexOf('{');
      if (startIndex == -1) {
        print('未找到JSON开始标记');
        return false;
      }
      
      // 找到匹配的结束括号
      int braceCount = 0;
      int endIndex = -1;
      for (int i = startIndex; i < cleanedResponse.length; i++) {
        if (cleanedResponse[i] == '{') {
          braceCount++;
        } else if (cleanedResponse[i] == '}') {
          braceCount--;
          // 防止braceCount变为负数（处理多余的右括号）
          if (braceCount < 0) {
            braceCount = 0;
            continue; // 跳过这个多余的右括号，继续寻找
          }
          if (braceCount == 0) {
            endIndex = i + 1;
            break;
          }
        }
      }
      
      if (endIndex == -1) {
        print('未找到JSON结束标记');
        return false;
      }
      
      final jsonString = cleanedResponse.substring(startIndex, endIndex);
      print('提取的JSON字符串长度: ${jsonString.length}');
      
      String sanitizedJson = jsonString;
      try {
        // 清理JSON字符串中的非法字符
        sanitizedJson = jsonString
            .replaceAll('\u0000', '')
            .replaceAll('\u0001', '')
            .replaceAll('\u0002', '')
            .replaceAll('\u0003', '')
            .replaceAll('\u0004', '')
            .replaceAll('\u0005', '')
            .replaceAll('\u0006', '')
            .replaceAll('\u0007', '')
            .replaceAll('\u0008', '')
            .replaceAll('\u0009', ' ')
            .replaceAll('\u000a', ' ')
            .replaceAll('\u000b', ' ')
            .replaceAll('\u000c', ' ')
            .replaceAll('\u000d', ' ')
            .replaceAll('\u000e', '')
            .replaceAll('\u000f', '')
            .replaceAll('\u0010', '')
            .replaceAll('\u0011', '')
            .replaceAll('\u0012', '')
            .replaceAll('\u0013', '')
            .replaceAll('\u0014', '')
            .replaceAll('\u0015', '')
            .replaceAll('\u0016', '')
            .replaceAll('\u0017', '')
            .replaceAll('\u0018', '')
            .replaceAll('\u0019', '')
            .replaceAll('\u001a', '')
            .replaceAll('\u001b', '')
            .replaceAll('\u001c', '')
            .replaceAll('\u001d', '')
            .replaceAll('\u001e', '')
            .replaceAll('\u001f', '');
        
        // 尝试修复常见的JSON格式问题
        sanitizedJson = sanitizedJson
            .replaceAll('，', ',')
            .replaceAll('。', '.')
            .replaceAll('；', ';')
            .replaceAll('：', ':')
            .replaceAll('"', '"')
            .replaceAll('"', '"')
            .replaceAll(''', "'")
            .replaceAll(''', "'");
        
        // 修复未闭合的引号问题
        sanitizedJson = _fixUnclosedQuotes(sanitizedJson);
        print('清理后的JSON字符串: $sanitizedJson');
        
        final trainingPlan = jsonDecode(sanitizedJson);
        print('解析后的训练计划: $trainingPlan');
        
        // 验证训练计划格式
        if (trainingPlan is Map && 
            trainingPlan.containsKey('plan') && 
            trainingPlan['plan'] is List) {
          print('检测到训练计划');
          return true;
        } else {
          print('训练计划格式不正确');
          return false;
        }
      } catch (jsonError) {
        print('JSON解析失败: $jsonError');
        print('原始JSON字符串: $jsonString');
        print('清理后的JSON字符串: $sanitizedJson');
        // 尝试使用更宽松的解析方式
        try {
          // 简化验证，只要有plan字段就认为是训练计划
          if (jsonString.contains('"plan"') || jsonString.contains("'plan'")) {
            print('检测到包含plan字段的JSON');
            return true;
          }
        } catch (e) {
          print('简化验证也失败: $e');
        }
        return false;
      }
    } catch (e) {
      print('检测训练计划失败: $e');
      print('错误详情: ${e.toString()}');
      return false;
    }
  }

  // 修复JSON中未闭合的引号问题
  String _fixUnclosedQuotes(String json) {
    try {
      print('开始修复JSON引号问题...');
      
      // 1. 首先修复字段之间缺少逗号的问题
      // 例如: "name": "跑步训练：15分钟"\n          "start_time": "07:30"
      // 修复为: "name": "跑步训练：15分钟",\n          "start_time": "07:30"
      final missingCommaPattern = RegExp(r'"\s*\n\s*"');
      final missingCommaMatches = missingCommaPattern.allMatches(json);
      print('找到 ${missingCommaMatches.length} 个缺少逗号的字段');
      json = json.replaceAll(missingCommaPattern, '",\n        "');
      
      // 2. 主要修复模式：处理字段值中逗号后未闭合引号的情况
      // 例如: "name": "游泳 30分钟,           "start_time": "08:00"
      // 修复为: "name": "游泳 30分钟",           "start_time": "08:00"
      final brokenQuotePattern = RegExp(r'":\s*"([^"]*?),\s{3,}"');
      final matches1 = brokenQuotePattern.allMatches(json);
      print('找到 ${matches1.length} 个多空格未闭合引号');
      json = json.replaceAllMapped(brokenQuotePattern, (match) {
        final value = match.group(1) ?? '';
        return '": "$value", "';
      });
      
      // 3. 备用修复模式：处理较少空格的情况
      final lessSpacePattern = RegExp(r'":\s*"([^"]*?),\s{1,2}"');
      final matches2 = lessSpacePattern.allMatches(json);
      print('找到 ${matches2.length} 个少空格未闭合引号');
      json = json.replaceAllMapped(lessSpacePattern, (match) {
        final value = match.group(1) ?? '';
        return '": "$value", "';
      });
      
      // 4. 修复字段值中的未闭合引号 - 边界情况（行尾）
      final pattern = RegExp(r'"([^"]*?),\s*$');
      final matches3 = pattern.allMatches(json);
      print('找到 ${matches3.length} 个行尾未闭合引号');
      json = json.replaceAllMapped(pattern, (match) {
        final value = match.group(1) ?? '';
        return '"$value",';
      });
      
      // 5. 通用修复：处理任何 "value, "next_field" 模式
      final generalPattern = RegExp(r'"([^"]*?),\s*"');
      final matches4 = generalPattern.allMatches(json);
      print('找到 ${matches4.length} 个通用未闭合引号');
      json = json.replaceAllMapped(generalPattern, (match) {
        final value = match.group(1) ?? '';
        return '"$value", "';
      });
      
      print('JSON引号修复完成');
      
      return json;
    } catch (e) {
      print('修复引号失败: $e');
      return json;
    }
  }

  // 从AI响应中提取并保存训练计划
  Future<bool> _extractAndSaveTrainingPlan(String aiResponse) async {
    try {
      print('开始提取训练计划...');
      
      // 清理响应内容，移除多余的空白字符和换行
      String cleanedResponse = aiResponse.trim();
      
      // 尝试找到JSON对象的开始
      int startIndex = cleanedResponse.indexOf('{');
      if (startIndex == -1) {
        print('未找到JSON开始标记');
        return false;
      }
      
      // 找到匹配的结束括号
      int braceCount = 0;
      int endIndex = -1;
      for (int i = startIndex; i < cleanedResponse.length; i++) {
        if (cleanedResponse[i] == '{') {
          braceCount++;
        } else if (cleanedResponse[i] == '}') {
          braceCount--;
          // 防止braceCount变为负数（处理多余的右括号）
          if (braceCount < 0) {
            braceCount = 0;
            continue; // 跳过这个多余的右括号，继续寻找
          }
          if (braceCount == 0) {
            endIndex = i + 1;
            break;
          }
        }
      }
      
      if (endIndex == -1) {
        print('未找到JSON结束标记');
        return false;
      }
      
      final jsonString = cleanedResponse.substring(startIndex, endIndex);
      print('提取的JSON字符串长度: ${jsonString.length}');
      
      String sanitizedJson = jsonString;
      Map<String, dynamic>? trainingPlan;
      
      try {
        // 清理JSON字符串中的非法字符
        sanitizedJson = jsonString
            .replaceAll('\u0000', '')
            .replaceAll('\u0001', '')
            .replaceAll('\u0002', '')
            .replaceAll('\u0003', '')
            .replaceAll('\u0004', '')
            .replaceAll('\u0005', '')
            .replaceAll('\u0006', '')
            .replaceAll('\u0007', '')
            .replaceAll('\u0008', '')
            .replaceAll('\u0009', ' ')
            .replaceAll('\u000a', ' ')
            .replaceAll('\u000b', ' ')
            .replaceAll('\u000c', ' ')
            .replaceAll('\u000d', ' ')
            .replaceAll('\u000e', '')
            .replaceAll('\u000f', '')
            .replaceAll('\u0010', '')
            .replaceAll('\u0011', '')
            .replaceAll('\u0012', '')
            .replaceAll('\u0013', '')
            .replaceAll('\u0014', '')
            .replaceAll('\u0015', '')
            .replaceAll('\u0016', '')
            .replaceAll('\u0017', '')
            .replaceAll('\u0018', '')
            .replaceAll('\u0019', '')
            .replaceAll('\u001a', '')
            .replaceAll('\u001b', '')
            .replaceAll('\u001c', '')
            .replaceAll('\u001d', '')
            .replaceAll('\u001e', '')
            .replaceAll('\u001f', '');
        
        // 尝试修复常见的JSON格式问题
        sanitizedJson = sanitizedJson
            .replaceAll('，', ',')
            .replaceAll('。', '.')
            .replaceAll('；', ';')
            .replaceAll('：', ':')
            .replaceAll('"', '"')
            .replaceAll('"', '"')
            .replaceAll("'", "'")
            .replaceAll("'", "'");
        
        // 修复未闭合的引号问题
        sanitizedJson = _fixUnclosedQuotes(sanitizedJson);
        print('清理后的JSON字符串: $sanitizedJson');
        
        trainingPlan = jsonDecode(sanitizedJson);
        print('解析后的训练计划: $trainingPlan');
      } catch (jsonError) {
        print('JSON解析失败: $jsonError');
        print('尝试使用宽松模式提取训练计划...');
        
        // 宽松模式：即使JSON解析失败，也尝试提取plan字段
        trainingPlan = _extractPlanLoosely(cleanedResponse);
      }
      
      if (trainingPlan != null) {
        // 验证训练计划格式
        if (trainingPlan.containsKey('plan') && trainingPlan['plan'] is List) {
          final Map<String, dynamic> stringKeyMap = {};
          trainingPlan.forEach((key, value) {
            if (key is String) {
              stringKeyMap[key] = value;
            }
          });
          
          // 处理plan列表，删除所有day字段（周几信息）
          if (stringKeyMap.containsKey('plan') && stringKeyMap['plan'] is List) {
            List planList = stringKeyMap['plan'];
            for (var dayPlan in planList) {
              if (dayPlan is Map) {
                // 删除day字段（周几信息）
                dayPlan.remove('day');
              }
            }
          }
          
          await _saveTrainingPlan(stringKeyMap);
          print('训练计划保存成功');
          return true;
        } else {
          print('训练计划格式不正确');
          return false;
        }
      } else {
        print('无法提取训练计划');
        return false;
      }
    } catch (e) {
      print('提取训练计划失败: $e');
      print('错误详情: ${e.toString()}');
      return false;
    }
  }
  
  // 宽松模式提取训练计划
  Map<String, dynamic>? _extractPlanLoosely(String response) {
    try {
      print('开始宽松模式提取训练计划...');
      
      // 尝试找到plan字段的开始和结束
      int planStart = response.indexOf('"plan"');
      if (planStart == -1) {
        planStart = response.indexOf("'plan'");
      }
      
      if (planStart == -1) {
        print('未找到plan字段');
        return null;
      }
      
      // 找到plan字段后面的冒号和数组开始
      int arrayStart = response.indexOf('[', planStart);
      if (arrayStart == -1) {
        print('未找到数组开始标记');
        return null;
      }
      
      // 找到匹配的数组结束括号
      int bracketCount = 0;
      int arrayEnd = -1;
      for (int i = arrayStart; i < response.length; i++) {
        if (response[i] == '[') {
          bracketCount++;
        } else if (response[i] == ']') {
          bracketCount--;
          if (bracketCount == 0) {
            arrayEnd = i + 1;
            break;
          }
        }
      }
      
      if (arrayEnd == -1) {
        print('未找到数组结束标记');
        return null;
      }
      
      // 提取plan数组字符串
      String planArrayStr = response.substring(arrayStart, arrayEnd);
      print('提取的plan数组字符串: $planArrayStr');
      
      // 尝试解析plan数组
      try {
        List<dynamic> planList = jsonDecode(planArrayStr);
        print('成功解析plan数组，包含${planList.length}个训练日');
        
        return {
          'plan': planList,
          'summary': '从AI响应中提取的训练计划'
        };
      } catch (e) {
        print('解析plan数组失败: $e');
        
        // 如果解析失败，尝试手动提取训练日信息
        List<Map<String, dynamic>> manualPlan = [];
        
        // 查找所有的date字段
        int dateIndex = 0;
        while (true) {
          int datePos = response.indexOf('"date"', dateIndex);
          if (datePos == -1) break;
          
          // 提取date值
          int dateValueStart = response.indexOf(':', datePos);
          if (dateValueStart == -1) break;
          dateValueStart = response.indexOf('"', dateValueStart);
          if (dateValueStart == -1) break;
          int dateValueEnd = response.indexOf('"', dateValueStart + 1);
          if (dateValueEnd == -1) break;
          
          String dateValue = response.substring(dateValueStart + 1, dateValueEnd);
          print('找到训练日期: $dateValue');
          
          // 查找exercises数组
          int exercisesPos = response.indexOf('"exercises"', dateValueEnd);
          if (exercisesPos != -1) {
            int exArrayStart = response.indexOf('[', exercisesPos);
            if (exArrayStart != -1) {
              int exBracketCount = 0;
              int exArrayEnd = -1;
              for (int i = exArrayStart; i < response.length && i < exArrayStart + 5000; i++) {
                if (response[i] == '[') {
                  exBracketCount++;
                } else if (response[i] == ']') {
                  exBracketCount--;
                  if (exBracketCount == 0) {
                    exArrayEnd = i + 1;
                    break;
                  }
                }
              }
              
              if (exArrayEnd != -1) {
                String exercisesStr = response.substring(exArrayStart, exArrayEnd);
                try {
                  List<dynamic> exercises = jsonDecode(exercisesStr);
                  manualPlan.add({
                    'date': dateValue,
                    'exercises': exercises
                  });
                  print('成功提取${exercises.length}个训练项目');
                } catch (exE) {
                  print('解析exercises失败: $exE');
                  manualPlan.add({
                    'date': dateValue,
                    'exercises': []
                  });
                }
              }
            }
          }
          
          dateIndex = dateValueEnd + 1;
          if (manualPlan.length >= 7) break; // 最多提取7天
        }
        
        if (manualPlan.isNotEmpty) {
          print('手动提取了${manualPlan.length}个训练日');
          return {
            'plan': manualPlan,
            'summary': '从AI响应中提取的训练计划'
          };
        }
        
        return null;
      }
    } catch (e) {
      print('宽松模式提取失败: $e');
      return null;
    }
  }

  // 保存训练计划到本地存储
  Future<void> _saveTrainingPlan(Map<String, dynamic> trainingPlan) async {
    try {
      await TrainingPlanStorage.saveTrainingPlan(trainingPlan);
      print('训练计划已保存到本地文件');
    } catch (e) {
      print('保存训练计划失败: $e');
    }
  }

  void _simulateAIResponse(String userMessage) {
    // 延迟模拟AI思考
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      String response;
      bool hasCalendarOption = false;
      
      // 简单的回复逻辑
      if (userMessage.contains('训练') || userMessage.contains('计划')) {
        response = '根据您的身体状况，我为您制定了以下训练计划：\n1. 每天进行30分钟的有氧运动\n2. 每小时起身活动5分钟\n3. 保持正确的坐姿和站姿\n\n坚持锻炼将有助于改善您的体态和健康状况。';
        hasCalendarOption = true;
      } else if (userMessage.contains('健康建议')) {
        response = '健康建议：\n1. 每天保持8小时睡眠\n2. 多喝水，每天至少2升\n3. 均衡饮食，多吃蔬菜水果\n4. 定期运动，每周至少150分钟\n5. 减少久坐时间';
      } else if (userMessage.contains('姿势纠正')) {
        response = '姿势纠正建议：\n1. 坐姿时保持背部挺直\n2. 使用符合人体工程学的椅子\n3. 每小时起身活动5分钟\n4. 睡觉时使用合适的枕头\n5. 定期做伸展运动';
      } else if (userMessage.contains('健康餐馆')) {
        response = '为您推荐附近的健康餐馆：\n1. 绿色餐厅 - 提供有机食材制作的健康餐点\n2. 活力沙拉吧 - 新鲜蔬果沙拉，多种选择\n3. 轻食主义 - 低卡路里健康快餐';
      } else if (userMessage.contains('小红书分享')) {
        response = '小红书分享功能已启动，您可以分享您的健康生活方式和训练成果。';
      } else {
        response = '感谢您的提问！我正在分析您的需求，为您提供最准确的健康建议。\n\n您可以询问关于训练计划、健康知识或姿势纠正等方面的问题。';
      }

      if (mounted) {
        setState(() {
          _messages.add(Message(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            hasCalendarOption: hasCalendarOption,
          ));
        });

        // 保存消息
        _saveMessages();
        
        // 滚动到底部
        _scrollToBottom();
      }
    });
  }

  // 保存训练计划
  Future<void> _writeToCalendar(String planText) async {
    try {
      print('开始保存训练计划...');
      
      final success = await _extractAndSaveTrainingPlan(planText);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('训练计划已保存')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('训练计划格式不正确')),
        );
      }
    } catch (e) {
      print('保存训练计划失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  // 发送详细的训练计划请求
  Future<void> _sendDetailedTrainingPlanRequest() async {
    if (_userId == null) {
      if (mounted) {
        setState(() {
          _messages.add(Message(
            text: '请先登录后再使用智能服务',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
      _saveMessages();
      _scrollToBottom();
      return;
    }

    // 显示用户输入的消息
    setState(() {
      _messages.add(Message(
        text: '制定训练计划',
        isUser: true,
        timestamp: DateTime.now(),
      ));
      // 添加一个加载中的消息
      _messages.add(Message(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
      _textController.clear();
    });

    // 保存消息
    _saveMessages();
    
    // 滚动到底部
    _scrollToBottom();

    try {
      // 获取姿态占比数据
      final postureData = await _getPostureDistribution();

      // 构建详细的提示词
      String detailedPrompt = '请为我制定一个个性化的训练计划，用户ID：$_userId\n';

      // 添加姿态占比数据
      if (postureData != null) {
        detailedPrompt += '\n近一个月姿态占比：\n';
        if (postureData['posture_distribution'] != null) {
          for (var item in postureData['posture_distribution']) {
            detailedPrompt += '- ${item['name']}：${item['value']}% (${item['hours']})\n';
          }
        }
        detailedPrompt += '\n活动数据：\n';
        detailedPrompt += '- 步数：${postureData['steps'] ?? 0}\n';
        detailedPrompt += '- 卡路里：${postureData['calories'] ?? 0}\n';
        detailedPrompt += '- 距离：${postureData['distance'] ?? 0}km\n';
        detailedPrompt += '- 活动时间：${postureData['active_time'] ?? 0}min\n';
        
        // 添加活动趋势数据
          if (postureData['activity_trend'] != null) {
            detailedPrompt += '\n每周活动趋势：\n';
            for (var item in postureData['activity_trend']) {
              detailedPrompt += '- ${item['label']}：${item['steps']}步\n';
            }
          }
          
          // 添加姿态详细数据
          if (postureData['postures'] != null) {
            detailedPrompt += '\n姿态详细数据：\n';
            for (var item in postureData['postures']) {
              detailedPrompt += '- ${item['date'] ?? item['label']}：\n';
              if (item['sitting'] != null) detailedPrompt += '  坐姿：${item['sitting']}小时\n';
              if (item['standing'] != null) detailedPrompt += '  站姿：${item['standing']}小时\n';
              if (item['walking'] != null) detailedPrompt += '  行走：${item['walking']}小时\n';
              if (item['running'] != null) detailedPrompt += '  跑步：${item['running']}小时\n';
              if (item['lying'] != null) detailedPrompt += '  躺姿：${item['lying']}小时\n';
            }
          }
          
          // 添加姿态角度数据
          if (postureData['posture_angles'] != null) {
            detailedPrompt += '\n姿态角度数据：\n';
            // 添加年龄组定义
            detailedPrompt += '年龄组定义：\n';
            detailedPrompt += '- 青年组：11-24岁\n';
            detailedPrompt += '- 壮年组：25-44岁\n';
            detailedPrompt += '- 中年组：45-59岁\n';
            detailedPrompt += '- 老年组：60岁及以上\n\n';
            // 添加角度范围定义
            detailedPrompt += '角度范围定义：\n';
            detailedPrompt += '- 正常：标准范围内的角度\n';
            detailedPrompt += '- 轻微异常：偏离标准范围中点的偏差≤10度（老年组≤12度）\n';
            detailedPrompt += '- 严重异常：偏离标准范围中点的偏差>10度（老年组>12度）\n\n';
            for (var item in postureData['posture_angles']) {
              detailedPrompt += '- ${item['time'] ?? item['date'] ?? item['week'] ?? item['label']}：\n';
              if (item['angle'] != null) detailedPrompt += '  前俯角：${item['angle']}\n';
              if (item['status'] != null) detailedPrompt += '  状态：${item['status']}\n';
              if (item['normal'] != null) detailedPrompt += '  正常：${item['normal']}小时\n';
              if (item['mild'] != null) detailedPrompt += '  轻微异常：${item['mild']}小时\n';
              if (item['severe'] != null) detailedPrompt += '  严重异常：${item['severe']}小时\n';
            }
          }
      }

      // 直接让大模型捕捉当前日期
      
      detailedPrompt += '\n请根据上述数据生成未来一周的详细训练安排，要求：\n';
      detailedPrompt += '- 生成从今天开始的未来7天（包括今天）的训练计划\n';
      detailedPrompt += '- 请自动捕捉当前日期，从今天开始连续生成7天的计划\n';
      detailedPrompt += '- 每天必须包含具体的日期（YYYY-MM-DD格式）\n';
      detailedPrompt += '- 每天的具体训练时间（开始时间和结束时间）\n';
      detailedPrompt += '- 具体的运动项目和训练内容\n';
      detailedPrompt += '- 训练强度和时长\n';
      detailedPrompt += '- 考虑我的姿态习惯，帮助改善不良姿态\n';
      detailedPrompt += '- 考虑我的健康状况和身体条件，避免过度训练\n';
      detailedPrompt += '\n重要：请只输出JSON格式的训练计划，不要包含任何其他文字说明或分析内容。\n';
      detailedPrompt += '今天是{{ $json.body.current_date }}\n';
      detailedPrompt += '\nJSON格式要求：\n';
      detailedPrompt += '- 只输出完整的JSON对象，不要有任何前缀或后缀文字\n';
      detailedPrompt += '- 确保所有字段名和字符串值都用双引号包围\n';
      detailedPrompt += '- 确保所有逗号、冒号等标点符号都是英文半角\n';
      detailedPrompt += '- 确保JSON格式完全正确，可直接被JSON解析器解析\n';
      detailedPrompt += '- 只包含plan数组，每个元素包含date和exercises字段\n';
      detailedPrompt += '- exercises数组中的每个元素必须包含name、start_time、end_time、intensity、duration、description字段\n';

      detailedPrompt += '\n示例JSON格式：\n';
      detailedPrompt += '{\n';
      detailedPrompt += '  "plan": [\n';
      detailedPrompt += '    {\n';
      detailedPrompt += '      "date": "YYYY-MM-DD", // 例如：2024-01-01\n';
      detailedPrompt += '      "exercises": [\n';
      detailedPrompt += '        {\n';
      detailedPrompt += '          "name": "运动项目名称",\n';
      detailedPrompt += '          "start_time": "08:00",\n';
      detailedPrompt += '          "end_time": "08:30",\n';
      detailedPrompt += '          "intensity": "中等",\n';
      detailedPrompt += '          "duration": "30分钟",\n';
      detailedPrompt += '          "description": "运动项目描述"\n';
      detailedPrompt += '        }\n';
      detailedPrompt += '      ]\n';
      detailedPrompt += '    },\n';
      detailedPrompt += '    {\n';
      detailedPrompt += '\n';
      detailedPrompt += '      "date": "YYYY-MM-DD",\n';
      detailedPrompt += '      "exercises": [\n';
      detailedPrompt += '        {\n';
      detailedPrompt += '          "name": "运动项目名称",\n';
      detailedPrompt += '          "start_time": "08:00",\n';
      detailedPrompt += '          "end_time": "08:30",\n';
      detailedPrompt += '          "intensity": "中等",\n';
      detailedPrompt += '          "duration": "30分钟",\n';
      detailedPrompt += '          "description": "运动项目描述"\n';
      detailedPrompt += '        }\n';
      detailedPrompt += '      ]\n';
      detailedPrompt += '    },\n';
      detailedPrompt += '    {\n';
      detailedPrompt += '\n';
      detailedPrompt += '      "date": "YYYY-MM-DD",\n';
      detailedPrompt += '      "exercises": [\n';
      detailedPrompt += '        {\n';
      detailedPrompt += '          "name": "运动项目名称",\n';
      detailedPrompt += '          "start_time": "08:00",\n';
      detailedPrompt += '          "end_time": "08:30",\n';
      detailedPrompt += '          "intensity": "中等",\n';
      detailedPrompt += '          "duration": "30分钟",\n';
      detailedPrompt += '          "description": "运动项目描述"\n';
      detailedPrompt += '        }\n';
      detailedPrompt += '      ]\n';
      detailedPrompt += '    },\n';
      detailedPrompt += '    {\n';
      detailedPrompt += '\n';
      detailedPrompt += '      "date": "YYYY-MM-DD",\n';
      detailedPrompt += '      "exercises": [\n';
      detailedPrompt += '        {\n';
      detailedPrompt += '          "name": "运动项目名称",\n';
      detailedPrompt += '          "start_time": "08:00",\n';
      detailedPrompt += '          "end_time": "08:30",\n';
      detailedPrompt += '          "intensity": "中等",\n';
      detailedPrompt += '          "duration": "30分钟",\n';
      detailedPrompt += '          "description": "运动项目描述"\n';
      detailedPrompt += '        }\n';
      detailedPrompt += '      ]\n';
      detailedPrompt += '    },\n';
      detailedPrompt += '    {\n';
      detailedPrompt += '\n';
      detailedPrompt += '      "date": "YYYY-MM-DD",\n';
      detailedPrompt += '      "exercises": [\n';
      detailedPrompt += '        {\n';
      detailedPrompt += '          "name": "运动项目名称",\n';
      detailedPrompt += '          "start_time": "08:00",\n';
      detailedPrompt += '          "end_time": "08:30",\n';
      detailedPrompt += '          "intensity": "中等",\n';
      detailedPrompt += '          "duration": "30分钟",\n';
      detailedPrompt += '          "description": "运动项目描述"\n';
      detailedPrompt += '        }\n';
      detailedPrompt += '      ]\n';
      detailedPrompt += '    },\n';
      detailedPrompt += '    {\n';
      detailedPrompt += '\n';
      detailedPrompt += '      "date": "YYYY-MM-DD",\n';
      detailedPrompt += '      "exercises": [\n';
      detailedPrompt += '        {\n';
      detailedPrompt += '          "name": "运动项目名称",\n';
      detailedPrompt += '          "start_time": "08:00",\n';
      detailedPrompt += '          "end_time": "08:30",\n';
      detailedPrompt += '          "intensity": "中等",\n';
      detailedPrompt += '          "duration": "30分钟",\n';
      detailedPrompt += '          "description": "运动项目描述"\n';
      detailedPrompt += '        }\n';
      detailedPrompt += '      ]\n';
      detailedPrompt += '    },\n';
      detailedPrompt += '    {\n';
      detailedPrompt += '\n';
      detailedPrompt += '      "date": "YYYY-MM-DD",\n';
      detailedPrompt += '      "exercises": [\n';
      detailedPrompt += '        {\n';
      detailedPrompt += '          "name": "运动项目名称",\n';
      detailedPrompt += '          "start_time": "08:00",\n';
      detailedPrompt += '          "end_time": "08:30",\n';
      detailedPrompt += '          "intensity": "中等",\n';
      detailedPrompt += '          "duration": "30分钟",\n';
      detailedPrompt += '          "description": "运动项目描述"\n';
      detailedPrompt += '        }\n';
      detailedPrompt += '      ]\n';
      detailedPrompt += '    }\n';
      detailedPrompt += '  ],\n';
      detailedPrompt += '  "summary": "整体训练计划总结"\n';
      detailedPrompt += '}\n';
      detailedPrompt += '\n请严格按照上述JSON格式输出，从今天开始连续生成7天的计划，只返回JSON数据，不要包含任何其他文字。今天是日期请参考提示词';

      // 调用N8N处理消息
      await _processMessageWithN8N(detailedPrompt);
    } catch (e) {
      print('发送训练计划请求失败: $e');
      if (mounted) {
        setState(() {
          // 移除加载中的消息
          _messages.removeWhere((message) => message.isLoading);
          // 添加错误消息
          _messages.add(Message(
            text: '生成训练计划失败，请稍后再试',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
      _saveMessages();
      _scrollToBottom();
    }
  }

  // 发送健康餐馆推荐请求
  Future<void> _sendHealthyRestaurantRequest() async {
    if (_userId == null) {
      if (mounted) {
        setState(() {
          _messages.add(Message(
            text: '请先登录后再使用智能服务',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
      _saveMessages();
      _scrollToBottom();
      return;
    }

    // 显示用户输入的消息
    setState(() {
      _messages.add(Message(
        text: '推荐健康餐馆',
        isUser: true,
        timestamp: DateTime.now(),
      ));
      // 添加一个加载中的消息
      _messages.add(Message(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
      _textController.clear();
    });

    // 保存消息
    _saveMessages();
    
    // 滚动到底部
    _scrollToBottom();

    try {
      // 获取用户信息和姿态数据
      final userInfo = await _getUserInfo();
      final postureData = await _getPostureDistribution();

      // 构建详细的提示词
      String detailedPrompt = '请为我推荐附近的健康餐馆\n';

      // 添加用户基本信息
      if (userInfo != null) {
        detailedPrompt += '\n用户基本信息：\n';
        detailedPrompt += '- 年龄：${userInfo['age'] ?? '未知'}岁\n';
        detailedPrompt += '- 体重：${userInfo['weight'] ?? '未知'}kg\n';
        detailedPrompt += '- 身高：${userInfo['height'] ?? '未知'}cm\n';
        detailedPrompt += '- 身份：${userInfo['identity'] ?? '未知'}\n';
        if (userInfo['ills'] != null && userInfo['ills'].toString().isNotEmpty) {
          detailedPrompt += '- 健康状况：${userInfo['ills']}\n';
        }
      }

      // 添加姿态占比数据
      if (postureData != null) {
        detailedPrompt += '\n近一个月姿态占比：\n';
        if (postureData['posture_distribution'] != null) {
          for (var item in postureData['posture_distribution']) {
            detailedPrompt += '- ${item['name']}：${item['value']}% (${item['hours']})\n';
          }
        }
        detailedPrompt += '\n活动数据：\n';
        detailedPrompt += '- 步数：${postureData['steps'] ?? 0}\n';
        detailedPrompt += '- 卡路里：${postureData['calories'] ?? 0}\n';
        detailedPrompt += '- 距离：${postureData['distance'] ?? 0}km\n';
        detailedPrompt += '- 活动时间：${postureData['active_time'] ?? 0}min\n';
        
        // 添加活动趋势数据
          if (postureData['activity_trend'] != null) {
            detailedPrompt += '\n每周活动趋势：\n';
            for (var item in postureData['activity_trend']) {
              detailedPrompt += '- ${item['label']}：${item['steps']}步\n';
            }
          }
          
          // 添加姿态详细数据
          if (postureData['postures'] != null) {
            detailedPrompt += '\n姿态详细数据：\n';
            for (var item in postureData['postures']) {
              detailedPrompt += '- ${item['date'] ?? item['label']}：\n';
              if (item['sitting'] != null) detailedPrompt += '  坐姿：${item['sitting']}小时\n';
              if (item['standing'] != null) detailedPrompt += '  站姿：${item['standing']}小时\n';
              if (item['walking'] != null) detailedPrompt += '  行走：${item['walking']}小时\n';
              if (item['running'] != null) detailedPrompt += '  跑步：${item['running']}小时\n';
              if (item['lying'] != null) detailedPrompt += '  躺姿：${item['lying']}小时\n';
            }
          }
          
          // 添加姿态角度数据
          if (postureData['posture_angles'] != null) {
            detailedPrompt += '\n姿态角度数据：\n';
            // 添加年龄组定义
            detailedPrompt += '年龄组定义：\n';
            detailedPrompt += '- 青年组：11-24岁\n';
            detailedPrompt += '- 壮年组：25-44岁\n';
            detailedPrompt += '- 中年组：45-59岁\n';
            detailedPrompt += '- 老年组：60岁及以上\n\n';
            // 添加角度范围定义
            detailedPrompt += '角度范围定义：\n';
            detailedPrompt += '- 正常：标准范围内的角度\n';
            detailedPrompt += '- 轻微异常：偏离标准范围中点的偏差≤10度（老年组≤12度）\n';
            detailedPrompt += '- 严重异常：偏离标准范围中点的偏差>10度（老年组>12度）\n\n';
            for (var item in postureData['posture_angles']) {
              detailedPrompt += '- ${item['time'] ?? item['date'] ?? item['week'] ?? item['label']}：\n';
              if (item['angle'] != null) detailedPrompt += '  前俯角：${item['angle']}\n';
              if (item['status'] != null) detailedPrompt += '  状态：${item['status']}\n';
              if (item['normal'] != null) detailedPrompt += '  正常：${item['normal']}小时\n';
              if (item['mild'] != null) detailedPrompt += '  轻微异常：${item['mild']}小时\n';
              if (item['severe'] != null) detailedPrompt += '  严重异常：${item['severe']}小时\n';
            }
          }
      }

      detailedPrompt += '\n请根据上述数据推荐适合我的健康餐馆，要求：\n';
      detailedPrompt += '- 考虑我的年龄、体重、身高等身体状况\n';
      detailedPrompt += '- 结合我的活动量和姿态习惯\n';
      detailedPrompt += '- 如果有健康状况，推荐适合的餐饮类型\n';
      detailedPrompt += '- 优先推荐：轻食、沙拉、高蛋白、低脂、有机等健康餐饮\n';
      detailedPrompt += '- 排除：快餐、油炸、高糖、高盐等不健康餐饮\n';
      detailedPrompt += '- 给出具体的推荐理由和营养价值分析\n';
      detailedPrompt += '- 按健康度和距离综合排序\n';
      detailedPrompt += '- 推荐3-5家餐馆\n';

      // 调用N8N处理消息（使用特殊类型标记为健康餐馆请求）
      await _processHealthyRestaurantRequest(detailedPrompt);
    } catch (e) {
      print('发送健康餐馆请求失败: $e');
      if (mounted) {
        setState(() {
          // 移除加载中的消息
          _messages.removeWhere((message) => message.isLoading);
          // 添加错误消息
          _messages.add(Message(
            text: '获取健康餐馆推荐失败，请稍后再试',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
      _saveMessages();
      _scrollToBottom();
    }
  }

  // 处理健康餐馆请求（发送到后端）
  Future<void> _processHealthyRestaurantRequest(String messageText) async {
    if (_userId == null) {
      if (mounted) {
        setState(() {
          _messages.add(Message(
            text: '请先登录后再使用智能服务',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
      _saveMessages();
      _scrollToBottom();
      return;
    }
    
    try {
      // 获取用户信息
      final userInfo = await _getUserInfo();
      // 获取姿态占比数据
      final postureData = await _getPostureDistribution();
      // 获取用户位置
      final location = await _getCurrentLocation();
      
      print('开始调用健康餐馆推荐API');
      print('API URL: ${ApiConfig.n8nUrl}');
      print('用户位置: 纬度=${location?['latitude']}, 经度=${location?['longitude']}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.n8nUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': _userId,
          'message': messageText,
          'session_id': _sessionId,
          'type': 'healthy_restaurant', // 特殊类型标记
          'user_info': userInfo,
          'posture_data': postureData,
          'latitude': location?['latitude'],
          'longitude': location?['longitude'],
        }),
      );
      
      print('API响应状态码: ${response.statusCode}');
      print('API响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('解析后的响应数据: $data');
        String aiResponse = data['response'] ?? '抱歉，无法获取餐馆推荐，请稍后再试。';
        
        // 过滤AI思考过程，只保留实际内容
        aiResponse = _filterThinkingProcess(aiResponse);
        
        if (mounted) {
          setState(() {
            // 移除加载中的消息
            _messages.removeWhere((message) => message.isLoading);
            // 添加实际的回复消息
            _messages.add(Message(
              text: aiResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        }
      } else {
        if (mounted) {
          setState(() {
            // 移除加载中的消息
            _messages.removeWhere((message) => message.isLoading);
            // 解析错误信息
            String errorMessage = '抱歉，服务暂时不可用，请稍后再试';
            try {
              final errorData = jsonDecode(response.body);
              if (errorData.containsKey('error')) {
                errorMessage = errorData['error'];
              }
            } catch (e) {
              print('解析错误信息失败: $e');
            }
            // 添加错误消息
            _messages.add(Message(
              text: errorMessage,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        }
      }
    } catch (e) {
      print('调用API失败: $e');
      if (mounted) {
        setState(() {
          // 移除加载中的消息
          _messages.removeWhere((message) => message.isLoading);
          // 添加错误消息
          _messages.add(Message(
            text: '网络错误，请检查网络连接后再试',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      // 保存消息
      _saveMessages();
      // 滚动到底部
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // 使用jumpTo滚动到最新消息（底部）
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // 构建跳动的加载点
  Widget _buildLoadingDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF4A90E2),
        borderRadius: BorderRadius.circular(4),
      ),
      transform: Matrix4.translationValues(
        0,
        // 根据index和当前时间计算垂直偏移，实现跳动效果
        -8 * sin(DateTime.now().millisecondsSinceEpoch / 200 + index * 2.094),
        0,
      ),
    );
  }

  // 辅助方法：解析消息文本中的格式符号
  List<TextSpan> _parseMessageText(String text) {
    List<TextSpan> spans = [];
    
    // 简单的Markdown解析，支持**加粗**格式
    int start = 0;
    while (start < text.length) {
      int boldStart = text.indexOf('**', start);
      if (boldStart == -1) {
        // 没有更多加粗格式，添加剩余文本
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontSize: 14, color: Colors.black),
        ));
        break;
      }
      
      // 添加加粗前的文本
      if (boldStart > start) {
        spans.add(TextSpan(
          text: text.substring(start, boldStart),
          style: const TextStyle(fontSize: 14, color: Colors.black),
        ));
      }
      
      // 查找加粗结束位置
      int boldEnd = text.indexOf('**', boldStart + 2);
      if (boldEnd == -1) {
        // 没有找到结束标记，添加剩余文本
        spans.add(TextSpan(
          text: text.substring(boldStart),
          style: const TextStyle(fontSize: 14, color: Colors.black),
        ));
        break;
      }
      
      // 添加加粗文本
      spans.add(TextSpan(
        text: text.substring(boldStart + 2, boldEnd),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ));
      
      // 更新起始位置
      start = boldEnd + 2;
    }
    
    return spans;
  }

  Widget _buildMessageBubble(Message message) {
    // 如果是加载中的消息，显示三个跳动的点
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: const Radius.circular(0),
              bottomRight: const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLoadingDot(0),
              const SizedBox(width: 6),
              _buildLoadingDot(1),
              const SizedBox(width: 6),
              _buildLoadingDot(2),
            ],
          ),
        ),
      );
    }
    
    // 正常消息的显示
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: message.isUser ? const Radius.circular(12) : const Radius.circular(0),
            bottomRight: message.isUser ? const Radius.circular(0) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SelectableText.rich(
              TextSpan(
                children: _parseMessageText(message.text),
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            if (message.hasCalendarOption) ...[
              const SizedBox(height: 12),
              const Text(
                '是否需要保存训练计划？',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [                  ElevatedButton(
                    onPressed: () {
                      // 写入日历逻辑
                      _writeToCalendar(message.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('保存', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // 不写入日历
                      if (mounted) {
                        setState(() {
                          _messages.add(Message(
                            text: '好的，期待下次为您服务~',
                            isUser: false,
                            timestamp: DateTime.now(),
                          ));
                        });
                        _saveMessages();
                        _scrollToBottom();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('否', style: TextStyle(fontSize: 12, color: Colors.black)),
                  ),                ],
              ),
            ],
            // 如果是报告消息，显示分享按钮
            if (!message.isUser && _isReportMessage(message.text)) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _shareToXiaohongshu(message.text),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('分享到小红书', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2442), // 小红书红色
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 页面构建完成后，确保滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        // 滚动到最新消息（底部）
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能体服务'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Image(image: AssetImage('assets/background.png'), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          Column(
            children: [
              // 消息列表
              Expanded(
                child: _showMessages
                    ? SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        // 移除reverse: true，保持正常的消息顺序
                        child: Column(
                          children: _messages.map((message) => _buildMessageBubble(message)).toList(),
                        ),
                      )
                    : Center(child: Text('加载中...')),
              ),
              // 功能按钮
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      offset: Offset(0, -2),
                      blurRadius: 6,
                      spreadRadius: 0,
                      blurStyle: BlurStyle.outer,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _textController.text = '制定训练计划';
                          _sendDetailedTrainingPlanRequest();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFF39FF14), width: 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              const Text('制定训练计划', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _sendHealthyRestaurantRequest();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFF39FF14), width: 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.restaurant, size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              const Text('健康餐馆', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _textController.text = '健康建议';
                          _sendMessage();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.favorite, size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              const Text('健康建议', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _textController.text = '姿势纠正';
                          _sendMessage();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.accessibility, size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              const Text('姿势纠正', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 输入框
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: _buildTextInput(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 从AI响应中检测是否包含训练计划JSON
  Map<String, dynamic> _extractAndFixTrainingPlan(String aiResponse) {
    try {
      print('开始检测训练计划...');
      print('原始AI响应长度: ${aiResponse.length}');
      
      // 清理响应内容，移除多余的空白字符和换行
      String cleanedResponse = aiResponse.trim();
      
      // 尝试找到JSON对象的开始
      int startIndex = cleanedResponse.indexOf('{');
      if (startIndex == -1) {
        print('未找到JSON开始标记');
        return {'hasTrainingPlan': false, 'fixedResponse': aiResponse};
      }
      
      // 找到匹配的结束括号
      int braceCount = 0;
      int endIndex = -1;
      for (int i = startIndex; i < cleanedResponse.length; i++) {
        if (cleanedResponse[i] == '{') {
          braceCount++;
        } else if (cleanedResponse[i] == '}') {
          braceCount--;
          // 防止braceCount变为负数（处理多余的右括号）
          if (braceCount < 0) {
            braceCount = 0;
            continue; // 跳过这个多余的右括号，继续寻找
          }
          if (braceCount == 0) {
            endIndex = i + 1;
            break;
          }
        }
      }
      
      if (endIndex == -1) {
        print('未找到JSON结束标记');
        return {'hasTrainingPlan': false, 'fixedResponse': aiResponse};
      }
      
      final jsonString = cleanedResponse.substring(startIndex, endIndex);
      print('提取的JSON字符串长度: ${jsonString.length}');
      
      String sanitizedJson = jsonString;
      try {
        // 清理JSON字符串中的非法字符
        sanitizedJson = jsonString
            .replaceAll('\u0000', '')
            .replaceAll('\u0001', '')
            .replaceAll('\u0002', '')
            .replaceAll('\u0003', '')
            .replaceAll('\u0004', '')
            .replaceAll('\u0005', '')
            .replaceAll('\u0006', '')
            .replaceAll('\u0007', '')
            .replaceAll('\u0008', '')
            .replaceAll('\u0009', ' ')
            .replaceAll('\u000a', ' ')
            .replaceAll('\u000b', ' ')
            .replaceAll('\u000c', ' ')
            .replaceAll('\u000d', ' ')
            .replaceAll('\u000e', '')
            .replaceAll('\u000f', '')
            .replaceAll('\u0010', '')
            .replaceAll('\u0011', '')
            .replaceAll('\u0012', '')
            .replaceAll('\u0013', '')
            .replaceAll('\u0014', '')
            .replaceAll('\u0015', '')
            .replaceAll('\u0016', '')
            .replaceAll('\u0017', '')
            .replaceAll('\u0018', '')
            .replaceAll('\u0019', '')
            .replaceAll('\u001a', '')
            .replaceAll('\u001b', '')
            .replaceAll('\u001c', '')
            .replaceAll('\u001d', '')
            .replaceAll('\u001e', '')
            .replaceAll('\u001f', '');
        
        // 尝试修复常见的JSON格式问题
        sanitizedJson = sanitizedJson
            .replaceAll('，', ',')
            .replaceAll('。', '.')
            .replaceAll('；', ';')
            .replaceAll('：', ':')
            .replaceAll('"', '"')
            .replaceAll('"', '"')
            .replaceAll("'", "'")
            .replaceAll("'", "'");
        
        // 修复未闭合的引号问题
        sanitizedJson = _fixUnclosedQuotes(sanitizedJson);
        print('清理后的JSON字符串: $sanitizedJson');
        
        final trainingPlan = jsonDecode(sanitizedJson);
        print('解析后的训练计划: $trainingPlan');
        
        // 验证训练计划格式
        if (trainingPlan is Map && 
            trainingPlan.containsKey('plan') && 
            trainingPlan['plan'] is List) {
          print('检测到训练计划');
          // 返回原始响应，不进行修改
          return {'hasTrainingPlan': true, 'fixedResponse': aiResponse};
        } else {
          print('训练计划格式不正确');
          print('trainingPlan类型: ${trainingPlan.runtimeType}');
          print('是否包含plan字段: ${trainingPlan is Map && trainingPlan.containsKey('plan')}');
          if (trainingPlan is Map && trainingPlan.containsKey('plan')) {
            print('plan字段类型: ${trainingPlan['plan'].runtimeType}');
          }
          return {'hasTrainingPlan': false, 'fixedResponse': aiResponse};
        }
      } catch (jsonError) {
        print('JSON解析失败: $jsonError');
        print('原始JSON字符串: $jsonString');
        print('清理后的JSON字符串: $sanitizedJson');
        print('错误类型: ${jsonError.runtimeType}');
        
        // 尝试使用更宽松的解析方式
        try {
          // 简化验证，只要有plan字段就认为是训练计划
          if (jsonString.contains('"plan"') || jsonString.contains("'plan'")) {
            print('检测到包含plan字段的JSON');
            // 返回原始响应，不进行修改
            return {'hasTrainingPlan': true, 'fixedResponse': aiResponse};
          }
        } catch (e) {
          print('简化验证也失败: $e');
        }
        return {'hasTrainingPlan': false, 'fixedResponse': aiResponse};
      }
    } catch (e) {
      print('检测训练计划失败: $e');
      print('错误详情: ${e.toString()}');
      return {'hasTrainingPlan': false, 'fixedResponse': aiResponse};
    }
  }

  Widget _buildTextInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: '输入消息...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.send),
          color: const Color(0xFF4A90E2),
          onPressed: _sendMessage,
        ),
      ],
    );
  }
}