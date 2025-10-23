import 'dart:io';
import '../config/storage_config.dart';
import '../services/vocabulary_service.dart';

/// 存储路径测试工具
class StorageTest {
  static final StorageConfig _storageConfig = StorageConfig();
  static final VocabularyService _vocabularyService = VocabularyService();

  /// 测试持久化存储路径
  static Future<void> testPersistentStorage() async {
    try {
      print('=== 持久化存储路径测试 ===');
      
      // 测试数据目录
      final dataDir = await _storageConfig.persistentDataDirectory;
      print('数据目录: $dataDir');
      
      // 测试音频目录
      final audioDir = await _storageConfig.audioDirectory;
      print('音频目录: $audioDir');
      
      // 测试元数据文件路径
      final metadataPath = await _storageConfig.metadataFilePath;
      print('元数据文件: $metadataPath');
      
      // 测试备份目录
      final backupDir = await _storageConfig.backupDirectory;
      print('备份目录: $backupDir');
      
      // 验证目录是否存在
      final dataDirExists = await Directory(dataDir).exists();
      final audioDirExists = await Directory(audioDir).exists();
      final backupDirExists = await Directory(backupDir).exists();
      
      print('数据目录存在: $dataDirExists');
      print('音频目录存在: $audioDirExists');
      print('备份目录存在: $backupDirExists');
      
      // 测试写入权限
      final testFile = File('$dataDir/test.txt');
      await testFile.writeAsString('测试文件');
      final testFileExists = await testFile.exists();
      print('测试文件写入成功: $testFileExists');
      
      if (testFileExists) {
        await testFile.delete();
        print('测试文件清理完成');
      }
      
      print('=== 持久化存储路径测试完成 ===');
    } catch (e) {
      print('持久化存储路径测试失败: $e');
    }
  }

  /// 测试VocabularyService存储路径
  static Future<void> testVocabularyServiceStorage() async {
    try {
      print('=== VocabularyService存储路径测试 ===');
      
      // 初始化服务
      await _vocabularyService.initialize();
      
      // 获取存储路径
      final dataDir = await _vocabularyService.dataDirectory;
      final audioDir = await _vocabularyService.audioDirectory;
      final metadataPath = await _vocabularyService.metadataFilePath;
      
      print('VocabularyService数据目录: $dataDir');
      print('VocabularyService音频目录: $audioDir');
      print('VocabularyService元数据文件: $metadataPath');
      
      // 验证路径一致性
      final storageDataDir = await _storageConfig.persistentDataDirectory;
      final storageAudioDir = await _storageConfig.audioDirectory;
      final storageMetadataPath = await _storageConfig.metadataFilePath;
      
      print('路径一致性检查:');
      print('数据目录一致: ${dataDir == storageDataDir}');
      print('音频目录一致: ${audioDir == storageAudioDir}');
      print('元数据文件一致: ${metadataPath == storageMetadataPath}');
      
      print('=== VocabularyService存储路径测试完成 ===');
    } catch (e) {
      print('VocabularyService存储路径测试失败: $e');
    }
  }

  /// 运行所有测试
  static Future<void> runAllTests() async {
    await testPersistentStorage();
    print('');
    await testVocabularyServiceStorage();
  }
}
