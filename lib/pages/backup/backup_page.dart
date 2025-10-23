import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import '../../provider/vocabulary_store.p.dart';
import '../../services/backup_service.dart';

/// 备份页面
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final BackupService _backupService = BackupService();
  bool _isExporting = false;
  bool _isImporting = false;
  String? _selectedExportPath;
  String? _selectedImportPath;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('数据备份'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明卡片
            _buildInfoCard(),
            SizedBox(height: 20.h),
            
            // 导出功能
            _buildExportSection(),
            SizedBox(height: 20.h),
            
            // 导入功能
            _buildImportSection(),
            SizedBox(height: 20.h),
            
            // 数据统计
            _buildDataStats(),
          ],
        ),
      ),
    );
  }

  /// 说明信息卡片
  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 48.sp),
                    SizedBox(width: 20.w),
                    Text(
                      '备份说明',
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
            SizedBox(height: 12.h),
            Text(
              '• 导出：将当前所有笔记数据（包括录音文件）导出到指定目录\n'
              '• 导入：从指定目录导入备份数据，会覆盖当前数据\n'
              '• 建议定期备份，避免数据丢失',
              style: TextStyle(
                fontSize: 24.sp,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// 导出功能区域
  Widget _buildExportSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_outlined, color: Colors.green[600], size: 48.sp),
                SizedBox(width: 20.w),
                Text(
                  '导出数据',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              '将当前所有笔记和录音文件导出到指定目录',
              style: TextStyle(
                fontSize: 24.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16.h),
            // 显示已选择的导出目录
            if (_selectedExportPath != null) ...[
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: Colors.green[600], size: 24.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '导出目录: ${path.basename(_selectedExportPath!)}',
                        style: TextStyle(
                          fontSize: 22.sp,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
            ],
            // 选择目录按钮
            SizedBox(
              width: double.infinity,
              height: 72.h,
              child: ElevatedButton.icon(
                onPressed: _selectExportDirectoryWithSAF,
                icon: Icon(Icons.folder_open_outlined, size: 32.sp),
                label: Text(
                  _selectedExportPath == null ? '选择导出目录' : '重新选择目录',
                  style: TextStyle(fontSize: 26.sp),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            // 导出按钮
            SizedBox(
              width: double.infinity,
              height: 72.h,
              child: ElevatedButton.icon(
                onPressed: (_isExporting || _selectedExportPath == null) ? null : _exportData,
                icon: _isExporting 
                  ? SizedBox(
                      width: 32.w,
                      height: 32.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.file_download_outlined, size: 32.sp),
                label: Text(
                  _isExporting 
                    ? '导出中...' 
                    : _selectedExportPath == null
                      ? '请先选择目录' 
                      : '开始导出',
                  style: TextStyle(fontSize: 26.sp),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 导入功能区域
  Widget _buildImportSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_outlined, color: Colors.orange[600], size: 48.sp),
                SizedBox(width: 20.w),
                Text(
                  '导入数据',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              '从指定目录导入备份数据（会覆盖当前数据）',
              style: TextStyle(
                fontSize: 24.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16.h),
            // 显示已选择的导入目录
            if (_selectedImportPath != null) ...[
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: Colors.orange[600], size: 24.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '导入目录: ${path.basename(_selectedImportPath!)}',
                        style: TextStyle(
                          fontSize: 22.sp,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
            ],
            // 选择目录按钮
            SizedBox(
              width: double.infinity,
              height: 72.h,
              child: ElevatedButton.icon(
                onPressed: _selectImportDirectoryWithSAF,
                icon: Icon(Icons.folder_open_outlined, size: 32.sp),
                label: Text(
                  _selectedImportPath == null ? '选择导入目录' : '重新选择目录',
                  style: TextStyle(fontSize: 26.sp),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            // 导入按钮
            SizedBox(
              width: double.infinity,
              height: 72.h,
              child: ElevatedButton.icon(
                onPressed: (_isImporting || _selectedImportPath == null) ? null : _importData,
                icon: _isImporting 
                  ? SizedBox(
                      width: 32.w,
                      height: 32.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.file_upload_outlined, size: 32.sp),
                label: Text(
                  _isImporting 
                    ? '导入中...' 
                    : _selectedImportPath == null
                      ? '请先选择目录' 
                      : '开始导入',
                  style: TextStyle(fontSize: 26.sp),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 数据统计区域
  Widget _buildDataStats() {
    return Consumer<VocabularyStore>(
      builder: (context, store, child) {
        final records = store.getAllRecords();
        final totalRecords = records.length;
        final totalDuration = records.fold<int>(
          0, 
          (sum, record) => sum + record.audioDuration,
        );
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.purple[600], size: 48.sp),
                    SizedBox(width: 20.w),
                    Text(
                      '数据统计',
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        '总记录数',
                        '$totalRecords 条',
                        Icons.note_outlined,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildStatItem(
                        '总录音时长',
                        _formatDuration(totalDuration),
                        Icons.audiotrack_outlined,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 统计项
  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }


  /// 格式化时长
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  /// 使用SAF选择导出目录
  Future<void> _selectExportDirectoryWithSAF() async {
    try {
      // 使用SAF选择目录
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择导出目录',
        lockParentWindow: true,
      );
      
      if (result != null) {
        setState(() {
          _selectedExportPath = result;
        });
        Fluttertoast.showToast(msg: '已选择导出目录: ${path.basename(result)}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '选择目录失败: $e');
    }
  }

  /// 使用SAF选择导入目录
  Future<void> _selectImportDirectoryWithSAF() async {
    try {
      // 使用SAF选择目录
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择导入目录',
        lockParentWindow: true,
      );
      
      if (result != null) {
        setState(() {
          _selectedImportPath = result;
        });
        Fluttertoast.showToast(msg: '已选择导入目录: ${path.basename(result)}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '选择目录失败: $e');
    }
  }

  /// 导出数据
  Future<void> _exportData() async {
    try {
      setState(() {
        _isExporting = true;
      });

      // 检查是否已选择导出目录
      if (_selectedExportPath == null) {
        Fluttertoast.showToast(msg: '请先选择导出目录');
        return;
      }

      // 执行导出
      await _backupService.exportData(_selectedExportPath!);
      
      Fluttertoast.showToast(msg: '数据导出成功');
    } catch (e) {
      Fluttertoast.showToast(msg: '导出失败: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  /// 导入数据
  Future<void> _importData() async {
    try {
      setState(() {
        _isImporting = true;
      });

      // 检查是否已选择导入目录
      if (_selectedImportPath == null) {
        Fluttertoast.showToast(msg: '请先选择导入目录');
        return;
      }

      // 确认导入
      final confirmed = await _showImportConfirmDialog();
      if (!confirmed) return;

      // 执行导入
      await _backupService.importData(_selectedImportPath!);
      
      // 刷新数据
      final store = Provider.of<VocabularyStore>(context, listen: false);
      await store.initialize();
      
      Fluttertoast.showToast(msg: '数据导入成功');
    } catch (e) {
      Fluttertoast.showToast(msg: '导入失败: $e');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  /// 选择目录
  Future<Directory?> _selectDirectory() async {
    try {
      // 使用 file_picker 选择目录
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        return Directory(selectedDirectory);
      }
      
      // 如果用户取消选择，返回null
      return null;
    } catch (e) {
      print('选择目录失败: $e');
      Fluttertoast.showToast(msg: '选择目录失败: $e');
      return null;
    }
  }

  /// 显示导入确认对话框
  Future<bool> _showImportConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: const Text('导入数据将覆盖当前所有数据，此操作不可撤销。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) ?? false;
  }
}
