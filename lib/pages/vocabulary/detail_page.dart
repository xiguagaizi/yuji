import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../models/vocabulary_record.m.dart';
import '../../provider/vocabulary_store.p.dart';
import '../../components/audio_player/audio_player_widget.dart';
import '../../components/voice_recorder/voice_recorder.dart';

/// 词汇详情页面
class DetailPage extends StatefulWidget {
  final String recordId;

  const DetailPage({
    super.key,
    required this.recordId,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  VocabularyRecord? _record;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isReRecording = false;
  String? _newAudioPath;
  int _newAudioDuration = 0;
  String _audioFilePath = '';

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 加载记录
  Future<void> _loadRecord() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
      await vocabularyStore.initialize();
      final record = vocabularyStore.getRecordById(widget.recordId);
      
      if (record != null) {
        setState(() {
          _record = record;
          _wordController.text = record.word;
          _noteController.text = record.note;
        });
        
        // 获取音频文件完整路径
        _audioFilePath = await vocabularyStore.getAudioFilePath(record.audioPath);
      }
    } catch (e) {
      print('加载记录失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 切换编辑模式
  void _toggleEditMode() {
    if (_isEditing) {
      // 取消编辑，恢复原始内容
      _wordController.text = _record?.word ?? '';
      _noteController.text = _record?.note ?? '';
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  /// 保存编辑
  Future<void> _saveEdit() async {
    if (_wordController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: '词汇不能为空');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
      final updatedRecord = _record!.copyWith(
        word: _wordController.text.trim(),
        note: _noteController.text.trim(),
      );

      await vocabularyStore.updateRecord(updatedRecord);
      
      setState(() {
        _record = updatedRecord;
        _isEditing = false;
      });

      Fluttertoast.showToast(msg: '保存成功');
    } catch (e) {
      Fluttertoast.showToast(msg: '保存失败: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// 开始重新录制
  void _startReRecord() {
    setState(() {
      _isReRecording = true;
      _newAudioPath = null;
      _newAudioDuration = 0;
    });
  }

  /// 取消重新录制
  void _cancelReRecord() {
    setState(() {
      _isReRecording = false;
      _newAudioPath = null;
      _newAudioDuration = 0;
    });
  }

  /// 处理重新录音完成
  void _handleReRecordComplete(String filePath, int duration) {
    setState(() {
      _newAudioPath = filePath;
      _newAudioDuration = duration;
    });
  }

  /// 确认保存新录音
  Future<void> _saveNewRecording() async {
    if (_newAudioPath == null) {
      Fluttertoast.showToast(msg: '请先录制语音');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
      await vocabularyStore.reRecordAudio(
        recordId: widget.recordId,
        newAudioSourcePath: _newAudioPath!,
        newAudioDuration: _newAudioDuration,
      );

      // 重新加载记录
      await _loadRecord();

      setState(() {
        _isReRecording = false;
        _newAudioPath = null;
        _newAudioDuration = 0;
      });

      Fluttertoast.showToast(msg: '重新录制成功');
    } catch (e) {
      Fluttertoast.showToast(msg: '保存录音失败: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// 删除记录
  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${_record?.word}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
        await vocabularyStore.deleteRecord(widget.recordId);
        if (mounted) {
          Navigator.pop(context, true); // 返回并刷新列表
        }
      } catch (e) {
        Fluttertoast.showToast(msg: '删除失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: Text('记录不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('词汇详情'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isReRecording)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: _toggleEditMode,
            ),
          if (!_isEditing && !_isReRecording)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteRecord();
                } else if (value == 'rerecord') {
                  _startReRecord();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rerecord',
                  child: Row(
                    children: [
                      Icon(Icons.mic, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('重新录制'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 词汇内容
            if (_isEditing)
              TextField(
                controller: _wordController,
                decoration: InputDecoration(
                  labelText: '词汇或句子',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 2,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Text(
                  _record!.word,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 备注内容
            if (_isEditing)
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              )
            else if (_record!.note.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '备注',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _record!.note,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

            if (_isEditing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _toggleEditMode,
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // 音频播放区域
            if (!_isReRecording) ...[
              const Text(
                '语音朗读',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // 按住播放模式
              AudioPlayerWidget(
                audioPath: _audioFilePath,
                mode: AudioPlayerMode.holdToPlay,
                totalDuration: _record!.audioDuration,
              ),
            ],

            // 重新录制界面
            if (_isReRecording) ...[
              const Text(
                '重新录制',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              
              if (_newAudioPath == null)
                Center(
                  child: VoiceRecorder(
                    onRecordingComplete: _handleReRecordComplete,
                    maxDuration: 300,
                    size: 80,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      AudioPlayerWidget(
                        audioPath: _newAudioPath!,
                        mode: AudioPlayerMode.holdToPlay,
                        totalDuration: _newAudioDuration,
                        primaryColor: Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _newAudioPath = null;
                            _newAudioDuration = 0;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新录制'),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelReRecord,
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isSaving || _newAudioPath == null) ? null : _saveNewRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('保存新录音'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // 记录信息
            if (!_isEditing && !_isReRecording)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('创建时间', _formatDateTime(_record!.createTime)),
                    if (_record!.updateTime != _record!.createTime) ...[
                      const Divider(height: 16),
                      _buildInfoRow('更新时间', _formatDateTime(_record!.updateTime)),
                    ],
                    const Divider(height: 16),
                    _buildInfoRow('音频时长', _record!.getFormattedDuration()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

