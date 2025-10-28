import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/vocabulary_record.m.dart';
import '../config/storage_config.dart';

/// 词汇数据服务
class VocabularyService {
  static final VocabularyService _instance = VocabularyService._internal();
  factory VocabularyService() => _instance;
  VocabularyService._internal();

  final Uuid _uuid = const Uuid();
  final StorageConfig _storageConfig = StorageConfig();
  
  /// 内存中的记录列表
  List<VocabularyRecord> _records = [];
  
  /// 获取数据存储目录（持久化存储）
  Future<String> get dataDirectory async {
    return await _storageConfig.persistentDataDirectory;
  }
  
  /// 获取音频目录（持久化存储）
  Future<String> get audioDirectory async {
    return await _storageConfig.audioDirectory;
  }
  
  /// 获取 metadata.json 文件路径（持久化存储）
  Future<String> get metadataFilePath async {
    return await _storageConfig.metadataFilePath;
  }
  
  /// 初始化服务，加载数据
  Future<void> initialize() async {
    await _loadMetadata();
  }
  
  /// 加载 metadata.json
  Future<void> _loadMetadata() async {
    try {
      final filePath = await metadataFilePath;
      final file = File(filePath);
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final recordsJson = json['records'] as List<dynamic>? ?? [];
        
        _records = recordsJson
            .map((item) => VocabularyRecord.fromJson(item as Map<String, dynamic>))
            .toList();
        
        // 按创建时间倒序排序
        _records.sort((a, b) => b.createTime.compareTo(a.createTime));
      } else {
        _records = [];
      }
    } catch (e) {
      print('加载元数据失败: $e');
      _records = [];
    }
  }
  
  /// 保存 metadata.json
  Future<void> _saveMetadata() async {
    try {
      final filePath = await metadataFilePath;
      final file = File(filePath);
      
      final json = {
        'version': '1.0',
        'records': _records.map((record) => record.toJson()).toList(),
      };
      
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      print('保存元数据失败: $e');
      rethrow;
    }
  }

  
  /// 根据ID获取记录
  VocabularyRecord? getRecordById(String id) {
    try {
      return _records.firstWhere((record) => record.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// 添加新记录
  Future<VocabularyRecord> addRecord({
    required String word,
    required String note,
    required String audioSourcePath,
    required int audioDuration,
  }) async {
    try {
      // 生成唯一ID
      final id = _uuid.v4();
      
      // 生成音频文件名
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final audioFileName = '${dateStr}_${now.millisecondsSinceEpoch}.m4a';
      
      // 复制音频文件到目标位置
      final audioDir = await audioDirectory;
      final targetAudioPath = '$audioDir/$audioFileName';
      final sourceFile = File(audioSourcePath);
      await sourceFile.copy(targetAudioPath);
      
      // 创建记录对象
      final record = VocabularyRecord(
        id: id,
        word: word,
        note: note,
        audioPath: 'audios/$audioFileName',
        audioDuration: audioDuration,
        createTime: now,
        updateTime: now,
      );
      
      // 添加到列表
      _records.insert(0, record);
      
      // 保存到文件
      await _saveMetadata();
      
      // 删除临时录音文件
      try {
        if (await sourceFile.exists()) {
          await sourceFile.delete();
        }
      } catch (e) {
        print('删除临时文件失败: $e');
      }
      
      return record;
    } catch (e) {
      print('添加记录失败: $e');
      rethrow;
    }
  }
  
  /// 更新记录
  Future<void> updateRecord(VocabularyRecord record) async {
    try {
      final index = _records.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        _records[index] = record.copyWith(updateTime: DateTime.now());
        await _saveMetadata();
      }
    } catch (e) {
      print('更新记录失败: $e');
      rethrow;
    }
  }
  
  /// 删除记录
  Future<void> deleteRecord(String id) async {
    try {
      final record = getRecordById(id);
      if (record == null) return;
      
      // 删除音频文件
      final dataDir = await dataDirectory;
      final audioFile = File('$dataDir/${record.audioPath}');
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      
      // 从列表中移除
      _records.removeWhere((r) => r.id == id);
      
      // 保存到文件
      await _saveMetadata();
    } catch (e) {
      print('删除记录失败: $e');
      rethrow;
    }
  }
  
  /// 获取所有记录
  List<VocabularyRecord> getAllRecords() {
    return List.unmodifiable(_records);
  }
  
  /// 搜索记录（搜索词汇和备注）
  List<VocabularyRecord> searchRecords(String keyword) {
    if (keyword.isEmpty) {
      return getAllRecords();
    }
    
    final lowerKeyword = keyword.toLowerCase();
    return _records.where((record) {
      return record.word.toLowerCase().contains(lowerKeyword) ||
             record.note.toLowerCase().contains(lowerKeyword);
    }).toList();
  }
  
  /// 按日期分组获取记录
  Map<String, List<VocabularyRecord>> getGroupedRecords() {
    final Map<String, List<VocabularyRecord>> grouped = {
      'today': [],
      'yesterday': [],
      'thisWeek': [],
      'thisMonth': [],
      'earlier': [],
    };
    
    for (final record in _records) {
      final groupKey = record.getDateGroupKey();
      grouped[groupKey]?.add(record);
    }
    
    // 移除空分组
    grouped.removeWhere((key, value) => value.isEmpty);
    
    return grouped;
  }
  
  /// 获取音频文件的完整路径
  Future<String> getAudioFilePath(String relativePath) async {
    final dataDir = await dataDirectory;
    return '$dataDir/$relativePath';
  }
  
  /// 重新录制音频
  Future<void> reRecordAudio({
    required String recordId,
    required String newAudioSourcePath,
    required int newAudioDuration,
  }) async {
    try {
      final record = getRecordById(recordId);
      if (record == null) return;
      
      // 删除旧音频文件
      final dataDir = await dataDirectory;
      final oldAudioFile = File('$dataDir/${record.audioPath}');
      if (await oldAudioFile.exists()) {
        await oldAudioFile.delete();
      }
      
      // 生成新音频文件名
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final todayRecords = _records.where((r) {
        final recordDate = r.createTime;
        return recordDate.year == now.year &&
               recordDate.month == now.month &&
               recordDate.day == now.day;
      }).toList();
      final sequence = (todayRecords.length + 1).toString().padLeft(3, '0');
      final audioFileName = '${dateStr}_$sequence.m4a';
      
      // 复制新音频文件
      final audioDir = await audioDirectory;
      final targetAudioPath = '$audioDir/$audioFileName';
      final sourceFile = File(newAudioSourcePath);
      await sourceFile.copy(targetAudioPath);
      
      // 更新记录
      final updatedRecord = record.copyWith(
        audioPath: 'audios/$audioFileName',
        audioDuration: newAudioDuration,
        updateTime: now,
      );
      
      await updateRecord(updatedRecord);
      
      // 删除临时录音文件
      try {
        if (await sourceFile.exists()) {
          await sourceFile.delete();
        }
      } catch (e) {
        print('删除临时文件失败: $e');
      }
    } catch (e) {
      print('重新录制音频失败: $e');
      rethrow;
    }
  }

  /// 批量导入记录（用于备份恢复）
  // Future<void> importRecords(List<VocabularyRecord> records) async {
  //   try {
  //     // 确保数据目录存在
  //     final dataDir = await dataDirectory;
  //     final dataDirFile = Directory(dataDir);
  //     if (!await dataDirFile.exists()) {
  //       await dataDirFile.create(recursive: true);
  //     }
      
  //     _records = List.from(records);
  //     await _saveMetadata();
  //   } catch (e) {
  //     print('批量导入记录失败: $e');
  //     rethrow;
  //   }
  // }

  /// 追加记录（用于备份导入）
  Future<void> appendRecords(List<VocabularyRecord> records) async {
    try {
      // 确保数据目录存在
      final dataDir = await dataDirectory;
      final dataDirFile = Directory(dataDir);
      if (!await dataDirFile.exists()) {
        await dataDirFile.create(recursive: true);
      }
      
      // 追加新记录到现有记录列表
      _records.addAll(records);
      
      // 按创建时间倒序排序
      _records.sort((a, b) => b.createTime.compareTo(a.createTime));
      
      await _saveMetadata();
    } catch (e) {
      print('追加记录失败: $e');
      rethrow;
    }
  }
}

