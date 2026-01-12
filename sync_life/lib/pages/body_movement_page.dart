import 'package:flutter/material.dart';

class BodyMovementPage extends StatelessWidget {
  const BodyMovementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('身体运动状况'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Image(image: AssetImage('assets/background.png'), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 顶部统计卡片
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Card(
                        margin: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: const [
                              Text('静坐时长'),
                              SizedBox(height: 8),
                              Text('5.36h', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('-20% day over day', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        margin: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: const [
                              Text('运动时长'),
                              SizedBox(height: 8),
                              Text('6.26h', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('+33% day over day', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 时间轴卡片
                Card(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('时间轴', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTimePoint('B00', '6:05', '静坐'),
                            _buildTimePoint('9:36', '9:36', '身体保护'),
                            _buildTimePoint('12:12', '12:12', '锻炼'),
                            _buildTimePoint('13:00', '13:00', '慢跑'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 身体活动图
                Card(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('身体活动图', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F8FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.insert_chart_outlined, size: 48, color: Color(0xFF4A90E2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePoint(String time, String timeLabel, String activity) {
    return Column(
      children: [
        Text(time, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F8FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4A90E2), width: 2),
          ),
          child: Center(
            child: Text(timeLabel.split(':')[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Text(activity, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}