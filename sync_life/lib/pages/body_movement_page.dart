import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sync_life/config/api_config.dart';
import 'package:sync_life/utils/training_plan_storage.dart';

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
  Map<String, dynamic>? _trainingPlan;

  @override
  void initState() {
    super.initState();
    _fetchBodyMovementData();
    _loadTrainingPlan();
  }

  Widget _buildTrainingPlanWindow() {
    if (_trainingPlan == null) {
      print('训练计划为空，无法构建窗口');
      return SizedBox();
    }

    if (!_trainingPlan!.containsKey('plan')) {
      print('训练计划缺少plan键');
      return SizedBox();
    }

    final plan = _trainingPlan!['plan'];
    if (plan == null) {
      print('训练计划数据为空');
      return SizedBox();
    }

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    print('今天日期: $todayStr');
    print('训练计划数据: $plan');

    if (plan is! List) {
      print('训练计划格式错误，期望是List');
      return SizedBox();
    }

    final planList = plan as List;
    print('训练计划列表长度: ${planList.length}');

    // 先尝试找今天的训练计划
    final todayPlan = planList.firstWhere(
      (dayPlan) {
        if (dayPlan is Map) {
          final date = dayPlan['date'];
          print('检查日期: $date vs $todayStr');
          return date == todayStr;
        }
        return false;
      },
      orElse: () => null
    );

    print('找到今日计划: $todayPlan');

    // 如果没有今天的计划，显示第一个可用的计划
    final displayPlan = todayPlan ?? (planList.isNotEmpty ? planList[0] : null);
    
    if (displayPlan == null) {
      print('没有可用的训练计划');
      return SizedBox();
    }

    if (displayPlan['exercises'] != null) {
      final exercises = displayPlan['exercises'] as List;
      print('训练项目数量: ${exercises.length}');
      
      if (exercises.isNotEmpty) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16, top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 74, 226, 81), Color(0xFF357ABD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayPlan == todayPlan ? '今日训练计划' : '训练计划 (${displayPlan['date'] ?? '未知日期'})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (displayPlan != null && displayPlan.containsKey('day'))
                          Text(
                            displayPlan['day'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...exercises.map((exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise['name'] ?? '未知训练',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${exercise['start_time'] ?? '--:--'} - ${exercise['end_time'] ?? '--:--'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        );
        }
      } else {
        print('训练计划中无训练项目');
      }
    
    return SizedBox();
  }

  Future<void> _loadTrainingPlan() async {
    try {
      final trainingPlan = await TrainingPlanStorage.loadTrainingPlan();
      print('加载训练计划: $trainingPlan');
      if (trainingPlan != null) {
        print('训练计划结构: ${trainingPlan.keys}');
        if (trainingPlan.containsKey('plan')) {
          print('计划数据: ${trainingPlan['plan']}');
        }
        if (mounted) {
          setState(() {
            _trainingPlan = trainingPlan;
          });
        }
      } else {
        print('训练计划为空');
      }
    } catch (e) {
      print('加载训练计划失败: $e');
    }
  }

  Future<void> _fetchBodyMovementData() async {
    if (!mounted) return;
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

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _error = '网络错误: $e';
      });
    } finally {
      if (!mounted) return;
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
                      // 训练计划显示窗口（仅在日视图显示）
                      _selectedRange == TimeRange.day && _trainingPlan != null ? _buildTrainingPlanWindow() : SizedBox(),

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
                        '点击按钮生成相应报告（支持小红书分享），报告将通过智能体服务发送给您',
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
    // 根据报告类型切换时间范围
    TimeRange targetRange;
    if (reportType == '日报') {
      targetRange = TimeRange.day;
    } else if (reportType == '周报') {
      targetRange = TimeRange.week;
    } else if (reportType == '月报') {
      targetRange = TimeRange.month;
    } else {
      targetRange = _selectedRange;
    }

    // 如果当前时间范围不是目标范围，先切换
    if (_selectedRange != targetRange) {
      setState(() {
        _selectedRange = targetRange;
      });
      // 重新获取数据，数据加载完成后会自动生成报告
      _fetchBodyMovementDataAndGenerateReport(reportType);
      return;
    }

    // 如果已经是目标时间范围，直接生成报告
    _generateReportWithCurrentData(reportType);
  }

  Future<void> _fetchBodyMovementDataAndGenerateReport(String reportType) async {
    if (!mounted) return;
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _bodyMovementData = jsonDecode(response.body);
          _isLoading = false;
        });
        // 数据加载完成后生成报告
        _generateReportWithCurrentData(reportType);
      } else {
        setState(() {
          _error = '服务器错误: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '网络错误: $e';
        _isLoading = false;
      });
    }
  }

  void _generateReportWithCurrentData(String reportType) {
    if (_bodyMovementData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无数据，无法生成报告')),
      );
      return;
    }

    // 构建报告数据
    String reportPrompt = '请根据以下数据生成一份适合在社交媒体（如小红书）上分享的$reportType：\n\n';
    
    // 添加时间范围
    final now = DateTime.now();
    String timeRange = '';
    if (reportType == '日报') {
      timeRange = '${now.month}月${now.day}日';
      reportPrompt += '日期：$timeRange\n\n';
    } else if (reportType == '周报') {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      timeRange = '${weekStart.month}月${weekStart.day}日-${weekEnd.month}月${weekEnd.day}日';
      reportPrompt += '时间范围：$timeRange\n\n';
    } else if (reportType == '月报') {
      timeRange = '${now.year}年${now.month}月';
      reportPrompt += '时间范围：$timeRange\n\n';
    }

    // 添加姿态数据
    if (_bodyMovementData!['posture_distribution'] != null) {
      reportPrompt += '姿态分布：\n';
      for (var item in _bodyMovementData!['posture_distribution']) {
        reportPrompt += '- ${item['name']}：${item['value']}% (${item['hours']})\n';
      }
      reportPrompt += '\n';
    }

    // 添加活动数据
    reportPrompt += '活动数据：\n';
    reportPrompt += '- 步数：${_bodyMovementData!['steps'] ?? 0}步\n';
    reportPrompt += '- 消耗卡路里：${_bodyMovementData!['calories'] ?? 0}kcal\n';
    reportPrompt += '- 运动距离：${_bodyMovementData!['distance'] ?? 0}km\n';
    reportPrompt += '- 活动时长：${_bodyMovementData!['active_time'] ?? 0}分钟\n';
    reportPrompt += '\n';

    // 添加详细的请求说明
    reportPrompt += '请生成一份适合社交媒体（如小红书）上分享的$reportType，要求如下：\n\n';
    reportPrompt += '【重要】直接用中文输出报告内容，不要输出思考过程、分析过程或任何额外说明！\n\n';
    reportPrompt += '1. 【隐私保护】不要提及任何个人隐私信息（如年龄、体重、身高等）\n';
    reportPrompt += '2. 【排版美观】使用emoji表情和分段，让内容清晰易读\n';
    reportPrompt += '3. 【内容结构】包含以下部分：\n';
    reportPrompt += '   - 数据亮点：突出表现好的数据\n';
    reportPrompt += '   - 健康洞察：分析姿态和运动情况\n';
    reportPrompt += '   - 改善建议：给出实用的改善建议\n';
    reportPrompt += '   - 激励语：一句正能量的话\n';
    reportPrompt += '4. 【风格要求】轻松活泼，适合年轻人阅读\n';
    reportPrompt += '5. 【字数控制】控制在200-300字之间\n';
    reportPrompt += '6. 【话题标签】在最后添加2-3个相关话题标签（如#健康生活 #运动打卡）\n';
    reportPrompt += '\n请直接输出报告内容：\n';

    // 使用回调函数传递报告数据
    if (widget.onGenerateReport != null) {
      widget.onGenerateReport!(reportPrompt);
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
