import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../db/extended_database_helper.dart';

const String _appVersion = '1.0.0';
const int _backupVersion = 2;

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  Future<String> createBackup() async {
    final data = await _db.exportAllData();
    final backup = {
      'app_version': _appVersion,
      'backup_version': _backupVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': data,
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
    final dir = await _getBackupDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-').substring(0, 19);
    final filePath = '${dir.path}/school_backup_$timestamp.json';
    await File(filePath).writeAsString(jsonStr, encoding: utf8);
    return filePath;
  }

  Future<String> restoreFromFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], allowMultiple: false);
    if (result == null || result.files.isEmpty) return 'No file selected';
    final filePath = result.files.first.path;
    if (filePath == null) return 'Cannot access file';
    return restoreFromPath(filePath);
  }

  Future<String> restoreFromPath(String filePath) async {
    try {
      final content = await File(filePath).readAsString(encoding: utf8);
      final Map<String, dynamic> backup = jsonDecode(content);
      if (!backup.containsKey('data') || !backup.containsKey('backup_version')) return 'Invalid backup file format';
      final data = backup['data'] as Map<String, dynamic>;
      await _db.restoreAllData(data);
      final createdAt = backup['created_at'] ?? 'Unknown date';
      return 'Restore successful! Backup was created on $createdAt';
    } on FormatException {
      return 'File is not valid JSON';
    } catch (e) {
      return 'Restore failed: ${e.toString()}';
    }
  }

  Future<Directory> _getBackupDirectory() async {
    final externalDir = await getExternalStorageDirectory();
    final backupPath = '${externalDir!.path}/SchoolManager/Backups';
    final dir = Directory(backupPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<FileSystemEntity>> listBackups() async {
    try {
      final dir = await _getBackupDirectory();
      final files = dir.listSync()..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files.where((f) => f.path.endsWith('.json')).toList();
    } catch (_) { return []; }
  }
}
