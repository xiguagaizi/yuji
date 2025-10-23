import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 持久化存储配置
class StorageConfig {
  static final StorageConfig _instance = StorageConfig._internal();
  factory StorageConfig() => _instance;
  StorageConfig._internal();

  /// 应用数据根目录（持久化存储）
  String? _persistentDataDirectory;
  
  /// 获取持久化数据存储目录
  /// 使用外部存储目录，重新安装应用时不会被删除
  Future<String> get persistentDataDirectory async {
    if (_persistentDataDirectory != null) {
      return _persistentDataDirectory!;
    }
    
    // 优先使用外部存储目录
    Directory? externalDir;
    try {
      externalDir = await getExternalStorageDirectory();
    } catch (e) {
      print('获取外部存储目录失败: $e');
    }
    
    // 如果外部存储不可用，使用应用文档目录
    if (externalDir == null) {
      externalDir = await getApplicationDocumentsDirectory();
    }
    
    // 创建应用专用目录
    _persistentDataDirectory = '${externalDir.path}/yuji_persistent_data';
    
    // 确保目录存在
    final dir = Directory(_persistentDataDirectory!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return _persistentDataDirectory!;
  }
  
  /// 获取音频文件存储目录
  Future<String> get audioDirectory async {
    final dataDir = await persistentDataDirectory;
    final audioDir = '$dataDir/audios';
    
    // 确保目录存在
    final dir = Directory(audioDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return audioDir;
  }
  
  /// 获取元数据文件路径
  Future<String> get metadataFilePath async {
    final dataDir = await persistentDataDirectory;
    return '$dataDir/metadata.json';
  }
  
  /// 获取备份目录
  Future<String> get backupDirectory async {
    final dataDir = await persistentDataDirectory;
    final backupDir = '$dataDir/backups';
    
    // 确保目录存在
    final dir = Directory(backupDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return backupDir;
  }
  
  /// 清理缓存（保留持久化数据）
  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final appCacheDir = Directory('${cacheDir.path}/yuji_cache');
      if (await appCacheDir.exists()) {
        await appCacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('清理缓存失败: $e');
    }
  }
}
