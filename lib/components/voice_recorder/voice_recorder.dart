import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';
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
  // bool _isPressing = false; // 暂时不使用
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

  /// 触发震动反馈
  Future<void> _triggerVibration() async {
    try {
      // 检查设备是否支持震动
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // 短震动反馈，表示开始录音
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      // 震动失败不影响录音功能
      print('震动反馈失败: $e');
    }
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      // 检查麦克风权限
      final hasPermission = await VoicePermissionUtils.checkMicrophonePermission();
      
      if (!hasPermission) {
        Fluttertoast.showToast(msg: '需要麦克风权限才能录音，请在设置中开启');
        return;
      }

      // 获取录音路径
      _recordingPath = await VoiceFileUtils.getRecordingPath();

      // 检查录音器是否正在使用
      final isRecording = await _audioRecorder.isRecording();
      if (isRecording) {
        await _audioRecorder.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 验证文件路径的父目录是否存在
      final file = File(_recordingPath);
      final parentDir = file.parent;
      final dirExists = await parentDir.exists();
      
      if (!dirExists) {
        await parentDir.create(recursive: true);
      }

      // 开始录音（移动平台）
      try {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath,
        );
      } catch (e) {
        rethrow;
      }
      
      // ⚠️ 关键修复：等待音频编码器完全初始化
      // MPEG4Writer需要足够时间来启动audio track，否则会报错
      // "Stop() called but track is not started or stopped"
      await Future.delayed(const Duration(milliseconds: 800));
      
      // 验证录音是否真正启动
      final isNowRecording = await _audioRecorder.isRecording();
      
      if (!isNowRecording) {
        throw Exception('录音器启动失败');
      }
      
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
        
      });

      // 最大录音时长定时器
      _maxDurationTimer = Timer(Duration(seconds: widget.maxDuration), () {
        _stopRecording();
      });

      // 开始动画
      _scaleController.forward();
      _pulseController.repeat(reverse: true);

      // 震动反馈
      _triggerVibration();

      // 回调
      widget.onRecordingStart?.call();
      widget.onRecordingStateChanged?.call(true);

    } catch (e) {
      Fluttertoast.showToast(msg: '录音失败: $e');
    }
  }


  /// 停止录音
  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }

    // 防止重复调用（防止 onTapUp 和 onLongPressEnd 同时触发）
    if (_isStopping) {
      return;
    }
    _isStopping = true;

    try {
      // 先保存时长（在取消计时器前）
      final duration = _recordingDuration;
      
      // ⚠️ 重要：检查实际录音时长（考虑初始化延迟）
      // 由于编码器初始化需要800ms，实际录音需要扣除这个时间
      // 但为了避免误判，我们使用更宽松的检查：只要用户按住超过1.5秒就认为有效
      final actualDuration = duration;
      
      if (actualDuration < 1) {
        await _audioRecorder.cancel(); // 取消录音，不生成文件
        _durationTimer?.cancel();
        _maxDurationTimer?.cancel();
        setState(() {
          _isRecording = false;
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
      
      _durationTimer?.cancel();
      _maxDurationTimer?.cancel();
      
      setState(() {
        _isRecording = false;
      });

      // 停止动画
      _scaleController.reverse();
      _pulseController.stop();

      // 检查录音是否成功（移动平台）
      // 优先使用 stop() 返回的路径，如果为空则使用原始路径
      final audioPath = (path != null && path.isNotEmpty) ? path : _recordingPath;
      
      // 等待文件系统刷新
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 检查文件是否存在，添加重试机制（等待文件写入完成）
      bool fileExists = await VoiceFileUtils.fileExists(audioPath);
      
      // 如果文件不存在，等待一小段时间后重试（最多重试5次，每次等待更长）
      if (!fileExists) {
        for (int i = 0; i < 5 && !fileExists; i++) {
          final waitTime = 300 + (i * 200); // 递增等待时间：300, 500, 700, 900, 1100ms
          await Future.delayed(Duration(milliseconds: waitTime));
          fileExists = await VoiceFileUtils.fileExists(audioPath);
        }
      }
      
      if (fileExists) {
        widget.onRecordingComplete?.call(audioPath, duration);
      } else {
        Fluttertoast.showToast(msg: '录音文件保存失败，请检查权限并重试');
        widget.onRecordingCancel?.call();
      }

      widget.onRecordingStateChanged?.call(false);

    } catch (e) {
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


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!_isRecording) {
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
                          color: Colors.red.withValues(alpha: 0.3),
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
