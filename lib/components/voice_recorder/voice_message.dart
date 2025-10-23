import 'package:flutter/material.dart';

/// 语音消息组件
/// 用于显示录音结果，类似微信的语音消息
class VoiceMessage extends StatefulWidget {
  /// 录音文件路径
  final String filePath;
  
  /// 录音时长（秒）
  final int duration;
  
  /// 是否正在播放
  final bool isPlaying;
  
  /// 播放状态变化回调
  final Function(bool isPlaying)? onPlayStateChanged;
  
  /// 删除回调
  final VoidCallback? onDelete;
  
  /// 是否显示删除按钮
  final bool showDeleteButton;
  
  /// 消息方向（发送/接收）
  final MessageDirection direction;

  const VoiceMessage({
    super.key,
    required this.filePath,
    required this.duration,
    this.isPlaying = false,
    this.onPlayStateChanged,
    this.onDelete,
    this.showDeleteButton = false,
    this.direction = MessageDirection.sent,
  });

  @override
  State<VoiceMessage> createState() => _VoiceMessageState();
}

enum MessageDirection { sent, received }

class _VoiceMessageState extends State<VoiceMessage>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(VoiceMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  /// 格式化时间显示
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// 根据时长计算宽度
  double _calculateWidth() {
    // 最小宽度60，最大宽度200，根据时长动态调整
    final minWidth = 60.0;
    final maxWidth = 200.0;
    final duration = widget.duration;
    
    if (duration <= 1) return minWidth;
    if (duration >= 60) return maxWidth;
    
    return minWidth + (maxWidth - minWidth) * (duration / 60);
  }

  /// 构建波形动画
  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final delay = index * 0.2;
            final animationValue = (_waveAnimation.value + delay) % 1.0;
            final height = 4 + (animationValue * 12);
            
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.direction == MessageDirection.sent
                    ? Colors.white
                    : Colors.blue,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSent = widget.direction == MessageDirection.sent;
    final width = _calculateWidth();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSent) ...[
            // 接收消息头像
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          
          // 语音消息气泡
          GestureDetector(
            onTap: () {
              widget.onPlayStateChanged?.call(!widget.isPlaying);
            },
            child: Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSent ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 播放/暂停图标
                  Icon(
                    widget.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: isSent ? Colors.white : Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  
                  // 波形动画
                  _buildWaveAnimation(),
                  
                  const SizedBox(width: 8),
                  
                  // 时长显示
                  Text(
                    _formatDuration(widget.duration),
                    style: TextStyle(
                      color: isSent ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isSent) ...[
            const SizedBox(width: 8),
            // 发送消息头像
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
          
          // 删除按钮
          if (widget.showDeleteButton)
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
        ],
      ),
    );
  }
}
