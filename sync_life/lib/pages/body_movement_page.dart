import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sync_life/config/api_config.dart';

// 时间范围
enum TimeRange { day, week, month }

class BodyMovementPage extends StatefulWidget {
  final Function(String)? onGenerateReport;

  const BodyMovementPage({super.key, this.onGenerateReport});

  @override
  State<BodyMovementPage> createState() => _BodyMovementPageState();
}

class _BodyMovementPageState extends State<BodyMovementPage> {
  TimeRange _selectedRange = TimeRange.day;
  Map<String, dynamic>? _bodyMovementData;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBodyMovementData();
  }

  Future<void> _fetchBodyMovementData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String timeRangeStr = _selectedRange.toString().split('.').last;
      final response = await http.post(
        Uri.parse(ApiConfig.bodyMovementUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 1, 'time_range': timeRangeStr}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _bodyMovementData = jsonDecode(response.body);
        });
      } else {
        setState(() {
          _error = '服务器错误: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络错误: $e';
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
      appBar: AppBar(
        title: const Text('身体运动状况'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Image(image: AssetImage('assets/background.png'), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 时间范围选择器
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildTimeRangeButton('日', TimeRange.day),
                      SizedBox(width: 12),
                      _buildTimeRangeButton('周', TimeRange.week),
                      SizedBox(width: 12),
                      _buildTimeRangeButton('月', TimeRange.month),
                    ],
                  ),
                ),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ),

                if (!_isLoading && _error == null && _bodyMovementData != null)
                  Column(
                    children: [
                      // 统计卡片
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatCard('步数', '${_bodyMovementData!['steps']}', Icons.directions_walk, Colors.blue),
                            _buildStatCard('卡路里', '${_bodyMovementData!['calories']}', Icons.local_fire_department, Colors.orange),
                            _buildStatCard('距离', '${_bodyMovementData!['distance']}km', Icons.map, Colors.green),
                            _buildStatCard('活动时间', '${_bodyMovementData!['active_time']}min', Icons.access_time, Colors.purple),
                          ],
                        ),
                      ),

                      // 姿态数据
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
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
                            Text(
                              _selectedRange == TimeRange.day ? '今日姿态分布' : 
                              _selectedRange == TimeRange.week ? '本周姿态分布' : '本月姿态分布',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              height: 200, // Set fixed height for the posture distribution
                              child: SingleChildScrollView(
                                child: _buildPostureDataWithApi(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 姿态占比
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
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
                            Text(
                              _selectedRange == TimeRange.day ? '今日姿态占比' : 
                              _selectedRange == TimeRange.week ? '本周姿态占比' : '本月姿态占比',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),
                            _buildPostureDistributionChartWithApi(),
                          ],
                        ),
                      ),

                      // 活动图表
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
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
                            Text(
                              _selectedRange == TimeRange.day ? '今日活动趋势' : 
                              _selectedRange == TimeRange.week ? '本周活动趋势' : '本月活动趋势',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 20),
                            SizedBox(
                              height: 200,
                              child: _buildActivityChartWithApi(),
                            ),
                          ],
                        ),
                      ),

                      // 姿态角度监测
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
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
                            Text(
                              _selectedRange == TimeRange.day ? '今日前俯角监测' : 
                              _selectedRange == TimeRange.week ? '本周前俯角监测' : '本月前俯角监测',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              height: 200, // Set fixed height for the posture angle monitoring
                              child: SingleChildScrollView(
                                child: _buildPostureAngleDataWithApi(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // 报告生成按钮
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
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
                      const Text(
                        '生成报告',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _generateReport('日报'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('生成日报'),
                          ),
                          ElevatedButton(
                            onPressed: () => _generateReport('周报'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('生成周报'),
                          ),
                          ElevatedButton(
                            onPressed: () => _generateReport('月报'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('生成月报'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      const Text(
                        '点击按钮生成相应报告，报告将通过智能体服务发送给您',
                        style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // 底部空间，确保内容不被底部导航栏遮挡
                SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, TimeRange range) {
    bool isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRange = range;
        });
        _fetchBodyMovementData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF757575),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
            SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostureDataWithApi() {
    if (_bodyMovementData == null || _bodyMovementData!['postures'] == null) {
      return const Center(child: Text('暂无姿态数据'));
    }
    
    List<dynamic> postures = _bodyMovementData!['postures'];
    
    if (postures.isEmpty) {
      return const Center(child: Text('暂无姿态数据'));
    }
    
    if (_selectedRange == TimeRange.day) {
      // 日视图：时间轴形式
      return Column(
        children: postures.map((posture) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 100,
                  padding: const EdgeInsets.only(left: 0),
                  child: Text(posture['time'] ?? '', style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse((posture['color'] ?? '#4A90E2').replaceAll('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(posture['type'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(posture['duration'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      // 周/月视图：表格形式
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('时间')),
            DataColumn(label: Text('静坐(h)')),
            DataColumn(label: Text('站立(h)')),
            DataColumn(label: Text('走路(h)')),
            DataColumn(label: Text('跑步(h)')),
            DataColumn(label: Text('躺卧(h)')),
          ],
          rows: postures.map((posture) {
            return DataRow(cells: [
              DataCell(Text(_selectedRange == TimeRange.week ? (posture['date'] ?? '') : (posture['week'] ?? ''))),
              DataCell(Text(posture['sitting'] ?? '0')),
              DataCell(Text(posture['standing'] ?? '0')),
              DataCell(Text(posture['walking'] ?? '0')),
              DataCell(Text(posture['running'] ?? '0')),
              DataCell(Text(posture['lying'] ?? '0')),
            ]);
          }).toList(),
        ),
      );
    }
  }

  Widget _buildActivityChartWithApi() {
    if (_bodyMovementData == null || _bodyMovementData!['activity_trend'] == null) {
      return const Center(child: Text('暂无活动趋势数据'));
    }
    
    List<dynamic> activityTrend = _bodyMovementData!['activity_trend'];
    
    if (activityTrend.isEmpty) {
      return const Center(child: Text('暂无活动趋势数据'));
    }
    
    // 找出最大步数用于计算高度
    int maxSteps = 0;
    for (var item in activityTrend) {
      int steps = item['steps'] ?? 0;
      if (steps > maxSteps) {
        maxSteps = steps;
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: activityTrend.map((item) {
        int steps = item['steps'] ?? 0;
        // 根据步数计算高度，最大高度150，最小高度5
        double height = maxSteps > 0 ? (steps / maxSteps) * 145 + 5 : 5;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['label'] ?? '',
              style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPostureAngleDataWithApi() {
    if (_bodyMovementData == null || _bodyMovementData!['posture_angles'] == null) {
      return const Center(child: Text('暂无姿态角度数据'));
    }
    
    List<dynamic> postureAngles = _bodyMovementData!['posture_angles'];
    
    if (postureAngles.isEmpty) {
      return const Center(child: Text('暂无姿态角度数据'));
    }
    
    if (_selectedRange == TimeRange.day) {
      // 日视图：时间轴形式
      return Column(
        children: postureAngles.map((angle) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 100,
                  padding: const EdgeInsets.only(left: 0),
                  child: Text(angle['time'] ?? '', style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse((angle['color'] ?? '#4A90E2').replaceAll('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(angle['status'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(angle['angle'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      // 周/月视图：表格形式
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('时间')),
            DataColumn(label: Text('正常(h)')),
            DataColumn(label: Text('轻微异常(h)')),
            DataColumn(label: Text('严重异常(h)')),
          ],
          rows: postureAngles.map((angle) {
            return DataRow(cells: [
              DataCell(Text(_selectedRange == TimeRange.week ? (angle['date'] ?? '') : (angle['week'] ?? ''))),
              DataCell(Text(angle['normal'] ?? '0')),
              DataCell(Text(angle['mild'] ?? '0')),
              DataCell(Text(angle['severe'] ?? '0')),
            ]);
          }).toList(),
        ),
      );
    }
  }

  // 生成报告
  void _generateReport(String reportType) {
    // 使用回调函数通知父组件切换到智能服务页面
    if (widget.onGenerateReport != null) {
      widget.onGenerateReport!(reportType);
    }
  }

  Widget _buildPostureDistributionChartWithApi() {
    if (_bodyMovementData == null || _bodyMovementData!['posture_distribution'] == null) {
      return const Center(child: Text('暂无姿态分布数据'));
    }
    
    List<dynamic> distribution = _bodyMovementData!['posture_distribution'];
    
    if (distribution.isEmpty) {
      return const Center(child: Text('暂无姿态分布数据'));
    }
    
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: Container(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: PieChartPainter(distribution),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: distribution.map((item) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(int.parse((item['color'] ?? '#4A90E2').replaceAll('#', '0xFF'))),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(item['name'] ?? '', style: const TextStyle(fontSize: 14)),
                      SizedBox(width: 8),
                      Text('${item['value'] ?? 0}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text(item['hours'] ?? '0h', style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

}

class PieChartPainter extends CustomPainter {
  final List<dynamic> data;
  
  PieChartPainter(this.data);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data == null || data.isEmpty) {
      return;
    }
    
    double centerX = size.width / 2;
    double centerY = size.height / 2;
    double radius = min(centerX, centerY) - 20;
    
    double total = 0;
    for (var item in data) {
      if (item != null && item['value'] != null) {
        total += item['value'];
      }
    }
    
    if (total == 0) {
      return;
    }
    
    double currentAngle = -pi / 2; // 从顶部开始
    
    for (var item in data) {
      if (item != null && item['value'] != null && item['color'] != null) {
        double angle = (item['value'] / total) * 2 * pi;
        
        Paint paint = Paint()..color = Color(int.parse((item['color'] ?? '#4A90E2').replaceAll('#', '0xFF')));
        
        canvas.drawArc(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
          currentAngle,
          angle,
          true,
          paint,
        );
        
        currentAngle += angle;
      }
    }
    
    // 绘制中心圆
    Paint centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(centerX, centerY), radius * 0.6, centerPaint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
