import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/logger.dart';

/// Màn hình Debug để xem và quản lý logs
/// Truy cập: Thêm button trong Settings hoặc dùng hidden gesture
class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  List<File> _logFiles = [];
  File? _currentLogFile;
  String? _logContent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await AppLogger.getAllLogFiles();
      _currentLogFile = AppLogger.logFile;
      setState(() {
        _logFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load log files: $e');
    }
  }

  Future<void> _loadLogContent(File file) async {
    setState(() => _isLoading = true);
    try {
      final content = await AppLogger.readLogFile(file);
      setState(() {
        _logContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load log content: $e');
    }
  }

  Future<void> _shareLogFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Chess AI Log - ${_getFileName(file)}',
        text: 'Log file từ Chess AI app',
      );
    } catch (e) {
      _showError('Failed to share log: $e');
    }
  }

  Future<void> _copyLogPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Log path copied to clipboard')),
      );
    }
  }

  Future<void> _clearAllLogs() async {
    final confirm = await _showConfirmDialog(
      'Xóa tất cả logs?',
      'Bạn có chắc muốn xóa tất cả log files? Hành động này không thể hoàn tác.',
    );

    if (confirm == true) {
      try {
        await AppLogger.clearAllLogs();
        await _loadLogFiles();
        setState(() => _logContent = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ All logs cleared')),
          );
        }
      } catch (e) {
        _showError('Failed to clear logs: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  String _getFileName(File file) {
    return file.path.split('/').last;
  }

  String _getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileTime(File file) {
    final modified = file.lastModifiedSync();
    final now = DateTime.now();
    final diff = now.difference(modified);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐛 Debug Logs'),
        actions: [
          if (_logFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all logs',
              onPressed: _clearAllLogs,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLogFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logContent != null
              ? _buildLogViewer()
              : _buildLogFilesList(),
    );
  }

  Widget _buildLogFilesList() {
    if (_logFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không có log files',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Log files sẽ được tạo khi app chạy',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Current log file info
        if (_currentLogFile != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Current Log File',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentLogFile!.path,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy path',
                      onPressed: () => _copyLogPath(_currentLogFile!.path),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Log files list
        Expanded(
          child: ListView.builder(
            itemCount: _logFiles.length,
            itemBuilder: (context, index) {
              final file = _logFiles[index];
              final isCurrent = file.path == _currentLogFile?.path;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.description,
                    color: isCurrent ? Colors.green : Colors.grey,
                  ),
                  title: Text(
                    _getFileName(file),
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text('${_getFileSize(file)} • ${_getFileTime(file)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        tooltip: 'View',
                        onPressed: () => _loadLogContent(file),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'Share',
                        onPressed: () => _shareLogFile(file),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogViewer() {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _logContent = null),
              ),
              const Text('Log Content'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy_all),
                tooltip: 'Copy all',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _logContent!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),

        // Log content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _logContent ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
