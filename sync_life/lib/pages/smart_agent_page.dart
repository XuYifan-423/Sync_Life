import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math'; // 添加dart:math库，用于sin函数
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

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
    _processMessageWithN8N(messageText);
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
      print('开始调用N8N API');
      print('API URL: ${ApiConfig.n8nUrl}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.n8nUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': _userId,
          'message': messageText,
          'session_id': _sessionId,
          'type': 'text',
        }),
      );
      
      print('API响应状态码: ${response.statusCode}');
      print('API响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('解析后的响应数据: $data');
        String aiResponse = data['response'] ?? '抱歉，我无法理解您的问题，请尝试换一种方式提问。';
        
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
            RichText(
              text: TextSpan(
                children: _parseMessageText(message.text),
              ),
            ),
            if (message.hasCalendarOption) ...[
              const SizedBox(height: 12),
              const Text(
                '是否需要将训练计划写入日历？',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [                  ElevatedButton(
                    onPressed: () {
                      // 写入日历逻辑
                      if (mounted) {
                        setState(() {
                          _messages.add(Message(
                            text: '训练计划已成功写入日历！',
                            isUser: false,
                            timestamp: DateTime.now(),
                          ));
                        });
                        _saveMessages();
                        _scrollToBottom();
                      }
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
                    child: const Text('是', style: TextStyle(fontSize: 12)),
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
                              const Icon(Icons.calendar_month, size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              const Text('制定训练计划', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _textController.text = '推荐健康餐馆';
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
                              const Icon(Icons.restaurant, size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              const Text('健康餐馆', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _textController.text = '小红书分享';
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
                              const Icon(Icons.share, size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              const Text('小红书分享', style: TextStyle(fontSize: 12, color: Colors.black)),
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