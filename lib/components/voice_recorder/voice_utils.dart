import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 文件工具类 - 仅支持移动端(iOS/Android)
class VoiceFileUtils {
  /// 获取录音文件路径
  static Future<String> getRecordingPath() async {
    final directory = await _getDirectory();
    final recordDir = Directory('${directory.path}/myrecord');
    
    if (!await recordDir.exists()) {
      await recordDir.create(recursive: true);
    }
    
    final filePath = '${recordDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    // 验证目录是否可写
    try {
      final testFile = File('${recordDir.path}/.test');
      await testFile.writeAsString('test');
      await testFile.delete();
    } catch (e) {
      // 目录不可写，但继续执行
    }
    
    return filePath;
  }

  /// 获取应用目录 - 使用外部存储的公共目录（持久化存储）
  static Future<Directory> _getDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Android: 使用外部存储的公共目录（Music文件夹）
        // 路径示例: /storage/emulated/0/Music/yuji
        try {
          // 直接使用外部存储根目录下的Music文件夹
          final musicDir = Directory('/storage/emulated/0/Music/yuji');
          if (!await musicDir.exists()) {
            await musicDir.create(recursive: true);
          }
          return musicDir;
        } catch (e) {
          // 如果直接路径失败，尝试使用getExternalStorageDirectory获取根路径
          try {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              // 从应用私有目录路径中提取外部存储根路径
              // 例如: /storage/emulated/0/Android/data/com.example.yuji/files
              // 提取: /storage/emulated/0
              final rootPath = externalDir.path.split('/Android/')[0];
              final musicDir = Directory('$rootPath/Music/yuji');
              if (!await musicDir.exists()) {
                await musicDir.create(recursive: true);
              }
              return musicDir;
            }
          } catch (e2) {
            // 如果都失败了，降级到应用私有目录
          }
        }
        
        // 备选：使用应用私有目录
        final dir = await getApplicationSupportDirectory();
        return dir;
      } else {
        // iOS 使用 DocumentsDirectory
        final dir = await getApplicationDocumentsDirectory();
        return dir;
      }
    } catch (e) {
      // 最后降级到临时目录
      return await getTemporaryDirectory();
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String path) async {
    try {
      final file = File(path);
      
      // 首先检查文件是否存在
      final exists = await file.exists();
      
      if (!exists) {
        return false;
      }
      
      // 文件存在，检查大小
      final fileSize = await file.length();
      
      if (fileSize == 0) {
        return false;
      }
      
      return true;
      
    } catch (e) {
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
    // 1. 检查麦克风权限
    final micStatus = await Permission.microphone.status;
    
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      
      if (!result.isGranted) {
        return false;
      }
    }
    
    // 2. 检查存储权限（Android 特定）- 使用公共目录需要存储权限
    if (Platform.isAndroid) {
      // Android 13+ 使用新的媒体权限
      try {
        final audioStatus = await Permission.audio.status;
        if (!audioStatus.isGranted) {
          final result = await Permission.audio.request();
          if (!result.isGranted) {
            // 音频权限被拒绝，尝试使用存储权限
            final storageStatus = await Permission.storage.status;
            if (!storageStatus.isGranted) {
              await Permission.storage.request();
            }
          }
        }
      } catch (e) {
        // 如果audio权限不支持，使用存储权限
        try {
          final storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            await Permission.storage.request();
          }
        } catch (e) {
          // 权限请求失败，但继续执行
        }
      }
    }
    
    return true;
  }
}
