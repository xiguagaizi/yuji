import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vocabulary_record.m.dart';
import '../../provider/vocabulary_store.p.dart';
import './detail_page.dart';

/// 词汇查看页面
class ViewPage extends StatefulWidget {
  const ViewPage({super.key});

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  
  List<VocabularyRecord> _displayRecords = [];
  Map<String, List<VocabularyRecord>> _groupedRecords = {};
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    
    // 监听搜索输入
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// 加载词汇记录
  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
      await vocabularyStore.initialize();
      _updateDisplayRecords();
    } catch (e) {
      print('加载记录失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 更新显示的记录
  void _updateDisplayRecords() {
    final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
    
    if (_searchController.text.isEmpty) {
      // 显示所有记录，按日期分组
      setState(() {
        _isSearching = false;
        _groupedRecords = vocabularyStore.getGroupedRecords();
        _displayRecords = vocabularyStore.getAllRecords();
      });
    } else {
      // 搜索模式
      setState(() {
        _isSearching = true;
        _displayRecords = vocabularyStore.searchRecords(_searchController.text);
        _groupedRecords = {};
      });
    }
  }

  /// 搜索输入变化
  void _onSearchChanged() {
    _updateDisplayRecords();
  }

  /// 删除记录（这个方法暂时不用，删除功能已经在 Dismissible 中实现）
  @Deprecated('使用 Dismissible 中的删除逻辑')
  Future<void> _deleteRecord(VocabularyRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${record.word}」吗？'),
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
        await vocabularyStore.deleteRecord(record.id);
        _updateDisplayRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  /// 打开详情页
  Future<void> _openDetailPage(VocabularyRecord record) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPage(recordId: record.id),
      ),
    );

    // 从详情页返回后刷新列表
    if (result == true) {
      _updateDisplayRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // 去掉返回按钮
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.library_books,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '词汇笔记',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索词汇或备注',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // 记录列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  /// 构建记录列表
  Widget _buildRecordsList() {
    if (_displayRecords.isEmpty) {
      return _buildEmptyState();
    }

    if (_isSearching) {
      return _buildSearchResults();
    } else {
      return _buildGroupedList();
    }
  }

  /// 构建空状态
  Widget _buildEmptyState() {
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
              _searchController.text.isNotEmpty ? Icons.search_off : Icons.mic_none,
              size: 80,
              color: const Color(0xFF4A90E2).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isNotEmpty ? '未找到相关记录' : '还没有词汇记录',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '点击下方「记录」标签开始添加',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建搜索结果列表
  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _displayRecords.length,
      itemBuilder: (context, index) {
        final record = _displayRecords[index];
        return _buildRecordCard(record);
      },
    );
  }

  /// 构建分组列表
  Widget _buildGroupedList() {
    final groupKeys = ['today', 'yesterday', 'thisWeek', 'thisMonth', 'earlier'];
    final existingGroups = groupKeys.where((key) => _groupedRecords.containsKey(key)).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: existingGroups.length,
      itemBuilder: (context, index) {
        final groupKey = existingGroups[index];
        final records = _groupedRecords[groupKey]!;
        return _buildGroupSection(groupKey, records);
      },
    );
  }

  /// 构建分组区块
  Widget _buildGroupSection(String groupKey, List<VocabularyRecord> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                VocabularyRecord.getGroupDisplayName(groupKey),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${records.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF357ABD),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...records.map((record) => _buildRecordCard(record)),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 构建记录卡片
  Widget _buildRecordCard(VocabularyRecord record) {
    final keyword = _searchController.text.toLowerCase();
    
    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除「${record.word}」吗？'),
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
      },
      onDismissed: (direction) async {
        final vocabularyStore = Provider.of<VocabularyStore>(context, listen: false);
        await vocabularyStore.deleteRecord(record.id);
        _updateDisplayRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
        }
      },
      child: Card(
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
          child: InkWell(
            onTap: () => _openDetailPage(record),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        record.note,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          ),
        ),
      ),
    );
  }
}

