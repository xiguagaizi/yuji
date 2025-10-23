import 'package:intl/intl.dart';

/// 词汇记录模型
class VocabularyRecord {
  /// 唯一标识
  final String id;
  
  /// 词汇文本
  final String word;
  
  /// 备注说明
  final String note;
  
  /// 音频文件相对路径
  final String audioPath;
  
  /// 音频时长（秒）
  final int audioDuration;
  
  /// 创建时间
  final DateTime createTime;
  
  /// 更新时间
  final DateTime updateTime;

  VocabularyRecord({
    required this.id,
    required this.word,
    required this.note,
    required this.audioPath,
    required this.audioDuration,
    required this.createTime,
    required this.updateTime,
  });

  /// 从 JSON 创建对象
  factory VocabularyRecord.fromJson(Map<String, dynamic> json) {
    return VocabularyRecord(
      id: json['id'] as String,
      word: json['word'] as String,
      note: json['note'] as String? ?? '',
      audioPath: json['audioPath'] as String,
      audioDuration: json['audioDuration'] as int,
      createTime: DateTime.parse(json['createTime'] as String),
      updateTime: DateTime.parse(json['updateTime'] as String),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'note': note,
      'audioPath': audioPath,
      'audioDuration': audioDuration,
      'createTime': createTime.toIso8601String(),
      'updateTime': updateTime.toIso8601String(),
    };
  }

  /// 复制并修改某些字段
  VocabularyRecord copyWith({
    String? id,
    String? word,
    String? note,
    String? audioPath,
    int? audioDuration,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return VocabularyRecord(
      id: id ?? this.id,
      word: word ?? this.word,
      note: note ?? this.note,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  /// 获取格式化的创建日期
  String getFormattedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordDate = DateTime(createTime.year, createTime.month, createTime.day);

    if (recordDate == today) {
      return '今天';
    } else if (recordDate == yesterday) {
      return '昨天';
    } else {
      return DateFormat('yyyy-MM-dd').format(createTime);
    }
  }

  /// 获取日期分组标识（用于列表分组）
  String getDateGroupKey() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordDate = DateTime(createTime.year, createTime.month, createTime.day);
    
    if (recordDate == today) {
      return 'today';
    } else if (recordDate == yesterday) {
      return 'yesterday';
    } else {
      // 本周
      final weekAgo = today.subtract(const Duration(days: 7));
      if (recordDate.isAfter(weekAgo)) {
        return 'thisWeek';
      }
      
      // 本月
      final monthStart = DateTime(now.year, now.month, 1);
      if (recordDate.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        return 'thisMonth';
      }
      
      return 'earlier';
    }
  }

  /// 获取日期分组显示名称
  static String getGroupDisplayName(String groupKey) {
    switch (groupKey) {
      case 'today':
        return '今天';
      case 'yesterday':
        return '昨天';
      case 'thisWeek':
        return '本周';
      case 'thisMonth':
        return '本月';
      case 'earlier':
        return '更早';
      default:
        return '未知';
    }
  }

  /// 格式化音频时长显示
  String getFormattedDuration() {
    final minutes = audioDuration ~/ 60;
    final seconds = audioDuration % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }
}

