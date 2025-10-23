import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../components/voice_recorder/voice_recorder.dart';
import '../../provider/vocabulary_store.p.dart';
import '../../models/vocabulary_record.m.dart';

/// 词汇记录页面
class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  String? _recordedAudioPath;
  int _recordedDuration = 0;
  bool _isSaving = false;
  bool _isNoteExpanded = false; // 备注区域是否展开
  bool _isRecording = false; // 是否正在录音
  int _currentRecordingDuration = 0; // 当前录音时长
  
  List<VocabularyRecord> _recentRecords = []; // 最近的录音记录
  
  // 页面刷新方法
  void refreshPageData() {
    _loadRecentRecords();
  }
  
  // 底部播放器状态
  AudioPlayer? _bottomPlayer; // 底部播放器实例
  bool _isBottomPlaying = false; // 底部是否正在播放
  
  // 列表播放器状态
  AudioPlayer? _listPlayer; // 列表播放器实例
  String? _playingRecordId; // 正在播放的记录ID
  bool _isListPlaying = false; // 列表是否正在播放

  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _loadRecentRecords();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _noteController.dispose();
    _bottomPlayer?.dispose();
    _listPlayer?.dispose();
    super.dispose();
  }

  /// 加载最近的录音记录
  Future<void> _loadRecentRecords() async {
    try {
      final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
      await vocabularyStore.initialize();
      final allRecords = vocabularyStore.getAllRecords();
      setState(() {
        // 只显示最近的10条记录
        _recentRecords = allRecords.take(10).toList();
      });
    } catch (e) {
      print('加载记录失败: $e');
    }
  }

  /// 处理录音完成
  void _handleRecordingComplete(String filePath, int duration) {
    setState(() {
      _recordedAudioPath = filePath;
      _recordedDuration = duration;
      _isRecording = false;
      _currentRecordingDuration = 0;
    });
  }

  /// 处理录音取消
  void _handleRecordingCancel() {
    setState(() {
      _recordedAudioPath = null;
      _recordedDuration = 0;
      _isRecording = false;
      _currentRecordingDuration = 0;
    });
  }

  /// 处理录音状态变化
  void _handleRecordingStateChanged(bool isRecording) {
    setState(() {
      _isRecording = isRecording;
      if (!isRecording) {
        _currentRecordingDuration = 0;
      }
    });
  }

  /// 处理录制时长变化
  void _handleDurationChanged(int duration) {
    setState(() {
      _currentRecordingDuration = duration;
    });
  }

  /// 重新录制
  void _reRecord() {
    // 停止并释放播放器
    _bottomPlayer?.stop();
    _bottomPlayer?.dispose();
    _bottomPlayer = null;
    
    _listPlayer?.stop();
    _listPlayer?.dispose();
    _listPlayer = null;
    
    setState(() {
      _recordedAudioPath = null;
      _recordedDuration = 0;
      _isBottomPlaying = false;
      _isListPlaying = false;
      _playingRecordId = null;
    });
  }

  /// 保存词汇记录
  Future<void> _saveRecord() async {
    // 验证输入
    if (_wordController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: '请输入词汇内容');
      return;
    }

    if (_recordedAudioPath == null) {
      Fluttertoast.showToast(msg: '请录制语音');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
      await vocabularyStore.addRecord(
        word: _wordController.text.trim(),
        note: _noteController.text.trim(),
        audioSourcePath: _recordedAudioPath!,
        audioDuration: _recordedDuration,
      );

      Fluttertoast.showToast(msg: '保存成功');

      // 停止并释放播放器
      _bottomPlayer?.stop();
      _bottomPlayer?.dispose();
      _bottomPlayer = null;
      
      _listPlayer?.stop();
      _listPlayer?.dispose();
      _listPlayer = null;

      // 清空输入
      _wordController.clear();
      _noteController.clear();
      setState(() {
        _recordedAudioPath = null;
        _recordedDuration = 0;
        _isNoteExpanded = false; // 收起备注区域
        _isBottomPlaying = false;
        _isListPlaying = false;
        _playingRecordId = null;
      });
      
      // 刷新最近记录列表
      await _loadRecentRecords();
    } catch (e) {
      Fluttertoast.showToast(msg: '保存失败: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// 格式化时长显示
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${remainingSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('记录词汇'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4A90E2).withOpacity(0.05),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // 上半部分：录音数据列表
            Expanded(
              flex: 3,
              child: _buildRecordsList(),
            ),
            
            // 下半部分：录音控制区域
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 录音时长显示（录音时显示）
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(_currentRecordingDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // 展开/收起备注按钮
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isNoteExpanded = !_isNoteExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isNoteExpanded ? Icons.expand_less : Icons.expand_more,
                              color: const Color(0xFF4A90E2),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isNoteExpanded ? '收起备注' : '点击展开添加备注',
                              style: const TextStyle(
                                color: Color(0xFF4A90E2),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 词汇输入框和录音按钮同一行
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 词汇输入框
                        Expanded(
                          child: TextField(
                            controller: _wordController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.text_fields, color: Color(0xFF4A90E2), size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            ),
                            maxLines: null, // 允许自动换行
                            minLines: 1, // 最少1行
                            textInputAction: TextInputAction.newline, // 支持换行
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // 录音按钮或操作按钮组
                        if (_recordedAudioPath == null)
                          VoiceRecorder(
                            onRecordingComplete: _handleRecordingComplete,
                            onRecordingCancel: _handleRecordingCancel,
                            onRecordingStateChanged: _handleRecordingStateChanged,
                            onDurationChanged: _handleDurationChanged,
                            maxDuration: 300,
                            size: 48, // 增大录音按钮尺寸
                            showDuration: false,
                          )
                        else
                          SizedBox(
                            height: 48, // 调整高度与录音按钮一致
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 播放/暂停按钮
                                _buildActionButton(
                                  icon: _isBottomPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.blue,
                                  label: _isBottomPlaying ? '暂停' : '播放',
                                  onTap: _toggleBottomPlayPause,
                                ),
                                const SizedBox(width: 8),
                                // 重录按钮
                                _buildActionButton(
                                  icon: Icons.refresh,
                                  color: Colors.orange,
                                  label: '重录',
                                  onTap: _reRecord,
                                ),
                                const SizedBox(width: 8),
                                // 保存按钮
                                _buildActionButton(
                                  icon: _isSaving ? null : Icons.check,
                                  color: Colors.green,
                                  label: '保存',
                                  onTap: _isSaving ? null : _saveRecord,
                                  isLoading: _isSaving,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // 备注输入框（可展开）
                    if (_isNoteExpanded) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          labelText: '备注',
                          hintText: '可添加释义、例句等（选填）',
                          prefixIcon: const Icon(Icons.note_alt_outlined, color: Color(0xFF4A90E2), size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                      ),
                    ],

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建录音数据列表
  Widget _buildRecordsList() {
    if (_recentRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_none,
                size: 80,
                color: const Color(0xFF4A90E2).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '还没有录音记录',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '开始录制第一条语音吧',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentRecords.length,
      itemBuilder: (context, index) {
        final record = _recentRecords[index];
        return _buildRecordCard(record);
      },
    );
  }

  /// 构建录音数据卡片（基于view_page设计，右侧添加播放按钮）
  Widget _buildRecordCard(VocabularyRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFF4A90E2).withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左侧：词汇信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.word,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4A90E2).withOpacity(0.15),
                                const Color(0xFF357ABD).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.headphones, size: 15, color: Color(0xFF357ABD)),
                              const SizedBox(width: 4),
                              Text(
                                record.getFormattedDuration(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF357ABD),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    if (record.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        record.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 10),
                    
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          record.getFormattedDate(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 右侧：播放按钮
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    // 根据播放状态显示不同图标
                    (_playingRecordId == record.id && _isListPlaying)
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _toggleListPlayPause(record);
                  },
                  iconSize: 28,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换列表播放/暂停
  Future<void> _toggleListPlayPause(VocabularyRecord record) async {
    try {
      // 立即更新UI状态，让用户看到响应
      setState(() {
        if (_playingRecordId == record.id && _isListPlaying) {
          // 如果点击的是当前播放的记录，则暂停
          _isListPlaying = false;
        } else {
          // 如果点击的是其他记录或未播放的记录，则开始播放
          _playingRecordId = record.id;
          _isListPlaying = true;
        }
      });

      // 如果正在播放同一个记录，则暂停
      if (_playingRecordId == record.id && !_isListPlaying) {
        await _listPlayer?.pause();
        return;
      }
      
      // 如果正在播放不同的记录，先停止当前播放
      if (_listPlayer != null) {
        await _listPlayer?.stop();
        await _listPlayer?.dispose();
        _listPlayer = null;
      }
      
      // 获取完整的音频文件路径
      final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
      final fullAudioPath = await vocabularyStore.getAudioFilePath(record.audioPath);
      
      // 检查音频文件是否存在
      final audioFile = File(fullAudioPath);
      if (!await audioFile.exists()) {
        Fluttertoast.showToast(msg: '音频文件不存在');
        setState(() {
          _isListPlaying = false;
          _playingRecordId = null;
        });
        return;
      }
      
      // 开始播放新的记录
      _listPlayer = AudioPlayer();
      await _listPlayer!.setFilePath(fullAudioPath);
      
      // 监听播放完成
      _listPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() {
              _isListPlaying = false;
              _playingRecordId = null;
            });
          }
        }
      });
      
      await _listPlayer!.play();
    } catch (e) {
      print('播放失败: $e');
      Fluttertoast.showToast(msg: '播放失败: ${e.toString()}');
      setState(() {
        _isListPlaying = false;
        _playingRecordId = null;
      });
    }
  }

  // 构建操作按钮（只显示图标）
  Widget _buildActionButton({
    IconData? icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48, // 增大按钮宽度
        height: 48, // 增大按钮高度
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              : Icon(icon, color: color, size: 22), // 增大图标尺寸
        ),
      ),
    );
  }

  // 底部播放/暂停切换
  Future<void> _toggleBottomPlayPause() async {
    if (_recordedAudioPath == null) return;
    
    try {
      if (_bottomPlayer == null) {
        // 首次播放，创建播放器
        _bottomPlayer = AudioPlayer();
        await _bottomPlayer!.setFilePath(_recordedAudioPath!);
        
        // 监听播放状态
        _bottomPlayer!.playerStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _isBottomPlaying = state.playing;
            });
            
            // 播放完成后重置
            if (state.processingState == ProcessingState.completed) {
              _bottomPlayer?.seek(Duration.zero);
              _bottomPlayer?.pause();
            }
          }
        });
        
        await _bottomPlayer!.play();
      } else {
        // 已有播放器，切换播放/暂停
        if (_isBottomPlaying) {
          await _bottomPlayer!.pause();
        } else {
          await _bottomPlayer!.play();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

