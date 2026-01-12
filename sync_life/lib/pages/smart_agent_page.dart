import 'package:flutter/material.dart';

class SmartAgentPage extends StatelessWidget {
  const SmartAgentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能体服务'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Image(image: AssetImage('assets/background.png'), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 智能提示卡片
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('9:56', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F8FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '检测到您已经连续20min腰椎45度倾斜，直起身来，气质更进一步哦～',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '小智还可以为您提供相关健康知识，制定相关针刺练喜技写入日历，有需要请告诉我～',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 功能按钮
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFunctionButton('制定训练计划'),
                  _buildFunctionButton('寻找餐厅'),
                  _buildFunctionButton('小红书分享'),
                ],
              ),
            ),
            // 输入框
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.mic),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '发消息或按住说话...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: const Color(0xFF4A90E2),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}