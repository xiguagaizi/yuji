import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'voice_utils.dart';

/// 语音录制控件
/// 类似微信的按住录音功能
class VoiceRecorder extends StatefulWidget {
  /// 录音完成回调
  final Function(String filePath, int duration)? onRecordingComplete;
  
  /// 录音取消回调
  final VoidCallback? onRecordingCancel;
  
  /// 录音开始回调
  final VoidCallback? onRecordingStart;
  
  /// 录音状态变化回调
  final Function(bool isRecording)? onRecordingStateChanged;
  
  /// 录制时长变化回调
  final Function(int duration)? onDurationChanged;
  
  /// 按钮大小
  final double size;
  
  /// 按钮颜色
  final Color? backgroundColor;
  
  /// 文字颜色
  final Color? textColor;
  
  /// 是否显示录音时长
  final bool showDuration;
  
  /// 最大录音时长（秒）
  final int maxDuration;

  const VoiceRecorder({
    super.key,
    this.onRecordingComplete,
    this.onRecordingCancel,
    this.onRecordingStart,
    this.onRecordingStateChanged,
    this.onDurationChanged,
    this.size = 60.0,
    this.backgroundColor,
    this.textColor,
    this.showDuration = true,
    this.maxDuration = 60,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _isRecording = false;
  bool _isPressing = false;
  bool _isStopping = false; // 防止重复调用 stop
  String _recordingPath = '';
  int _recordingDuration = 0;
  Timer? _durationTimer;
  Timer? _maxDurationTimer;
  
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    _durationTimer?.cancel();
    _maxDurationTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      // 检查麦克风权限
      print('[录音] 检查麦克风权限...');
      final hasPermission = await VoicePermissionUtils.checkMicrophonePermission();
      print('[录音] 麦克风权限状态: $hasPermission');
      
      if (!hasPermission) {
        Fluttertoast.showToast(msg: '需要麦克风权限才能录音，请在设置中开启');
        return;
      }

      // 获取录音路径
      _recordingPath = await VoiceFileUtils.getRecordingPath();
      print('[录音] ✅ 准备录音，路径: $_recordingPath');

      // 检查录音器是否正在使用
      final isRecording = await _audioRecorder.isRecording();
      if (isRecording) {
        print('[录音] ⚠️ 录音器已在使用中，先停止');
        await _audioRecorder.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 验证文件路径的父目录是否存在
      final file = File(_recordingPath);
      final parentDir = file.parent;
      final dirExists = await parentDir.exists();
      print('[录音] 父目录存在性: $dirExists, 路径: ${parentDir.path}');
      
      if (!dirExists) {
        print('[录音] ⚠️ 父目录不存在，创建中...');
        await parentDir.create(recursive: true);
      }

      // 开始录音（移动平台）
      print('[录音] ========== 开始录音 ==========');
      print('[录音] 🎤 目标路径: $_recordingPath');
      print('[录音] 录音配置:');
      print('[录音]   - 编码器: AudioEncoder.aacLc');
      print('[录音]   - 比特率: 128000');
      print('[录音]   - 采样率: 44100');
      print('[录音]   - 传入 path 参数: $_recordingPath');
      
      // 🔍 关键：检查 record 包的版本和配置
      try {
        // 尝试不同的方式启动录音
        print('[录音] 调用 _audioRecorder.start()...');
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath,
        );
        print('[录音] ✅ start() 调用成功');
      } catch (e) {
        print('[录音] ❌ start() 调用失败: $e');
        rethrow;
      }
      
      // ⚠️ 关键修复：等待音频编码器完全初始化
      // MPEG4Writer需要足够时间来启动audio track，否则会报错
      // "Stop() called but track is not started or stopped"
      print('[录音] ⏳ 等待音频编码器初始化...');
      await Future.delayed(const Duration(milliseconds: 800));
      
      // 验证录音是否真正启动
      final isNowRecording = await _audioRecorder.isRecording();
      print('[录音] 录音启动验证: $isNowRecording');
      
      if (!isNowRecording) {
        throw Exception('录音器启动失败');
      }
      
      // 检查录音文件是否已经开始创建（某些平台会立即创建文件）
      final fileExistsNow = await file.exists();
      print('[录音] 录音文件即时状态: ${fileExistsNow ? "已创建" : "未创建（正常，会在停止时创建）"}');
      
      if (fileExistsNow) {
        try {
          final size = await file.length();
          print('[录音] 初始文件大小: $size 字节');
        } catch (e) {
          print('[录音] ⚠️ 无法读取初始文件大小: $e');
        }
      }
      
      print('[录音] ====================================');
      
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // 开始计时
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
        widget.onDurationChanged?.call(_recordingDuration);
        
        // 🔍 每3秒检查一次文件状态（用于诊断）
        if (_recordingDuration % 3 == 0) {
          _checkRecordingFileStatus();
        }
      });

      // 最大录音时长定时器
      _maxDurationTimer = Timer(Duration(seconds: widget.maxDuration), () {
        _stopRecording();
      });

      // 开始动画
      _scaleController.forward();
      _pulseController.repeat(reverse: true);

      // 回调
      widget.onRecordingStart?.call();
      widget.onRecordingStateChanged?.call(true);

    } catch (e) {
      Fluttertoast.showToast(msg: '录音失败: $e');
    }
  }

  /// 检查录音文件状态（用于诊断）
  Future<void> _checkRecordingFileStatus() async {
    try {
      final file = File(_recordingPath);
      final exists = await file.exists();
      
      if (exists) {
        final size = await file.length();
        print('[录音监控] ✅ 文件正在写入 - 大小: $size 字节 ($_recordingDuration秒)');
      } else {
        print('[录音监控] ⚠️ 文件尚未创建 ($_recordingDuration秒) - 这可能正常，某些平台在停止时才创建文件');
        
        // 列出目录查看是否有其他文件被创建
        final parentDir = file.parent;
        if (await parentDir.exists()) {
          final files = await parentDir.list().toList();
          final recentFiles = files.whereType<File>().where((f) {
            try {
              final stat = f.statSync();
              final now = DateTime.now();
              final diff = now.difference(stat.modified);
              return diff.inSeconds < 60; // 最近60秒内修改的文件
            } catch (e) {
              return false;
            }
          }).toList();
          
          if (recentFiles.isNotEmpty) {
            print('[录音监控] 📁 最近60秒内修改的文件:');
            for (var f in recentFiles) {
              final fileName = f.path.split('/').last.split('\\').last;
              try {
                final size = await f.length();
                print('[录音监控]   - $fileName ($size 字节)');
              } catch (e) {
                print('[录音监控]   - $fileName (无法读取大小)');
              }
            }
          }
        }
      }
    } catch (e) {
      print('[录音监控] ⚠️ 检查文件状态失败: $e');
    }
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    if (!_isRecording) {
      print('[录音] ⚠️ 未在录音状态，无需停止');
      return;
    }

    // 防止重复调用（防止 onTapUp 和 onLongPressEnd 同时触发）
    if (_isStopping) {
      print('[录音] ⚠️ 正在停止中，忽略重复调用');
      return;
    }
    _isStopping = true;

    try {
      // 先保存时长（在取消计时器前）
      final duration = _recordingDuration;
      print('[录音] 准备停止录音 - 时长: $duration 秒');
      
      // ⚠️ 重要：检查实际录音时长（考虑初始化延迟）
      // 由于编码器初始化需要800ms，实际录音需要扣除这个时间
      // 但为了避免误判，我们使用更宽松的检查：只要用户按住超过1.5秒就认为有效
      final actualDuration = duration;
      print('[录音] 检查录音时长 - 计时器显示: $actualDuration 秒');
      
      if (actualDuration < 1) {
        print('[录音] ⚠️ 录音时长太短: $actualDuration 秒（需要至少1秒）');
        print('[录音] 🗑️ 取消录音，不保存文件');
        await _audioRecorder.cancel(); // 取消录音，不生成文件
        _durationTimer?.cancel();
        _maxDurationTimer?.cancel();
        setState(() {
          _isRecording = false;
          _isPressing = false;
        });
        _scaleController.reverse();
        _pulseController.stop();
        _isStopping = false; // 重置停止标志
        Fluttertoast.showToast(msg: '录音时长太短，请至少录制1秒');
        widget.onRecordingCancel?.call();
        widget.onRecordingStateChanged?.call(false);
        return;
      }
      
      final path = await _audioRecorder.stop();
      
      print('[录音] ========== 停止录音详细信息 ==========');
      print('[录音] AudioRecorder.stop() 返回路径: $path');
      print('[录音] 原始录音路径 (_recordingPath): $_recordingPath');
      print('[录音] 返回路径是否为 null: ${path == null}');
      print('[录音] 返回路径是否为空字符串: ${path?.isEmpty ?? true}');
      print('[录音] 路径是否一致: ${path == _recordingPath}');
      
      _durationTimer?.cancel();
      _maxDurationTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _isPressing = false;
      });

      // 停止动画
      _scaleController.reverse();
      _pulseController.stop();

      // 检查录音是否成功（移动平台）
      // 优先使用 stop() 返回的路径，如果为空则使用原始路径
      final audioPath = (path != null && path.isNotEmpty) ? path : _recordingPath;
      print('[录音] 最终使用的音频路径: $audioPath');
      
      // 🔍 立即进行文件系统深度诊断
      print('[录音] ========== 文件系统诊断 ==========');
      
      // 等待文件系统刷新
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 检查目标文件
      final targetFile = File(audioPath);
      final targetExists = await targetFile.exists();
      print('[录音] 目标路径文件存在: $targetExists ($audioPath)');
      
      if (targetExists) {
        try {
          final size = await targetFile.length();
          final stat = await targetFile.stat();
          print('[录音] ✅ 文件大小: $size 字节');
          print('[录音] 文件修改时间: ${stat.modified}');
        } catch (e) {
          print('[录音] ⚠️ 读取文件信息失败: $e');
        }
      }
      
      // 如果返回路径和原始路径不同，也检查原始路径
      if (path != null && path != _recordingPath) {
        final originalFile = File(_recordingPath);
        final originalExists = await originalFile.exists();
        print('[录音] 原始路径文件存在: $originalExists ($_recordingPath)');
        if (originalExists) {
          final size = await originalFile.length();
          print('[录音] 原始路径文件大小: $size 字节');
        }
      }
      
      // 列出父目录中的所有文件
      try {
        final parentDir = targetFile.parent;
        final dirExists = await parentDir.exists();
        print('[录音] 父目录存在: $dirExists (${parentDir.path})');
        
        if (dirExists) {
          final files = await parentDir.list().toList();
          print('[录音] 📁 父目录中的文件总数: ${files.length}');
          
          // 只显示最近的10个文件
          final sortedFiles = files.whereType<File>().toList()
            ..sort((a, b) {
              try {
                return b.statSync().modified.compareTo(a.statSync().modified);
              } catch (e) {
                return 0;
              }
            });
          
          print('[录音] 最近的文件（最多10个）:');
          for (var i = 0; i < sortedFiles.length && i < 10; i++) {
            final file = sortedFiles[i];
            try {
              final stat = await file.stat();
              final fileName = file.path.split('/').last;
              print('[录音]   ${i + 1}. $fileName (${stat.size} 字节, ${stat.modified})');
            } catch (e) {
              print('[录音]   ${i + 1}. ${file.path} (无法读取信息)');
            }
          }
        } else {
          print('[录音] ⚠️ 父目录不存在！这很不正常！');
        }
      } catch (e) {
        print('[录音] ⚠️ 列出目录文件时出错: $e');
      }
      
      print('[录音] ====================================');
    
      
      // 检查文件是否存在，添加重试机制（等待文件写入完成）
      bool fileExists = await VoiceFileUtils.fileExists(audioPath);
      print('[录音] 第一次检查 - 文件存在: $fileExists');
      
      // 如果文件不存在，等待一小段时间后重试（最多重试5次，每次等待更长）
      if (!fileExists) {
        print('[录音] ⏳ 文件暂不存在，开始重试...');
        for (int i = 0; i < 5 && !fileExists; i++) {
          final waitTime = 300 + (i * 200); // 递增等待时间：300, 500, 700, 900, 1100ms
          await Future.delayed(Duration(milliseconds: waitTime));
          fileExists = await VoiceFileUtils.fileExists(audioPath);
          print('[录音] 重试 ${i + 1}/5 (等待${waitTime}ms) - 文件存在: $fileExists');
        }
      }
      
      if (fileExists) {
        print('[录音] ✅ 录音成功！文件路径: $audioPath, 时长: $duration 秒');
        widget.onRecordingComplete?.call(audioPath, duration);
      } else {
        print('[录音] ❌ 录音失败！文件最终不存在: $audioPath');
        print('[录音] 💡 可能原因: 1) 录音时间太短 2) 权限不足 3) 磁盘空间不足');
        Fluttertoast.showToast(msg: '录音文件保存失败，请检查权限并重试');
        widget.onRecordingCancel?.call();
      }

      widget.onRecordingStateChanged?.call(false);

    } catch (e) {
      print('[录音] ❌ 停止录音异常: $e');
      Fluttertoast.showToast(msg: '停止录音失败: $e');
      widget.onRecordingCancel?.call();
    } finally {
      // 无论成功或失败，重置停止标志
      _isStopping = false;
    }
  }

  /// 取消录音
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.cancel();
      
      _durationTimer?.cancel();
      _maxDurationTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _isPressing = false;
        _recordingDuration = 0;
      });

      // 停止动画
      _scaleController.reverse();
      _pulseController.stop();

      // 删除录音文件
      await VoiceFileUtils.deleteFile(_recordingPath);

      widget.onRecordingCancel?.call();
      widget.onRecordingStateChanged?.call(false);

    } catch (e) {
      Fluttertoast.showToast(msg: '取消录音失败: $e');
    }
  }

  /// 格式化时间显示
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTapDown: (_) {
            if (!_isRecording) {
              setState(() {
                _isPressing = true;
              });
              _startRecording();
            }
          },
          onTapUp: (_) {
            if (_isRecording) {
              _stopRecording();
            }
          },
          onTapCancel: () {
            if (_isRecording) {
              _cancelRecording();
            }
          },
          // 长按触发
          // onLongPressStart: (_) {
          //   if (!_isRecording) {
          //     setState(() {
          //       _isPressing = true;
          //     });
          //     _startRecording();
          //   }
          // },
          // onLongPressEnd: (_) {
          //   if (_isRecording) {
          //     _stopRecording();
          //   }
          // },
          // onLongPressCancel: () {
          //   if (_isRecording) {
          //     _cancelRecording();
          //   }
          // },
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _pulseAnimation.value : _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: _isRecording 
                        ? Colors.red 
                        : (widget.backgroundColor ?? Colors.blue),
                    shape: BoxShape.circle,
                    boxShadow: _isRecording
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: widget.textColor ?? Colors.white,
                    size: widget.size * 0.4,
                  ),
                ),
              );
            },
          ),
    );
  }
}
