import 'dart:io';
import 'package:excel/excel.dart';
import '../db/extended_database_helper.dart';
import '../../models/models.dart';

/// Result summary from an Excel import operation
class ImportResult {
  final int added;
  final int updated;
  final int failed;
  final List<String> errors;

  ImportResult({
    required this.added,
    required this.updated,
    required this.failed,
    required this.errors,
  });
}

/// Service for importing students from .xlsx files
class ExcelImportService {
  static final ExcelImportService instance = ExcelImportService._();
  ExcelImportService._();

  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  /// Required columns in the Excel template
  static const List<String> requiredColumns = [
    'registration_no',
    'roll_no',
    'full_name',
    'father_name',
    'guardian_name',
    'guardian_phone',
    'class_name',
    'section_name',
    'gender',
  ];

  /// All expected columns
  static const List<String> allColumns = [
    'registration_no',
    'roll_no',
    'full_name',
    'father_name',
    'guardian_name',
    'guardian_phone',
    'guardian_phone_2',
    'class_name',
    'section_name',
    'gender',
    'dob',
    'address',
  ];

  /// Import students from an Excel file path
  Future<ImportResult> importStudents(String filePath) async {
    int added = 0;
    int updated = 0;
    int failed = 0;
    final errors = <String>[];

    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Use first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      if (sheet.maxRows < 2) {
        return ImportResult(
            added: 0, updated: 0, failed: 0, errors: ['File is empty']);
      }

      // Build column index map from header row
      final headerRow = sheet.row(0);
      final columnMap = <String, int>{};
      for (int i = 0; i < headerRow.length; i++) {
        final cellValue = headerRow[i]?.value?.toString().trim().toLowerCase();
        if (cellValue != null) {
          columnMap[cellValue] = i;
        }
      }

      // Validate required columns
      for (final col in requiredColumns) {
        if (!columnMap.containsKey(col)) {
          errors.add('Missing required column: $col');
        }
      }
      if (errors.isNotEmpty) {
        return ImportResult(
            added: 0, updated: 0, failed: 0, errors: errors);
      }

      // Process each data row
      for (int row = 1; row < sheet.maxRows; row++) {
        try {
          final rowData = sheet.row(row);
          String get(String col) =>
              columnMap[col] != null
                  ? rowData[columnMap[col]!]?.value?.toString().trim() ?? ''
                  : '';

          final regNo = get('registration_no');
          if (regNo.isEmpty) continue; // Skip empty rows

          final className = get('class_name');
          final sectionName = get('section_name');

          if (className.isEmpty || sectionName.isEmpty) {
            failed++;
            errors.add('Row ${row + 1}: class_name or section_name is empty');
            continue;
          }

          // Get or create class
          int classId;
          final existingClass = await _db.getClassByName(className);
          if (existingClass != null) {
            classId = existingClass.id!;
          } else {
            classId = await _db.insertClass(SchoolClass(className: className));
          }

          // Get or create section
          int sectionId;
          final existingSection =
              await _db.getSectionByName(classId, sectionName);
          if (existingSection != null) {
            sectionId = existingSection.id!;
          } else {
            sectionId = await _db
                .insertSection(Section(classId: classId, sectionName: sectionName));
          }

          final student = Student(
            registrationNo: regNo,
            rollNo: get('roll_no'),
            fullName: get('full_name'),
            fatherName: get('father_name'),
            guardianName: get('guardian_name'),
            guardianPhone: get('guardian_phone'),
            guardianPhone2: get('guardian_phone_2').isEmpty
                ? null
                : get('guardian_phone_2'),
            classId: classId,
            sectionId: sectionId,
            gender: get('gender').isEmpty ? 'Male' : get('gender'),
            dob: get('dob').isEmpty ? null : get('dob'),
            address: get('address').isEmpty ? null : get('address'),
          );

          // Upsert logic
          final existing = await _db.getStudentByRegNo(regNo);
          if (existing != null) {
            await _db.updateStudent(student.copyWith(id: existing.id));
            updated++;
          } else {
            await _db.insertStudent(student);
            added++;
          }
        } catch (e) {
          failed++;
          errors.add('Row ${row + 1}: ${e.toString()}');
        }
      }
    } catch (e) {
      errors.add('Failed to read file: ${e.toString()}');
    }

    return ImportResult(
        added: added, updated: updated, failed: failed, errors: errors);
  }

  /// Generate and save a sample Excel template file
  Future<String> generateSampleTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Students'];

    // Header row
    for (int i = 0; i < allColumns.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        TextCellValue(allColumns[i]),
      );
    }

    // Sample data row
    final sampleData = [
      'REG-001', 'R001', 'Ahmed Ali', 'Muhammad Ali', 'Muhammad Ali',
      '03001234567', '03009876543', 'Class 1', 'A', 'Male',
      '2015-01-15', '123 Main Street, Karachi',
    ];
    for (int i = 0; i < sampleData.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
        TextCellValue(sampleData[i]),
      );
    }

    // Save to Downloads
    const savePath = '/storage/emulated/0/Download/School\'s Files/Templates/student_import_template.xlsx';
    await File(savePath).parent.create(recursive: true);
    final fileBytes = excel.save();
    if (fileBytes != null) {
      await File(savePath).writeAsBytes(fileBytes);
    }
    return savePath;
  }
}
