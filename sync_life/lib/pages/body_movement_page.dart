import 'package:flutter/material.dart';

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

  // 模拟数据
  final Map<TimeRange, Map<String, dynamic>> _mockData = {
    TimeRange.day: {
      'steps': 8542,
      'calories': 320,
      'distance': 6.2,
      'activeTime': 75,
      'postures': [
        {'time': '06:00-08:30', 'type': '静坐', 'duration': '2.5h', 'color': Colors.blue},
        {'time': '08:30-09:15', 'type': '走路', 'duration': '45min', 'color': Colors.green},
        {'time': '09:15-12:00', 'type': '静坐', 'duration': '2.75h', 'color': Colors.blue},
        {'time': '12:00-13:00', 'type': '站立', 'duration': '1h', 'color': Colors.yellow},
        {'time': '13:00-13:30', 'type': '走路', 'duration': '30min', 'color': Colors.green},
        {'time': '13:30-17:00', 'type': '静坐', 'duration': '3.5h', 'color': Colors.blue},
        {'time': '17:00-18:00', 'type': '跑步', 'duration': '1h', 'color': Colors.red},
        {'time': '18:00-20:00', 'type': '站立', 'duration': '2h', 'color': Colors.yellow},
        {'time': '20:00-22:00', 'type': '静坐', 'duration': '2h', 'color': Colors.blue},
      ],
      'postureAngles': [
        {'time': '09:00-09:30', 'angle': '15°', 'status': '正常', 'color': Colors.green},
        {'time': '09:30-10:00', 'angle': '25°', 'status': '轻度异常', 'color': Colors.yellow},
        {'time': '10:00-10:30', 'angle': '18°', 'status': '正常', 'color': Colors.green},
        {'time': '10:30-11:00', 'angle': '32°', 'status': '严重异常', 'color': Colors.red},
        {'time': '11:00-11:30', 'angle': '20°', 'status': '正常', 'color': Colors.green},
        {'time': '14:00-14:30', 'angle': '28°', 'status': '轻度异常', 'color': Colors.yellow},
        {'time': '14:30-15:00', 'angle': '16°', 'status': '正常', 'color': Colors.green},
        {'time': '15:00-15:30', 'angle': '35°', 'status': '严重异常', 'color': Colors.red},
        {'time': '15:30-16:00', 'angle': '19°', 'status': '正常', 'color': Colors.green},
      ],
      'dataPoints': [
        {'time': '06:00', 'value': 200},
        {'time': '08:00', 'value': 1200},
        {'time': '10:00', 'value': 800},
        {'time': '12:00', 'value': 1500},
        {'time': '14:00', 'value': 900},
        {'time': '16:00', 'value': 1300},
        {'time': '18:00', 'value': 1600},
        {'time': '20:00', 'value': 1042},
      ],
    },
    TimeRange.week: {
      'steps': 52340,
      'calories': 2100,
      'distance': 38.5,
      'activeTime': 480,
      'postures': [
        {'day': '周一', 'sitting': '6.5h', 'standing': '3h', 'walking': '1.5h', 'running': '1h'},
        {'day': '周二', 'sitting': '7h', 'standing': '2.5h', 'walking': '1.5h', 'running': '0.5h'},
        {'day': '周三', 'sitting': '6h', 'standing': '3h', 'walking': '2h', 'running': '1h'},
        {'day': '周四', 'sitting': '7.5h', 'standing': '2h', 'walking': '1.5h', 'running': '0h'},
        {'day': '周五', 'sitting': '6.5h', 'standing': '2.5h', 'walking': '2h', 'running': '1h'},
        {'day': '周六', 'sitting': '4h', 'standing': '3h', 'walking': '3h', 'running': '2h'},
        {'day': '周日', 'sitting': '5h', 'standing': '4h', 'walking': '2h', 'running': '1h'},
      ],
      'postureAngles': [
        {'day': '周一', 'normal': '4h', 'mild': '2h', 'severe': '1h'},
        {'day': '周二', 'normal': '5h', 'mild': '1.5h', 'severe': '0.5h'},
        {'day': '周三', 'normal': '4.5h', 'mild': '2h', 'severe': '1h'},
        {'day': '周四', 'normal': '5h', 'mild': '2h', 'severe': '0.5h'},
        {'day': '周五', 'normal': '4h', 'mild': '2h', 'severe': '1.5h'},
        {'day': '周六', 'normal': '6h', 'mild': '1h', 'severe': '0h'},
        {'day': '周日', 'normal': '7h', 'mild': '1h', 'severe': '0h'},
      ],
      'dataPoints': [
        {'day': '周一', 'value': 7800},
        {'day': '周二', 'value': 8200},
        {'day': '周三', 'value': 6500},
        {'day': '周四', 'value': 9100},
        {'day': '周五', 'value': 8500},
        {'day': '周六', 'value': 5800},
        {'day': '周日', 'value': 6440},
      ],
    },
    TimeRange.month: {
      'steps': 210560,
      'calories': 8400,
      'distance': 154.2,
      'activeTime': 1920,
      'postures': [
        {'week': '第1周', 'sitting': '42h', 'standing': '18h', 'walking': '10h', 'running': '5h'},
        {'week': '第2周', 'sitting': '40h', 'standing': '20h', 'walking': '12h', 'running': '6h'},
        {'week': '第3周', 'sitting': '38h', 'standing': '22h', 'walking': '14h', 'running': '4h'},
        {'week': '第4周', 'sitting': '45h', 'standing': '16h', 'walking': '10h', 'running': '3h'},
      ],
      'postureAngles': [
        {'week': '第1周', 'normal': '25h', 'mild': '10h', 'severe': '5h'},
        {'week': '第2周', 'normal': '28h', 'mild': '8h', 'severe': '4h'},
        {'week': '第3周', 'normal': '22h', 'mild': '12h', 'severe': '6h'},
        {'week': '第4周', 'normal': '30h', 'mild': '6h', 'severe': '4h'},
      ],
      'dataPoints': [
        {'week': '第1周', 'value': 62000},
        {'week': '第2周', 'value': 58000},
        {'week': '第3周', 'value': 48560},
        {'week': '第4周', 'value': 42000},
      ],
    },
  };

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
                      const SizedBox(width: 12),
                      _buildTimeRangeButton('周', TimeRange.week),
                      const SizedBox(width: 12),
                      _buildTimeRangeButton('月', TimeRange.month),
                    ],
                  ),
                ),

                // 统计卡片
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard('步数', '${_mockData[_selectedRange]!['steps']}', Icons.directions_walk, Colors.blue),
                      _buildStatCard('卡路里', '${_mockData[_selectedRange]!['calories']}', Icons.local_fire_department, Colors.orange),
                      _buildStatCard('距离', '${_mockData[_selectedRange]!['distance']}km', Icons.map, Colors.green),
                      _buildStatCard('活动时间', '${_mockData[_selectedRange]!['activeTime']}min', Icons.access_time, Colors.purple),
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
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200, // Set fixed height for the posture distribution
                        child: SingleChildScrollView(
                          child: _buildPostureData(),
                        ),
                      ),
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
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: _buildActivityChart(),
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
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200, // Set fixed height for the posture angle monitoring
                        child: SingleChildScrollView(
                          child: _buildPostureAngleData(),
                        ),
                      ),
                    ],
                  ),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostureData() {
    List<dynamic> postures = _mockData[_selectedRange]!['postures'];
    
    if (_selectedRange == TimeRange.day) {
      // 日视图：时间轴形式
      return Column(
        children: postures.map((posture) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(posture['time'], style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: posture['color'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(posture['type'], style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(posture['duration'], style: const TextStyle(fontSize: 12, color: Colors.white)),
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
            DataColumn(label: Text('静坐')),
            DataColumn(label: Text('站立')),
            DataColumn(label: Text('走路')),
            DataColumn(label: Text('跑步')),
          ],
          rows: postures.map((posture) {
            return DataRow(cells: [
              DataCell(Text(_selectedRange == TimeRange.week ? posture['day'] : posture['week'])),
              DataCell(Text(posture['sitting'])),
              DataCell(Text(posture['standing'])),
              DataCell(Text(posture['walking'])),
              DataCell(Text(posture['running'])),
            ]);
          }).toList(),
        ),
      );
    }
  }

  Widget _buildActivityChart() {
    List<dynamic> dataPoints = _mockData[_selectedRange]!['dataPoints'];
    
    // 找出最大值
    double maxValue = 0;
    for (var point in dataPoints) {
      if (point['value'] > maxValue) {
        maxValue = point['value'].toDouble();
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: dataPoints.asMap().entries.map((entry) {
        int index = entry.key;
        var point = entry.value;
        double height = (point['value'] / maxValue) * 150;
        
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
            const SizedBox(height: 8),
            Text(
              _selectedRange == TimeRange.day ? point['time'] : 
              _selectedRange == TimeRange.week ? point['day'] : point['week'],
              style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPostureAngleData() {
    List<dynamic> postureAngles = _mockData[_selectedRange]!['postureAngles'];
    
    if (_selectedRange == TimeRange.day) {
      // 日视图：时间轴形式
      return Column(
        children: postureAngles.map((angle) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(angle['time'], style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: angle['color'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(angle['status'], style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(angle['angle'], style: const TextStyle(fontSize: 12, color: Colors.white)),
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
            DataColumn(label: Text('正常')),
            DataColumn(label: Text('轻度异常')),
            DataColumn(label: Text('严重异常')),
          ],
          rows: postureAngles.map((angle) {
            return DataRow(cells: [
              DataCell(Text(_selectedRange == TimeRange.week ? angle['day'] : angle['week'])),
              DataCell(Text(angle['normal'])),
              DataCell(Text(angle['mild'])),
              DataCell(Text(angle['severe'])),
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
}