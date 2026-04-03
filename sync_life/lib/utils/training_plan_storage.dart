import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class TrainingPlanStorage {
  static const String _fileName = 'training_plan.json';
  static const String _backupFileName = 'training_plan_backup.json';

  // 获取本地文件路径
  static Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  // 获取备份文件路径
  static Future<String> _getBackupFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_backupFileName';
  }

  // 保存训练计划到本地文件（带备份机制）
  static Future<void> saveTrainingPlan(Map<String, dynamic> plan) async {
    try {
      final filePath = await _getFilePath();
      final backupFilePath = await _getBackupFilePath();
      final file = File(filePath);
      final backupFile = File(backupFilePath);

      // 如果文件已存在，先备份
      if (await file.exists()) {
        try {
          final existingContent = await file.readAsString();
          await backupFile.writeAsString(existingContent);
          print('已创建训练计划备份');
        } catch (e) {
          print('创建备份失败: $e');
        }
      }

      // 保存新数据
      await file.writeAsString(jsonEncode(plan));
      print('训练计划已保存到本地文件');
    } catch (e) {
      print('保存训练计划失败: $e');
      throw e;
    }
  }

  // 读取训练计划从本地文件（带恢复机制）
  static Future<Map<String, dynamic>?> loadTrainingPlan() async {
    try {
      final filePath = await _getFilePath();
      final backupFilePath = await _getBackupFilePath();
      final file = File(filePath);
      final backupFile = File(backupFilePath);

      // 尝试从主文件加载
      if (await file.exists()) {
        try {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            final plan = jsonDecode(contents);
            print('训练计划已从本地文件加载');
            return plan;
          }
        } catch (e) {
          print('主文件加载失败，尝试从备份恢复: $e');
        }
      }

      // 如果主文件失败或不存在，尝试从备份恢复
      if (await backupFile.exists()) {
        try {
          final backupContents = await backupFile.readAsString();
          if (backupContents.isNotEmpty) {
            final plan = jsonDecode(backupContents);
            // 恢复备份到主文件
            await file.writeAsString(backupContents);
            print('训练计划已从备份恢复');
            return plan;
          }
        } catch (e) {
          print('从备份恢复失败: $e');
        }
      }

      print('训练计划文件不存在或为空');
      return null;
    } catch (e) {
      print('加载训练计划失败: $e');
      return null;
    }
  }

  // 检查训练计划文件是否存在
  static Future<bool> exists() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      print('检查训练计划文件失败: $e');
      return false;
    }
  }

  // 删除训练计划文件（保留备份）
  static Future<void> delete() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        // 删除前先备份
        await saveTrainingPlan({});
        await file.delete();
        print('训练计划文件已删除，备份已保留');
      }
    } catch (e) {
      print('删除训练计划文件失败: $e');
    }
  }

  // 强制删除（包括备份）
  static Future<void> forceDelete() async {
    try {
      final filePath = await _getFilePath();
      final backupFilePath = await _getBackupFilePath();
      final file = File(filePath);
      final backupFile = File(backupFilePath);

      if (await file.exists()) {
        await file.delete();
      }
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      print('训练计划文件和备份已全部删除');
    } catch (e) {
      print('强制删除失败: $e');
    }
  }

  // 获取文件信息（用于调试）
  static Future<Map<String, dynamic>> getFileInfo() async {
    try {
      final filePath = await _getFilePath();
      final backupFilePath = await _getBackupFilePath();
      final file = File(filePath);
      final backupFile = File(backupFilePath);

      final info = <String, dynamic>{};

      if (await file.exists()) {
        final stat = await file.stat();
        info['main_file'] = {
          'exists': true,
          'size': stat.size,
          'modified': stat.modified,
        };
      } else {
        info['main_file'] = {'exists': false};
      }

      if (await backupFile.exists()) {
        final stat = await backupFile.stat();
        info['backup_file'] = {
          'exists': true,
          'size': stat.size,
          'modified': stat.modified,
        };
      } else {
        info['backup_file'] = {'exists': false};
      }

      return info;
    } catch (e) {
      print('获取文件信息失败: $e');
      return {};
    }
  }
}