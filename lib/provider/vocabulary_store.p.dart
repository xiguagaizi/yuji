import 'package:flutter/material.dart';
import '../models/vocabulary_record.m.dart';
import '../services/vocabulary_service.dart';

/// 词汇数据状态管理
class VocabularyStore extends ChangeNotifier {
  final VocabularyService _service = VocabularyService();
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 初始化服务
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _service.initialize();
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 获取所有记录
  List<VocabularyRecord> getAllRecords() {
    return _service.getAllRecords();
  }

  /// 获取分组记录
  Map<String, List<VocabularyRecord>> getGroupedRecords() {
    return _service.getGroupedRecords();
  }

  /// 搜索记录
  List<VocabularyRecord> searchRecords(String keyword) {
    return _service.searchRecords(keyword);
  }

  /// 根据ID获取记录
  VocabularyRecord? getRecordById(String id) {
    return _service.getRecordById(id);
  }

  /// 添加记录
  Future<VocabularyRecord> addRecord({
    required String word,
    required String note,
    required String audioSourcePath,
    required int audioDuration,
  }) async {
    final record = await _service.addRecord(
      word: word,
      note: note,
      audioSourcePath: audioSourcePath,
      audioDuration: audioDuration,
    );
    notifyListeners();
    return record;
  }

  /// 更新记录
  Future<void> updateRecord(VocabularyRecord record) async {
    await _service.updateRecord(record);
    notifyListeners();
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    await _service.deleteRecord(id);
    notifyListeners();
  }

  /// 重新录制音频
  Future<void> reRecordAudio({
    required String recordId,
    required String newAudioSourcePath,
    required int newAudioDuration,
  }) async {
    await _service.reRecordAudio(
      recordId: recordId,
      newAudioSourcePath: newAudioSourcePath,
      newAudioDuration: newAudioDuration,
    );
    notifyListeners();
  }

  /// 获取音频文件路径
  Future<String> getAudioFilePath(String relativePath) {
    return _service.getAudioFilePath(relativePath);
  }
}

