import 'dart:io';
import 'dart:convert';
import '../models/vocabulary_record.m.dart';
import '../services/vocabulary_service.dart';
import '../config/storage_config.dart';
import 'package:fluttertoast/fluttertoast.dart';
/// 备份服务
class BackupService {
  final VocabularyService _vocabularyService = VocabularyService();
  final StorageConfig _storageConfig = StorageConfig();

  /// 导出数据到指定目录
  Future<void> exportData(String exportPath) async {
    try {
      final exportDir = Directory(exportPath);
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDir = Directory('$exportPath/yuji_backup_$timestamp');
      await backupDir.create(recursive: true);

      final records = _vocabularyService.getAllRecords();
      
      await _exportMetadata(backupDir.path, records);
      await _exportAudioFiles(backupDir.path, records);

      print('数据导出完成: ${backupDir.path}');
    } catch (e) {
      print('导出数据失败: $e');
      rethrow;
    }
  }

  /// 导出数据到默认备份目录（持久化存储）
  Future<String> exportToDefaultBackup() async {
    try {
      final backupDir = await _storageConfig.backupDirectory;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '$backupDir/yuji_backup_$timestamp';
      
      await exportData(backupPath);
      return backupPath;
    } catch (e) {
      print('导出到默认备份目录失败: $e');
      rethrow;
    }
  }

  /// 从指定目录导入数据（追加模式）
  Future<void> importData(String importPath) async {
    try {
      final backupDir = await _findBackupDirectory(importPath);
      if (backupDir == null) {
        throw Exception('未找到有效的备份目录');
      }

      final backupRecords = await _importMetadata(backupDir.path);
      final existingRecords = _vocabularyService.getAllRecords();
      final existingIds = existingRecords.map((r) => r.id).toSet();
      
      // 过滤出新记录（ID不存在的记录）
      final newRecords = backupRecords.where((record) => !existingIds.contains(record.id)).toList();
      
      if (newRecords.isEmpty) {
        print('没有新数据需要导入');
        return;
      }

      await _vocabularyService.appendRecords(newRecords);
      await _importAudioFiles(backupDir.path, newRecords);

      Fluttertoast.showToast(msg: '数据导入成功，新增 ${newRecords.length} 条记录');
    } catch (e) {
      print('导入数据失败: $e');
      rethrow;
    }
  }

  /// 导出元数据
  Future<void> _exportMetadata(String backupPath, List<VocabularyRecord> records) async {
    final metadata = {
      'version': '1.0',
      'exportTime': DateTime.now().toIso8601String(),
      'recordCount': records.length,
      'records': records.map((record) => record.toJson()).toList(),
    };

    final metadataFile = File('$backupPath/metadata.json');
    await metadataFile.writeAsString(jsonEncode(metadata));
  }

  /// 导出音频文件
  Future<void> _exportAudioFiles(String backupPath, List<VocabularyRecord> records) async {
    final audioDir = Directory('$backupPath/audios');
    await audioDir.create(recursive: true);
    final dataDir = await _vocabularyService.dataDirectory;

    for (final record in records) {
      final sourcePath = '$dataDir/${record.audioPath}';
      final sourceFile = File(sourcePath);
      
      if (await sourceFile.exists()) {
        final fileName = record.audioPath.split('/').last;
        await sourceFile.copy('${audioDir.path}/$fileName');
      }
    }
  }

  /// 查找备份目录
  Future<Directory?> _findBackupDirectory(String importPath) async {
    final normalizedPath = importPath.trim();
    final importDir = Directory(normalizedPath);
    
    if (!await importDir.exists()) {
      throw Exception('导入路径不存在: $normalizedPath');
    }

    // 检查当前目录是否就是备份目录
    if (normalizedPath.contains('yuji_backup_')) {
      final metadataFile = File('$normalizedPath/metadata.json');
      if (await metadataFile.exists()) {
        return importDir;
      } else {
        final entries = await importDir.list().toList();
        final fileNames = entries.map((e) => e.path.split('/').last).join(', ');
        throw Exception('选择的目录不是有效的备份目录。目录内容: $fileNames');
      }
    }

    // 查找 yuji_backup_ 开头的子目录
    final entries = await importDir.list().toList();
    for (final entry in entries) {
      if (entry is Directory && entry.path.contains('yuji_backup_')) {
        return entry;
      }
    }

    final subDirs = entries.where((e) => e is Directory).map((e) => e.path.split('/').last).join(', ');
    throw Exception('未找到备份目录。请选择包含 yuji_backup_ 开头的目录。当前目录内容: $subDirs');
  }

  /// 导入元数据
  Future<List<VocabularyRecord>> _importMetadata(String backupPath) async {
    final metadataFile = File('$backupPath/metadata.json');
    if (!await metadataFile.exists()) {
      final backupDir = Directory(backupPath);
      if (await backupDir.exists()) {
        final entries = await backupDir.list().toList();
        final fileNames = entries.map((e) => e.path.split('/').last).join(', ');
        throw Exception('未找到元数据文件。备份目录内容: $fileNames');
      } else {
        throw Exception('备份目录不存在: $backupPath');
      }
    }

    try {
      final content = await metadataFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final recordsJson = json['records'] as List<dynamic>;

      return recordsJson
          .map((item) => VocabularyRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('解析元数据文件失败: $e');
    }
  }

  /// 导入音频文件
  Future<void> _importAudioFiles(String backupPath, List<VocabularyRecord> records) async {
    final audioDir = Directory('$backupPath/audios');
    
    if (!await audioDir.exists()) {
      throw Exception('未找到音频文件目录: ${audioDir.path}');
    }

    final targetAudioDir = await _vocabularyService.audioDirectory;
    final targetDir = Directory(targetAudioDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    for (final record in records) {
      final fileName = record.audioPath.split('/').last;
      final sourceFile = File('${audioDir.path}/$fileName');
      
      if (await sourceFile.exists()) {
        try {
          await sourceFile.copy('$targetAudioDir/$fileName');
        } catch (e) {
          print('复制音频文件失败: $fileName, 错误: $e');
        }
      }
    }
  }


}
