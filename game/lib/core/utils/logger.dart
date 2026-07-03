import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static Logger? _logger;
  static File? _logFile;
  static bool _isInitialized = false;

  // Public getter để kiểm tra trạng thái
  static bool get isInitialized => _isInitialized;

  // Public getter để lấy log file
  static File? get logFile => _logFile;

  /// Initialize logger với file output
  /// GỌI HÀM NÀY TRONG main() trước khi runApp()
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Lấy app's document directory
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      // Tạo thư mục logs nếu chưa có
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Tạo log file với timestamp trong tên
      final timestamp = DateTime.now().toIso8601String().split('.')[0].replaceAll(':', '-');
      _logFile = File('${logsDir.path}/kings_gambit_ai_$timestamp.log');

      // Giới hạn số file logs (giữ tối đa 5 file gần nhất)
      await _cleanOldLogs(logsDir);

      // Khởi tạo logger với multi-output (console + file)
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: !kReleaseMode, // Chỉ dùng màu ở debug mode
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
        output: MultiOutput([
          ConsoleOutput(),
          _FileOutput(_logFile!),
        ]),
      );

      _isInitialized = true;

      // Ghi log đầu tiên
      info('📱 King\'s Gambit AI Logger initialized');
      info('📁 Log file: ${_logFile!.path}');
      info('🔧 Build mode: ${kReleaseMode ? "Release" : "Debug"}');
    } catch (e) {
      // Fallback về console-only logger nếu file output fail
      debugPrint('⚠️ Failed to initialize file logger: $e');
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
      );
      _isInitialized = true;
    }
  }

  /// Xóa các file log cũ, giữ lại tối đa maxFiles file gần nhất
  static Future<void> _cleanOldLogs(Directory logsDir, {int maxFiles = 5}) async {
    try {
      final files = logsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();

      if (files.length <= maxFiles) return;

      // Sort theo thời gian sửa đổi (cũ nhất trước)
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      // Xóa các file cũ, giữ lại maxFiles file mới nhất
      final filesToDelete = files.sublist(0, files.length - maxFiles);
      for (final file in filesToDelete) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to clean old logs: $e');
    }
  }

  /// Lấy đường dẫn tới log file hiện tại
  static String? getLogFilePath() {
    return _logFile?.path;
  }

  /// Lấy tất cả log files
  static Future<List<File>> getAllLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        return [];
      }

      return logsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      debugPrint('Failed to get log files: $e');
      return [];
    }
  }

  /// Đọc nội dung log file
  static Future<String?> readLogFile([File? file]) async {
    try {
      final targetFile = file ?? _logFile;
      if (targetFile == null || !await targetFile.exists()) {
        return null;
      }
      return await targetFile.readAsString();
    } catch (e) {
      debugPrint('Failed to read log file: $e');
      return null;
    }
  }

  /// Xóa tất cả log files
  static Future<void> clearAllLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        return;
      }

      final files = logsDir.listSync().whereType<File>();
      for (final file in files) {
        await file.delete();
      }

      info('🗑️ All log files cleared');
    } catch (e) {
      error('Failed to clear logs', e);
    }
  }

  // Log methods
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.d(message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.i(message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.w(message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }

  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.f(message, error: error, stackTrace: stackTrace);
  }
}

/// Custom file output cho Logger
class _FileOutput extends LogOutput {
  final File file;

  _FileOutput(this.file);

  @override
  void output(OutputEvent event) {
    try {
      // Ghi từng dòng log vào file
      for (var line in event.lines) {
        // Remove ANSI color codes trước khi ghi vào file
        final cleanLine = line.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
        file.writeAsStringSync('$cleanLine\n', mode: FileMode.append);
      }
    } catch (e) {
      debugPrint('Failed to write log to file: $e');
    }
  }
}
