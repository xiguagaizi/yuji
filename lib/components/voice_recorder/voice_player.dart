import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// 语音播放器（单例模式）
/// 用于播放录音文件，仅支持移动端(iOS/Android)
class VoicePlayer {
  static final VoicePlayer _instance = VoicePlayer._internal();
  factory VoicePlayer() => _instance;
  VoicePlayer._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentFilePath;
  VoidCallback? _onPlayStateChanged;

  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 当前播放的文件路径
  String? get currentFilePath => _currentFilePath;

  /// 播放语音文件
  Future<void> playVoice(String filePath, {VoidCallback? onPlayStateChanged}) async {
    try {
      // 如果正在播放同一个文件，则停止播放
      if (_isPlaying && _currentFilePath == filePath) {
        await stopVoice();
        return;
      }

      // 停止当前播放
      if (_isPlaying) {
        await stopVoice();
      }

      _currentFilePath = filePath;
      _onPlayStateChanged = onPlayStateChanged;

      // 设置音频源（移动平台使用文件路径）
      await _audioPlayer.setFilePath(filePath);

      // 监听播放完成事件
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _currentFilePath = null;
          _onPlayStateChanged?.call();
        }
      });

      // 开始播放
      _isPlaying = true;
      _onPlayStateChanged?.call();
      await _audioPlayer.play();

    } catch (e) {
      debugPrint('播放语音失败: $e');
      _isPlaying = false;
      _currentFilePath = null;
      _onPlayStateChanged?.call();
    }
  }

  /// 停止播放
  Future<void> stopVoice() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentFilePath = null;
      _onPlayStateChanged?.call();
    } catch (e) {
      debugPrint('停止播放失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pauseVoice() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      _onPlayStateChanged?.call();
    } catch (e) {
      debugPrint('暂停播放失败: $e');
    }
  }

  /// 恢复播放
  Future<void> resumeVoice() async {
    try {
      await _audioPlayer.play();
      _isPlaying = true;
      _onPlayStateChanged?.call();
    } catch (e) {
      debugPrint('恢复播放失败: $e');
    }
  }

  /// 获取当前播放位置
  Duration get currentPosition => _audioPlayer.position;

  /// 获取总时长
  Duration? get duration => _audioPlayer.duration;

  /// 释放资源
  void dispose() {
    _audioPlayer.dispose();
  }
}
