import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 文件工具类 - 仅支持移动端(iOS/Android)
class VoiceFileUtils {
  /// 获取录音文件路径
  static Future<String> getRecordingPath() async {
    final directory = await _getDirectory();
    final recordDir = Directory('${directory.path}/myrecord');
    
    print('[路径] 基础目录: ${directory.path}');
    print('[路径] 录音目录: ${recordDir.path}');
    
    if (!await recordDir.exists()) {
      print('[路径] 目录不存在，创建中...');
      await recordDir.create(recursive: true);
      print('[路径] ✅ 目录创建成功');
    } else {
      print('[路径] ✅ 目录已存在');
    }
    
    final filePath = '${recordDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    print('[路径] 完整文件路径: $filePath');
    
    // 验证目录是否可写
    try {
      final testFile = File('${recordDir.path}/.test');
      await testFile.writeAsString('test');
      await testFile.delete();
      print('[路径] ✅ 目录可写');
    } catch (e) {
      print('[路径] ❌ 目录不可写: $e');
    }
    
    return filePath;
  }

  /// 获取应用目录
  static Future<Directory> _getDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Android: 优先使用外部存储的应用私有目录
        // 路径示例: /storage/emulated/0/Android/data/com.gmc.yueyu/files
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            print('[目录] 使用外部存储应用目录: ${externalDir.path}');
            return externalDir;
          }
        } catch (e) {
          print('[目录] 外部存储目录失败: $e');
        }
        
        // 如果外部存储不可用，使用内部存储
        // 路径示例: /data/user/0/com.gmc.yueyu/files
        try {
          final dir = await getApplicationSupportDirectory();
          print('[目录] 使用内部存储应用目录: ${dir.path}');
          return dir;
        } catch (e) {
          print('[目录] 内部存储目录失败: $e');
          // 最后降级到临时目录
          final tempDir = await getTemporaryDirectory();
          print('[目录] 降级使用临时目录: ${tempDir.path}');
          return tempDir;
        }
      } else {
        // iOS 使用 DocumentsDirectory
        final dir = await getApplicationDocumentsDirectory();
        print('[目录] 使用 ApplicationDocumentsDirectory: ${dir.path}');
        return dir;
      }
    } catch (e) {
      print('[目录] 所有尝试失败，使用临时目录: $e');
      return await getTemporaryDirectory();
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String path) async {
    try {
      final file = File(path);
      
      // 首先检查文件是否存在
      final exists = await file.exists();
      print('[文件检查] 文件存在性: $exists, 路径: $path');
      
      if (!exists) {
        // 检查目录是否存在
        final dir = file.parent;
        final dirExists = await dir.exists();
        print('[文件检查] 父目录存在性: $dirExists, 路径: ${dir.path}');
        
        if (dirExists) {
          // 列出目录内容，看看有没有相似的文件
          final files = await dir.list().toList();
          print('[文件检查] 目录中的文件数量: ${files.length}');
          if (files.isNotEmpty) {
            print('[文件检查] 目录中的文件:');
            for (var f in files.take(5)) {
              print('  - ${f.path}');
            }
          }
        }
        
        return false;
      }
      
      // 文件存在，检查大小
      final fileSize = await file.length();
      print('[文件检查] 文件大小: $fileSize 字节');
      
      if (fileSize == 0) {
        print('[文件检查] ⚠️ 文件大小为0，可能还在写入中');
        return false;
      }
      
      print('[文件检查] ✅ 文件有效');
      return true;
      
    } catch (e) {
      print('[文件检查] ❌ 错误: $e, 路径: $path');
      return false;
    }
  }

  /// 删除文件
  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// 权限工具类 - 仅支持移动端(iOS/Android)
class VoicePermissionUtils {
  /// 检查麦克风权限和存储权限
  static Future<bool> checkMicrophonePermission() async {
    print('[权限] 开始检查麦克风权限...');
    
    // 1. 检查麦克风权限
    final micStatus = await Permission.microphone.status;
    print('[权限] 麦克风状态: $micStatus');
    
    if (!micStatus.isGranted) {
      print('[权限] ⚠️ 麦克风权限被拒绝，尝试请求...');
      final result = await Permission.microphone.request();
      print('[权限] 麦克风请求结果: $result');
      
      if (!result.isGranted) {
        print('[权限] ❌ 用户拒绝了麦克风权限');
        return false;
      }
    }
    
    // 2. 检查存储权限（Android 特定）
    if (Platform.isAndroid) {
      print('[权限] 检查存储权限...');
      final storageStatus = await Permission.storage.status;
      print('[权限] 存储权限状态: $storageStatus');
      
      if (!storageStatus.isGranted) {
        print('[权限] ⚠️ 存储权限未授予，尝试请求...');
        final result = await Permission.storage.request();
        print('[权限] 存储权限请求结果: $result');
        
        // 存储权限不是强制的，因为我们使用应用私有目录
        // 但获得权限可以提高兼容性
        if (!result.isGranted) {
          print('[权限] ⚠️ 存储权限未授予，但继续使用应用私有目录');
        }
      }
    }
    
    print('[权限] ✅ 权限检查完成');
    return true;
  }
}
