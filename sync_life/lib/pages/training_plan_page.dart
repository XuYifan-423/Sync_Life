import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_life/utils/training_plan_storage.dart';

class TrainingPlanPage extends StatefulWidget {
  const TrainingPlanPage({super.key});

  @override
  State<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends State<TrainingPlanPage> {
  Map<String, dynamic>? _trainingPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrainingPlan();
  }

  Future<void> _loadTrainingPlan() async {
    try {
      final trainingPlan = await TrainingPlanStorage.loadTrainingPlan();
      setState(() {
        _trainingPlan = trainingPlan;
        _isLoading = false;
      });
    } catch (e) {
      print('加载训练计划失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTrainingPlan(Map<String, dynamic> plan) async {
    try {
      await TrainingPlanStorage.saveTrainingPlan(plan);
      setState(() {
        _trainingPlan = plan;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('训练计划已保存')),
      );
    } catch (e) {
      print('保存训练计划失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败')),
      );
    }
  }

  void _editDayPlan(int dayIndex) {
    if (_trainingPlan == null || _trainingPlan!['plan'] == null) return;
    
    final dayPlan = _trainingPlan!['plan'][dayIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayPlanEditPage(
          dayPlan: dayPlan,
          onSave: (updatedPlan) {
            setState(() {
              _trainingPlan!['plan'][dayIndex] = updatedPlan;
            });
            _saveTrainingPlan(_trainingPlan!);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练计划'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trainingPlan == null || _trainingPlan!['plan'] == null
              ? _buildEmptyState()
              : _buildTrainingPlan(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无训练计划',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请在智能服务页面生成训练计划',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingPlan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_trainingPlan!['summary'] != null)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '训练计划总结',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _trainingPlan!['summary'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ...List.generate(_trainingPlan!['plan'].length, (index) {
            final dayPlan = _trainingPlan!['plan'][index];
            return _buildDayCard(dayPlan, index);
          }),
        ],
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> dayPlan, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${dayPlan['day']} (${dayPlan['date']})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editDayPlan(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(dayPlan['exercises'].length, (exerciseIndex) {
              final exercise = dayPlan['exercises'][exerciseIndex];
              return _buildExerciseItem(exercise);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${exercise['start_time']} - ${exercise['end_time']} · ${exercise['intensity']} · ${exercise['duration']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DayPlanEditPage extends StatefulWidget {
  final Map<String, dynamic> dayPlan;
  final Function(Map<String, dynamic>) onSave;

  const DayPlanEditPage({
    super.key,
    required this.dayPlan,
    required this.onSave,
  });

  @override
  State<DayPlanEditPage> createState() => _DayPlanEditPageState();
}

class _DayPlanEditPageState extends State<DayPlanEditPage> {
  late List<Map<String, dynamic>> _exercises;
  late List<Map<String, TextEditingController>> _exerciseControllers;

  @override
  void initState() {
    super.initState();
    _exercises = List<Map<String, dynamic>>.from(widget.dayPlan['exercises'] ?? []);
    
    // 初始化控制器，每个训练项目一个控制器组
    _exerciseControllers = _exercises.map((exercise) {
      return {
        'name': TextEditingController(text: exercise['name'] ?? ''),
        'start_time': TextEditingController(text: exercise['start_time'] ?? '08:00'),
        'end_time': TextEditingController(text: exercise['end_time'] ?? '08:30'),
        'intensity': TextEditingController(text: exercise['intensity'] ?? '中等'),
        'duration': TextEditingController(text: exercise['duration'] ?? '30分钟'),
      };
    }).toList();
  }

  @override
  void dispose() {
    for (var controllers in _exerciseControllers) {
      controllers.forEach((key, controller) {
        controller.dispose();
      });
    }
    super.dispose();
  }

  void _addExercise() {
    setState(() {
      _exercises.add({
        'name': '新训练项目',
        'start_time': '08:00',
        'end_time': '08:30',
        'intensity': '中等',
        'duration': '30分钟',
        'description': '',
      });
      _exerciseControllers.add({
        'name': TextEditingController(text: '新训练项目'),
        'start_time': TextEditingController(text: '08:00'),
        'end_time': TextEditingController(text: '08:30'),
        'intensity': TextEditingController(text: '中等'),
        'duration': TextEditingController(text: '30分钟'),
      });
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      // 释放控制器
      _exerciseControllers[index].forEach((key, controller) {
        controller.dispose();
      });
      _exerciseControllers.removeAt(index);
    });
  }

  void _save() {
    final updatedPlan = Map<String, dynamic>.from(widget.dayPlan);
    
    // 更新训练项目
    final updatedExercises = _exercises.asMap().entries.map((entry) {
      int index = entry.key;
      var exercise = entry.value;
      var controllers = _exerciseControllers[index];
      
      return {
        'name': controllers['name']?.text ?? exercise['name'],
        'start_time': controllers['start_time']?.text ?? exercise['start_time'],
        'end_time': controllers['end_time']?.text ?? exercise['end_time'],
        'intensity': controllers['intensity']?.text ?? exercise['intensity'],
        'duration': controllers['duration']?.text ?? exercise['duration'],
        'description': exercise['description'] ?? '',
      };
    }).toList();
    
    updatedPlan['exercises'] = updatedExercises;
    widget.onSave(updatedPlan);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑 ${widget.dayPlan['day']}'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '训练项目',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_exercises.length, (index) {
              return _buildExerciseEditCard(index);
            }),
            TextButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('添加训练项目'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseEditCard(int index) {
    final exercise = _exercises[index];
    final controllers = _exerciseControllers[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '项目 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeExercise(index),
                ),
              ],
            ),
            TextField(
              controller: controllers['name'],
              decoration: const InputDecoration(
                labelText: '训练名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '开始时间',
                      border: OutlineInputBorder(),
                    ),
                    controller: controllers['start_time'],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '结束时间',
                      border: OutlineInputBorder(),
                    ),
                    controller: controllers['end_time'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: '强度',
                border: OutlineInputBorder(),
              ),
              controller: controllers['intensity'],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: '时长',
                border: OutlineInputBorder(),
              ),
              controller: controllers['duration'],
            ),
          ],
        ),
      ),
    );
  }
}