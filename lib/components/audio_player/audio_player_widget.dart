import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// 音频播放模式
enum AudioPlayerMode {
  /// 按住播放模式（按住播放，松开暂停）
  holdToPlay,
  /// 标准播放模式（播放/暂停按钮 + 进度条）
  standard,
}

/// 音频播放器组件
class AudioPlayerWidget extends StatefulWidget {
  /// 音频文件路径
  final String audioPath;
  
  /// 播放模式
  final AudioPlayerMode mode;
  
  /// 音频总时长（秒）
  final int totalDuration;
  
  /// 是否显示播放速度控制
  final bool showSpeedControl;
  
  /// 自定义样式
  final Color? primaryColor;
  
  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    this.mode = AudioPlayerMode.standard,
    required this.totalDuration,
    this.showSpeedControl = true,
    this.primaryColor,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isHolding = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  Duration _countdownDuration = Duration.zero; // 倒计时剩余时间
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // 拖拽进度相关
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// 初始化音频播放器
  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    
    try {
      // 检查音频文件是否存在（仅移动平台）
      if (!kIsWeb) {
        final audioFile = File(widget.audioPath);
        if (!await audioFile.exists()) {
          print('音频文件不存在: ${widget.audioPath}');
          return;
        }
      }
      
      // 加载音频文件
      if (kIsWeb) {
        // Web平台：使用URL加载（支持blob URLs和http URLs）
        await _audioPlayer.setUrl(widget.audioPath);
      } else {
        // 移动平台：使用文件路径加载
        await _audioPlayer.setFilePath(widget.audioPath);
      }
      
      // 监听播放位置
      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            // 计算倒计时：总时长 - 当前播放位置
            _countdownDuration = _totalDuration - position;
            if (_countdownDuration.isNegative) {
              _countdownDuration = Duration.zero;
            }
          });
        }
      });
      
      // 监听音频总时长
      _durationSubscription = _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _totalDuration = duration;
            // 初始化倒计时为总时长
            _countdownDuration = duration;
          });
        }
      });
      
      // 监听播放状态
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
          
          // 播放完成后重置
          if (state.processingState == ProcessingState.completed) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.pause();
          }
        }
      });
      
    } catch (e) {
      print('音频加载失败: $e');
    }
  }

  /// 播放/暂停
  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // 检查音频文件是否存在
        if (!kIsWeb) {
          final audioFile = File(widget.audioPath);
          if (!await audioFile.exists()) {
            print('音频文件不存在，无法播放: ${widget.audioPath}');
            return;
          }
        }
        await _audioPlayer.play();
      }
    } catch (e) {
      print('播放控制失败: $e');
    }
  }

  /// 按住开始播放
  Future<void> _onHoldStart() async {
    setState(() {
      _isHolding = true;
    });
    try {
      // 检查音频文件是否存在
      if (!kIsWeb) {
        final audioFile = File(widget.audioPath);
        if (!await audioFile.exists()) {
          print('音频文件不存在，无法播放: ${widget.audioPath}');
          setState(() {
            _isHolding = false;
          });
          return;
        }
      }
      await _audioPlayer.play();
    } catch (e) {
      print('播放失败: $e');
      setState(() {
        _isHolding = false;
      });
    }
  }

  /// 松开暂停播放
  Future<void> _onHoldEnd() async {
    setState(() {
      _isHolding = false;
    });
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('暂停失败: $e');
    }
  }

  /// 设置播放速度
  Future<void> _setPlaybackSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      setState(() {
        _playbackSpeed = speed;
      });
    } catch (e) {
      print('设置播放速度失败: $e');
    }
  }

  /// 跳转到指定位置
  Future<void> _seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      print('跳转失败: $e');
    }
  }

  /// 开始拖拽进度条
  void _onDragStart() {
    setState(() {
      _isDragging = true;
    });
  }

  /// 拖拽进度条
  void _onDragUpdate(double value) {
    if (_isDragging && _totalDuration.inMilliseconds > 0) {
      setState(() {
        _dragValue = value.clamp(0.0, 1.0);
      });
    }
  }

  /// 结束拖拽进度条
  void _onDragEnd() {
    if (_isDragging && _totalDuration.inMilliseconds > 0) {
      final newPosition = Duration(
        milliseconds: (_dragValue * _totalDuration.inMilliseconds).round(),
      );
      _seekTo(newPosition);
    }
    setState(() {
      _isDragging = false;
    });
  }

  /// 格式化时间显示
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return widget.mode == AudioPlayerMode.holdToPlay
        ? _buildHoldToPlayMode()
        : _buildStandardMode();
  }

  /// 构建按住播放模式界面
  Widget _buildHoldToPlayMode() {
    return GestureDetector(
      onLongPressStart: (_) => _onHoldStart(),
      onLongPressEnd: (_) => _onHoldEnd(),
      onLongPressCancel: () => _onHoldEnd(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHolding ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHolding ? (widget.primaryColor ?? Colors.blue) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isHolding ? Icons.volume_up : Icons.volume_off,
              color: _isHolding ? (widget.primaryColor ?? Colors.blue) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isHolding ? '播放中...' : '长按收听',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isHolding ? (widget.primaryColor ?? Colors.blue) : Colors.grey[700],
                      fontWeight: _isHolding ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 可拖拽的进度条
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: widget.primaryColor ?? Colors.blue,
                      inactiveTrackColor: Colors.grey[300],
                      thumbColor: widget.primaryColor ?? Colors.blue,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _isDragging 
                          ? _dragValue 
                          : (_totalDuration.inMilliseconds > 0
                              ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                              : 0),
                      onChanged: _onDragUpdate,
                      onChangeStart: (_) => _onDragStart(),
                      onChangeEnd: (_) => _onDragEnd(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatDuration(_countdownDuration),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标准播放模式界面
  Widget _buildStandardMode() {
    // 删除播放按钮，返回空容器
    return const SizedBox.shrink();
  }

  /// 构建播放速度按钮
  Widget _buildSpeedButton(double speed) {
    final isSelected = _playbackSpeed == speed;
    return GestureDetector(
      onTap: () => _setPlaybackSpeed(speed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? (widget.primaryColor ?? Colors.blue) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? (widget.primaryColor ?? Colors.blue) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

