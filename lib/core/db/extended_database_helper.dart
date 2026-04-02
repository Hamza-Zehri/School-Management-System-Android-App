import 'dart:developer' as dev;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/models.dart';
import '../../models/extended_models.dart';

/// EXTENDED DatabaseHelper — adds new tables via safe migration.
/// All original tables are untouched. Version bumped to 2.
/// Drop-in replacement for database_helper.dart via mixin extension pattern.
class ExtendedDatabaseHelper {
  static final ExtendedDatabaseHelper instance = ExtendedDatabaseHelper._init();
  static Database? _database;

  ExtendedDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('school_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2, // bumped from 1 → 2
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ============================================================
  // CREATE — all tables (v1 original + v2 new)
  // ============================================================
  Future _createDB(Database db, int version) async {
    await _createOriginalTables(db);
    await _createExtendedTables(db);
    await _seedSmsTemplates(db);
    await db.insert('app_counters', {'counter_key': 'receipt_no', 'counter_value': 0});
  }

  // ============================================================
  // UPGRADE — only adds new tables, never drops existing
  // ============================================================
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      dev.log('[DB] Migrating from v$oldVersion → v$newVersion: adding new tables');
      await _createExtendedTables(db);
      await _seedNewSmsTemplates(db);
      dev.log('[DB] Migration complete');
    }
  }

  // ============================================================
  // ORIGINAL TABLES (v1) — kept identical to database_helper.dart
  // ============================================================
  Future<void> _createOriginalTables(Database db) async {
    await db.execute('''CREATE TABLE school_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT, school_name TEXT NOT NULL,
      school_address TEXT NOT NULL, school_phone TEXT NOT NULL,
      school_email TEXT, logo_path TEXT, current_session TEXT)''');

    await db.execute('''CREATE TABLE classes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, class_name TEXT NOT NULL UNIQUE,
      description TEXT, sort_order INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE sections (
      id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL,
      section_name TEXT NOT NULL, UNIQUE(class_id, section_name),
      FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE)''');

    await db.execute('''CREATE TABLE students (
      id INTEGER PRIMARY KEY AUTOINCREMENT, registration_no TEXT NOT NULL UNIQUE,
      roll_no TEXT NOT NULL, full_name TEXT NOT NULL, father_name TEXT NOT NULL,
      guardian_name TEXT NOT NULL, guardian_phone TEXT NOT NULL,
      guardian_phone_2 TEXT, class_id INTEGER NOT NULL, section_id INTEGER NOT NULL,
      gender TEXT DEFAULT 'Male', dob TEXT, address TEXT, is_active INTEGER DEFAULT 1,
      FOREIGN KEY (class_id) REFERENCES classes(id),
      FOREIGN KEY (section_id) REFERENCES sections(id))''');

    await db.execute('''CREATE TABLE student_promotions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL,
      old_class_id INTEGER NOT NULL, old_section_id INTEGER NOT NULL,
      new_class_id INTEGER NOT NULL, new_section_id INTEGER NOT NULL,
      promotion_year TEXT NOT NULL, promoted_on TEXT NOT NULL, remarks TEXT,
      status TEXT DEFAULT 'promoted', FOREIGN KEY (student_id) REFERENCES students(id))''');

    await db.execute('''CREATE TABLE attendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL,
      attendance_date TEXT NOT NULL, status TEXT NOT NULL, remarks TEXT,
      UNIQUE(student_id, attendance_date),
      FOREIGN KEY (student_id) REFERENCES students(id))''');

    await db.execute('''CREATE TABLE fee_structures (
      id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL UNIQUE,
      monthly_fee REAL DEFAULT 0, exam_fee REAL DEFAULT 0,
      transport_fee REAL DEFAULT 0, other_fee REAL DEFAULT 0,
      FOREIGN KEY (class_id) REFERENCES classes(id))''');

    await db.execute('''CREATE TABLE fee_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL,
      class_id INTEGER NOT NULL, section_id INTEGER NOT NULL,
      month INTEGER NOT NULL, year INTEGER NOT NULL, total_amount REAL DEFAULT 0,
      discount_amount REAL DEFAULT 0, fine_amount REAL DEFAULT 0,
      paid_amount REAL DEFAULT 0, due_date TEXT, payment_date TEXT,
      status TEXT DEFAULT 'unpaid', remarks TEXT,
      UNIQUE(student_id, month, year),
      FOREIGN KEY (student_id) REFERENCES students(id))''');

    await db.execute('''CREATE TABLE fee_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fee_record_id INTEGER NOT NULL,
      receipt_no TEXT NOT NULL UNIQUE, paid_amount REAL NOT NULL,
      payment_date TEXT NOT NULL, payment_method TEXT, remarks TEXT,
      FOREIGN KEY (fee_record_id) REFERENCES fee_records(id))''');

    await db.execute('''CREATE TABLE exams (
      id INTEGER PRIMARY KEY AUTOINCREMENT, exam_name TEXT NOT NULL,
      class_id INTEGER NOT NULL, section_id INTEGER NOT NULL,
      exam_date TEXT, description TEXT, FOREIGN KEY (class_id) REFERENCES classes(id))''');

    await db.execute('''CREATE TABLE subjects (
      id INTEGER PRIMARY KEY AUTOINCREMENT, subject_name TEXT NOT NULL,
      class_id INTEGER NOT NULL, FOREIGN KEY (class_id) REFERENCES classes(id))''');

    await db.execute('''CREATE TABLE marks (
      id INTEGER PRIMARY KEY AUTOINCREMENT, exam_id INTEGER NOT NULL,
      student_id INTEGER NOT NULL, subject_id INTEGER NOT NULL,
      total_marks REAL DEFAULT 0, obtained_marks REAL DEFAULT 0, remarks TEXT,
      UNIQUE(exam_id, student_id, subject_id),
      FOREIGN KEY (exam_id) REFERENCES exams(id),
      FOREIGN KEY (student_id) REFERENCES students(id),
      FOREIGN KEY (subject_id) REFERENCES subjects(id))''');

    await db.execute('''CREATE TABLE sms_templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT, template_key TEXT NOT NULL UNIQUE,
      template_name TEXT NOT NULL, template_body TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE sms_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT, phone_number TEXT NOT NULL,
      message TEXT NOT NULL, sent_at TEXT NOT NULL, status TEXT DEFAULT 'sent',
      student_id INTEGER, purpose TEXT)''');

    await db.execute('''CREATE TABLE app_counters (
      id INTEGER PRIMARY KEY AUTOINCREMENT, counter_key TEXT NOT NULL UNIQUE,
      counter_value INTEGER DEFAULT 0)''');
  }

  // ============================================================
  // NEW TABLES (v2) — employees, salary, student tests
  // ============================================================
  Future<void> _createExtendedTables(Database db) async {
    // ---- employees ----
    await db.execute('''CREATE TABLE IF NOT EXISTS employees (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id TEXT NOT NULL UNIQUE,
      full_name TEXT NOT NULL,
      father_name TEXT NOT NULL,
      phone TEXT NOT NULL,
      cnic TEXT,
      designation TEXT NOT NULL,
      joining_date TEXT,
      salary REAL DEFAULT 0,
      address TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT
    )''');

    // ---- employee_attendance ----
    await db.execute('''CREATE TABLE IF NOT EXISTS employee_attendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id INTEGER NOT NULL,
      attendance_date TEXT NOT NULL,
      status TEXT NOT NULL,
      remarks TEXT,
      UNIQUE(employee_id, attendance_date),
      FOREIGN KEY (employee_id) REFERENCES employees(id)
    )''');

    // ---- salary_records ----
    await db.execute('''CREATE TABLE IF NOT EXISTS salary_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id INTEGER NOT NULL,
      month INTEGER NOT NULL,
      year INTEGER NOT NULL,
      basic_salary REAL DEFAULT 0,
      bonus REAL DEFAULT 0,
      deduction REAL DEFAULT 0,
      paid_amount REAL DEFAULT 0,
      payment_date TEXT,
      status TEXT DEFAULT 'Unpaid',
      remarks TEXT,
      UNIQUE(employee_id, month, year),
      FOREIGN KEY (employee_id) REFERENCES employees(id)
    )''');

    // ---- salary_payments ----
    await db.execute('''CREATE TABLE IF NOT EXISTS salary_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      salary_record_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      payment_date TEXT NOT NULL,
      method TEXT,
      remarks TEXT,
      FOREIGN KEY (salary_record_id) REFERENCES salary_records(id)
    )''');

    // ---- student_tests ----
    await db.execute('''CREATE TABLE IF NOT EXISTS student_tests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      test_date TEXT NOT NULL,
      class_id INTEGER NOT NULL,
      section_id INTEGER NOT NULL,
      subject_id INTEGER NOT NULL,
      title TEXT,
      created_at TEXT,
      FOREIGN KEY (class_id) REFERENCES classes(id),
      FOREIGN KEY (section_id) REFERENCES sections(id),
      FOREIGN KEY (subject_id) REFERENCES subjects(id)
    )''');

    // ---- student_test_marks ----
    await db.execute('''CREATE TABLE IF NOT EXISTS student_test_marks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      test_id INTEGER NOT NULL,
      student_id INTEGER NOT NULL,
      total_marks REAL DEFAULT 0,
      obtained_marks REAL DEFAULT 0,
      remarks TEXT,
      UNIQUE(test_id, student_id),
      FOREIGN KEY (test_id) REFERENCES student_tests(id),
      FOREIGN KEY (student_id) REFERENCES students(id)
    )''');

    dev.log('[DB] Extended tables created/verified');
  }

  // ============================================================
  // SMS SEEDS (original + new)
  // ============================================================
  Future<void> _seedSmsTemplates(Database db) async {
    final templates = [
      {'template_key': 'attendance_absent', 'template_name': 'Attendance Absent',
        'template_body': 'Dear Parent, your child {student_name} ({class_name}-{section_name}) is absent on {date}. Please contact school if needed.'},
      {'template_key': 'fee_unpaid', 'template_name': 'Fee Unpaid Reminder',
        'template_body': 'Dear Parent, fee for {student_name} ({class_name}-{section_name}) amount Rs. {due_amount} for {month_name} {year} is unpaid. Kindly submit before {due_date}.'},
      {'template_key': 'fee_paid', 'template_name': 'Fee Paid Confirmation',
        'template_body': 'Dear Parent, fee payment of Rs. {paid_amount} for {student_name} ({month_name} {year}) has been received successfully on {payment_date}. Thank you.'},
      {'template_key': 'fee_partial', 'template_name': 'Partial Fee Paid',
        'template_body': 'Dear Parent, partial fee payment of Rs. {paid_amount} has been received for {student_name}. Remaining due amount is Rs. {due_amount} for {month_name} {year}.'},
      {'template_key': 'general_notice', 'template_name': 'General School Notice',
        'template_body': 'School Notice: {custom_message}'},
      {'template_key': 'test_result', 'template_name': 'Student Test Result',
        'template_body': 'Dear Parent, {student_name} scored {obtained_marks}/{total_marks} in {subject_name} test on {test_date}. Remarks: {remarks}'},
      {'template_key': 'salary_paid', 'template_name': 'Salary Paid',
        'template_body': 'Dear {employee_name}, your salary of Rs. {amount} for {month} has been paid. Thank you.'},
      {'template_key': 'employee_absent', 'template_name': 'Employee Absent Alert',
        'template_body': 'Dear {employee_name}, you were marked absent on {date}. Please contact admin if incorrect.'},
    ];
    for (final t in templates) {
      await db.insert('sms_templates', t, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedNewSmsTemplates(Database db) async {
    final newTemplates = [
      {'template_key': 'test_result', 'template_name': 'Student Test Result',
        'template_body': 'Dear Parent, {student_name} scored {obtained_marks}/{total_marks} in {subject_name} test on {test_date}. Remarks: {remarks}'},
      {'template_key': 'salary_paid', 'template_name': 'Salary Paid',
        'template_body': 'Dear {employee_name}, your salary of Rs. {amount} for {month} has been paid. Thank you.'},
      {'template_key': 'employee_absent', 'template_name': 'Employee Absent Alert',
        'template_body': 'Dear {employee_name}, you were marked absent on {date}. Please contact admin if incorrect.'},
    ];
    for (final t in newTemplates) {
      await db.insert('sms_templates', t, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ============================================================
  // SCHOOL SETTINGS (delegated — same as original)
  // ============================================================
  Future<SchoolSettings?> getSchoolSettings() async {
    final db = await database;
    final maps = await db.query('school_settings', limit: 1);
    return maps.isEmpty ? null : SchoolSettings.fromMap(maps.first);
  }

  Future<int> saveSchoolSettings(SchoolSettings settings) async {
    final db = await database;
    final existing = await getSchoolSettings();
    if (existing == null) return await db.insert('school_settings', settings.toMap());
    return await db.update('school_settings', settings.toMap(), where: 'id = ?', whereArgs: [existing.id]);
  }

  // ============================================================
  // CLASSES & SECTIONS (full passthrough)
  // ============================================================
  Future<List<SchoolClass>> getAllClasses() async {
    final db = await database;
    final maps = await db.query('classes', orderBy: 'sort_order, class_name');
    return maps.map((m) => SchoolClass.fromMap(m)).toList();
  }

  Future<SchoolClass?> getClassById(int id) async {
    final db = await database;
    final maps = await db.query('classes', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : SchoolClass.fromMap(maps.first);
  }

  Future<SchoolClass?> getClassByName(String name) async {
    final db = await database;
    final maps = await db.query('classes', where: 'class_name = ?', whereArgs: [name]);
    return maps.isEmpty ? null : SchoolClass.fromMap(maps.first);
  }

  Future<int> insertClass(SchoolClass cls) async => await (await database).insert('classes', cls.toMap());
  Future<int> updateClass(SchoolClass cls) async => await (await database).update('classes', cls.toMap(), where: 'id = ?', whereArgs: [cls.id]);
  Future<int> deleteClass(int id) async => await (await database).delete('classes', where: 'id = ?', whereArgs: [id]);

  Future<List<Section>> getSectionsByClass(int classId) async {
    final db = await database;
    final maps = await db.query('sections', where: 'class_id = ?', whereArgs: [classId], orderBy: 'section_name');
    return maps.map((m) => Section.fromMap(m)).toList();
  }

  Future<Section?> getSectionById(int id) async {
    final db = await database;
    final maps = await db.query('sections', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Section.fromMap(maps.first);
  }

  Future<Section?> getSectionByName(int classId, String name) async {
    final db = await database;
    final maps = await db.query('sections', where: 'class_id = ? AND section_name = ?', whereArgs: [classId, name]);
    return maps.isEmpty ? null : Section.fromMap(maps.first);
  }

  Future<int> insertSection(Section section) async => await (await database).insert('sections', section.toMap());
  Future<int> updateSection(Section section) async => await (await database).update('sections', section.toMap(), where: 'id = ?', whereArgs: [section.id]);
  Future<int> deleteSection(int id) async => await (await database).delete('sections', where: 'id = ?', whereArgs: [id]);

  // ============================================================
  // STUDENTS — FIXED: correct JOIN, debug logs
  // ============================================================
  Future<List<Student>> getAllStudents({bool? isActive}) async {
    final db = await database;
    final where = isActive != null ? 'WHERE s.is_active = ${isActive ? 1 : 0}' : '';
    final maps = await db.rawQuery('''
      SELECT s.*, c.class_name, sec.section_name
      FROM students s
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN sections sec ON s.section_id = sec.id
      $where
      ORDER BY c.sort_order, sec.section_name, s.full_name
    ''');
    dev.log('[DB] getAllStudents isActive=$isActive → ${maps.length} rows');
    return maps.map((m) => Student.fromMap(m)).toList();
  }

  /// FIX: explicit column list, correct JOIN, debug logging
  Future<List<Student>> getStudentsByClassSection(int classId, int sectionId, {bool? isActive}) async {
    final db = await database;
    dev.log('[DB] getStudentsByClassSection classId=$classId sectionId=$sectionId isActive=$isActive');

    final conditions = <String>['s.class_id = ?', 's.section_id = ?'];
    final args = <dynamic>[classId, sectionId];
    if (isActive != null) {
      conditions.add('s.is_active = ?');
      args.add(isActive ? 1 : 0);
    }
    final where = conditions.join(' AND ');

    final maps = await db.rawQuery('''
      SELECT
        s.id, s.registration_no, s.roll_no, s.full_name, s.father_name,
        s.guardian_name, s.guardian_phone, s.guardian_phone_2,
        s.class_id, s.section_id, s.gender, s.dob, s.address, s.is_active,
        c.class_name, sec.section_name
      FROM students s
      INNER JOIN classes c ON s.class_id = c.id
      INNER JOIN sections sec ON s.section_id = sec.id
      WHERE $where
      ORDER BY CAST(s.roll_no AS INTEGER), s.full_name
    ''', args);

    dev.log('[DB] getStudentsByClassSection → ${maps.length} students found');
    return maps.map((m) => Student.fromMap(m)).toList();
  }

  Future<List<Student>> searchStudents(String query) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.*, c.class_name, sec.section_name
      FROM students s
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN sections sec ON s.section_id = sec.id
      WHERE s.full_name LIKE ? OR s.registration_no LIKE ? OR s.father_name LIKE ?
      ORDER BY s.full_name
    ''', ['%$query%', '%$query%', '%$query%']);
    return maps.map((m) => Student.fromMap(m)).toList();
  }

  Future<Student?> getStudentById(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.*, c.class_name, sec.section_name
      FROM students s
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN sections sec ON s.section_id = sec.id
      WHERE s.id = ?
    ''', [id]);
    return maps.isEmpty ? null : Student.fromMap(maps.first);
  }

  Future<Student?> getStudentByRegNo(String regNo) async {
    final db = await database;
    final maps = await db.query('students', where: 'registration_no = ?', whereArgs: [regNo]);
    return maps.isEmpty ? null : Student.fromMap(maps.first);
  }

  Future<int> insertStudent(Student student) async => await (await database).insert('students', student.toMap());
  Future<int> updateStudent(Student student) async => await (await database).update('students', student.toMap(), where: 'id = ?', whereArgs: [student.id]);
  Future<int> deleteStudent(int id) async => await (await database).delete('students', where: 'id = ?', whereArgs: [id]);

  Future<int> getTotalStudentCount({bool? isActive}) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM students ${isActive != null ? 'WHERE is_active = ${isActive ? 1 : 0}' : ''}');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ============================================================
  // ATTENDANCE — student
  // ============================================================
  Future<void> saveAttendanceBatch(List<Attendance> records) async {
    final db = await database;
    final batch = db.batch();
    for (final a in records) {
      batch.insert('attendance', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Attendance>> getAttendanceByClassSectionDate(int classId, int sectionId, String date) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT a.*, s.full_name, s.guardian_phone, c.class_name, sec.section_name
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      JOIN classes c ON s.class_id = c.id
      JOIN sections sec ON s.section_id = sec.id
      WHERE s.class_id = ? AND s.section_id = ? AND a.attendance_date = ?
      ORDER BY CAST(s.roll_no AS INTEGER)
    ''', [classId, sectionId, date]);
    return maps.map((m) => Attendance.fromMap(m)).toList();
  }

  /// Student attendance history with date range filter
  Future<List<Attendance>> getStudentAttendanceHistory({
    required int studentId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await database;
    final conditions = ['a.student_id = ?'];
    final args = <dynamic>[studentId];
    if (fromDate != null) { conditions.add('a.attendance_date >= ?'); args.add(fromDate); }
    if (toDate != null) { conditions.add('a.attendance_date <= ?'); args.add(toDate); }
    final maps = await db.rawQuery('''
      SELECT a.*, s.full_name, s.guardian_phone, c.class_name, sec.section_name
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      JOIN classes c ON s.class_id = c.id
      JOIN sections sec ON s.section_id = sec.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY a.attendance_date DESC
    ''', args);
    return maps.map((m) => Attendance.fromMap(m)).toList();
  }

  Future<Map<String, int>> getStudentAttendanceSummary(int studentId, {String? fromDate, String? toDate}) async {
    final db = await database;
    final conditions = ['student_id = ?'];
    final args = <dynamic>[studentId];
    if (fromDate != null) { conditions.add('attendance_date >= ?'); args.add(fromDate); }
    if (toDate != null) { conditions.add('attendance_date <= ?'); args.add(toDate); }
    final results = await db.rawQuery('''
      SELECT status, COUNT(*) as cnt FROM attendance
      WHERE ${conditions.join(' AND ')} GROUP BY status
    ''', args);
    final map = <String, int>{};
    for (final r in results) {
      map[r['status'] as String] = r['cnt'] as int;
    }
    return map;
  }

  Future<Map<String, int>> getAttendanceSummaryForToday(String date) async {
    final db = await database;
    final results = await db.rawQuery('SELECT status, COUNT(*) as cnt FROM attendance WHERE attendance_date = ? GROUP BY status', [date]);
    final map = <String, int>{};
    for (final r in results) {
      map[r['status'] as String] = r['cnt'] as int;
    }
    return map;
  }

  Future<List<Attendance>> getAbsentStudentsForDate(String date) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT a.*, s.full_name, s.guardian_phone, c.class_name, sec.section_name
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      JOIN classes c ON s.class_id = c.id
      JOIN sections sec ON s.section_id = sec.id
      WHERE a.attendance_date = ? AND a.status = 'absent'
    ''', [date]);
    return maps.map((m) => Attendance.fromMap(m)).toList();
  }

  // ============================================================
  // FEE STRUCTURES
  // ============================================================
  Future<FeeStructure?> getFeeStructureByClass(int classId) async {
    final db = await database;
    final maps = await db.query('fee_structures', where: 'class_id = ?', whereArgs: [classId]);
    return maps.isEmpty ? null : FeeStructure.fromMap(maps.first);
  }

  Future<int> saveFeeStructure(FeeStructure fs) async {
    final db = await database;
    final existing = await getFeeStructureByClass(fs.classId);
    if (existing == null) return await db.insert('fee_structures', fs.toMap());
    return await db.update('fee_structures', fs.toMap(), where: 'class_id = ?', whereArgs: [fs.classId]);
  }

  // ============================================================
  // FEE RECORDS — FIXED: proper JOIN and null-safe args
  // ============================================================
  Future<List<FeeRecord>> getFeeRecords({
    int? classId, int? sectionId, int? month, int? year, String? status, String? searchQuery,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (classId != null) { conditions.add('fr.class_id = ?'); args.add(classId); }
    if (sectionId != null) { conditions.add('fr.section_id = ?'); args.add(sectionId); }
    if (month != null) { conditions.add('fr.month = ?'); args.add(month); }
    if (year != null) { conditions.add('fr.year = ?'); args.add(year); }
    if (status != null && status != 'all') { conditions.add('fr.status = ?'); args.add(status); }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(s.full_name LIKE ? OR s.registration_no LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    dev.log('[DB] getFeeRecords $where args=$args');

    final maps = await db.rawQuery('''
      SELECT
        fr.id, fr.student_id, fr.class_id, fr.section_id, fr.month, fr.year,
        fr.total_amount, fr.discount_amount, fr.fine_amount, fr.paid_amount,
        fr.due_date, fr.payment_date, fr.status, fr.remarks,
        s.full_name, s.father_name, s.guardian_phone, s.registration_no,
        c.class_name, sec.section_name
      FROM fee_records fr
      INNER JOIN students s ON fr.student_id = s.id
      LEFT JOIN classes c ON fr.class_id = c.id
      LEFT JOIN sections sec ON fr.section_id = sec.id
      $where
      ORDER BY c.sort_order, sec.section_name, s.full_name
    ''', args);

    dev.log('[DB] getFeeRecords → ${maps.length} records');
    return maps.map((m) => FeeRecord.fromMap(m)).toList();
  }

  Future<FeeRecord?> getFeeRecord(int studentId, int month, int year) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT fr.*, s.full_name, s.father_name, s.guardian_phone, s.registration_no,
             c.class_name, sec.section_name
      FROM fee_records fr
      JOIN students s ON fr.student_id = s.id
      LEFT JOIN classes c ON fr.class_id = c.id
      LEFT JOIN sections sec ON fr.section_id = sec.id
      WHERE fr.student_id = ? AND fr.month = ? AND fr.year = ?
    ''', [studentId, month, year]);
    return maps.isEmpty ? null : FeeRecord.fromMap(maps.first);
  }

  Future<FeeRecord?> getFeeRecordById(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT fr.*, s.full_name, s.father_name, s.guardian_phone, s.registration_no,
             c.class_name, sec.section_name
      FROM fee_records fr
      JOIN students s ON fr.student_id = s.id
      LEFT JOIN classes c ON fr.class_id = c.id
      LEFT JOIN sections sec ON fr.section_id = sec.id
      WHERE fr.id = ?
    ''', [id]);
    return maps.isEmpty ? null : FeeRecord.fromMap(maps.first);
  }

  Future<int> insertFeeRecord(FeeRecord record) async =>
      await (await database).insert('fee_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<int> updateFeeRecord(FeeRecord record) async =>
      await (await database).update('fee_records', record.toMap(), where: 'id = ?', whereArgs: [record.id]);

  Future<Map<String, dynamic>> getFeeMonthSummary(int month, int year) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as total,
        SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) as paid,
        SUM(CASE WHEN status = 'unpaid' THEN 1 ELSE 0 END) as unpaid,
        SUM(CASE WHEN status = 'partial' THEN 1 ELSE 0 END) as partial,
        SUM(CASE WHEN status = 'overdue' THEN 1 ELSE 0 END) as overdue,
        SUM(paid_amount) as total_paid,
        SUM(total_amount + fine_amount - discount_amount - paid_amount) as total_due
      FROM fee_records WHERE month = ? AND year = ?
    ''', [month, year]);
    return result.first;
  }

  // ============================================================
  // FEE PAYMENTS
  // ============================================================
  Future<int> insertFeePayment(FeePayment payment) async => await (await database).insert('fee_payments', payment.toMap());
  Future<List<FeePayment>> getPaymentsByFeeRecord(int feeRecordId) async {
    final db = await database;
    final maps = await db.query('fee_payments', where: 'fee_record_id = ?', whereArgs: [feeRecordId], orderBy: 'payment_date DESC');
    return maps.map((m) => FeePayment.fromMap(m)).toList();
  }

  Future<int> getNextReceiptNumber() async {
    final db = await database;
    await db.rawUpdate("UPDATE app_counters SET counter_value = counter_value + 1 WHERE counter_key = 'receipt_no'");
    final result = await db.query('app_counters', where: 'counter_key = ?', whereArgs: ['receipt_no']);
    return result.first['counter_value'] as int;
  }

  // ============================================================
  // STUDENT PROMOTIONS
  // ============================================================
  Future<int> insertPromotion(StudentPromotion p) async => await (await database).insert('student_promotions', p.toMap());
  Future<List<StudentPromotion>> getPromotionsByYear(String year) async {
    final db = await database;
    final maps = await db.query('student_promotions', where: 'promotion_year = ?', whereArgs: [year]);
    return maps.map((m) => StudentPromotion.fromMap(m)).toList();
  }

  // ============================================================
  // EXAMS, SUBJECTS, MARKS
  // ============================================================
  Future<List<Exam>> getExams({int? classId}) async {
    final db = await database;
    final maps = classId != null
        ? await db.query('exams', where: 'class_id = ?', whereArgs: [classId], orderBy: 'exam_date DESC')
        : await db.query('exams', orderBy: 'exam_date DESC');
    return maps.map((m) => Exam.fromMap(m)).toList();
  }

  Future<int> insertExam(Exam exam) async => await (await database).insert('exams', exam.toMap());

  Future<List<Subject>> getSubjectsByClass(int classId) async {
    final db = await database;
    final maps = await db.query('subjects', where: 'class_id = ?', whereArgs: [classId], orderBy: 'subject_name');
    return maps.map((m) => Subject.fromMap(m)).toList();
  }

  Future<Subject?> getSubjectById(int id) async {
    final db = await database;
    final maps = await db.query('subjects', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Subject.fromMap(maps.first);
  }

  Future<int> insertSubject(Subject subject) async => await (await database).insert('subjects', subject.toMap());

  Future<List<Mark>> getMarksByExam(int examId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT m.*, s.full_name, sub.subject_name FROM marks m
      JOIN students s ON m.student_id = s.id
      JOIN subjects sub ON m.subject_id = sub.id
      WHERE m.exam_id = ? ORDER BY s.full_name, sub.subject_name
    ''', [examId]);
    return maps.map((m) => Mark.fromMap(m)).toList();
  }

  Future<void> saveMarksBatch(List<Mark> marks) async {
    final db = await database;
    final batch = db.batch();
    for (final m in marks) {
      batch.insert('marks', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ============================================================
  // SMS TEMPLATES & LOGS
  // ============================================================
  Future<List<SmsTemplate>> getAllSmsTemplates() async {
    final db = await database;
    final maps = await db.query('sms_templates');
    return maps.map((m) => SmsTemplate.fromMap(m)).toList();
  }

  Future<SmsTemplate?> getSmsTemplateByKey(String key) async {
    final db = await database;
    final maps = await db.query('sms_templates', where: 'template_key = ?', whereArgs: [key]);
    return maps.isEmpty ? null : SmsTemplate.fromMap(maps.first);
  }

  Future<int> updateSmsTemplate(SmsTemplate template) async =>
      await (await database).update('sms_templates', template.toMap(), where: 'id = ?', whereArgs: [template.id]);

  Future<int> insertSmsLog(SmsLog log) async => await (await database).insert('sms_logs', log.toMap());

  Future<int> getSmsCountToday(String date) async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as cnt FROM sms_logs WHERE sent_at LIKE ? AND status = 'sent'", ['$date%']);
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ============================================================
  // EMPLOYEES
  // ============================================================
  Future<List<Employee>> getAllEmployees({bool? isActive}) async {
    final db = await database;
    final where = isActive != null ? 'WHERE is_active = ${isActive ? 1 : 0}' : '';
    final maps = await db.rawQuery('SELECT * FROM employees $where ORDER BY full_name');
    dev.log('[DB] getAllEmployees → ${maps.length}');
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  Future<Employee?> getEmployeeById(int id) async {
    final db = await database;
    final maps = await db.query('employees', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Employee.fromMap(maps.first);
  }

  Future<Employee?> getEmployeeByEmpId(String empId) async {
    final db = await database;
    final maps = await db.query('employees', where: 'employee_id = ?', whereArgs: [empId]);
    return maps.isEmpty ? null : Employee.fromMap(maps.first);
  }

  Future<List<Employee>> searchEmployees(String query) async {
    final db = await database;
    final maps = await db.rawQuery(
        'SELECT * FROM employees WHERE full_name LIKE ? OR employee_id LIKE ? ORDER BY full_name',
        ['%$query%', '%$query%']);
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  Future<int> insertEmployee(Employee emp) async => await (await database).insert('employees', emp.toMap());
  Future<int> updateEmployee(Employee emp) async =>
      await (await database).update('employees', emp.toMap(), where: 'id = ?', whereArgs: [emp.id]);
  Future<int> deleteEmployee(int id) async => await (await database).delete('employees', where: 'id = ?', whereArgs: [id]);
  Future<int> getTotalEmployeeCount({bool? isActive}) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM employees ${isActive != null ? 'WHERE is_active=${isActive ? 1 : 0}' : ''}');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ============================================================
  // EMPLOYEE ATTENDANCE
  // ============================================================
  Future<void> saveEmployeeAttendanceBatch(List<EmployeeAttendance> records) async {
    final db = await database;
    final batch = db.batch();
    for (final a in records) {
      batch.insert('employee_attendance', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<EmployeeAttendance>> getEmployeeAttendanceByDate(String date) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT ea.*, e.full_name, e.phone, e.designation
      FROM employee_attendance ea
      JOIN employees e ON ea.employee_id = e.id
      WHERE ea.attendance_date = ?
      ORDER BY e.full_name
    ''', [date]);
    return maps.map((m) => EmployeeAttendance.fromMap(m)).toList();
  }

  Future<List<EmployeeAttendance>> getEmployeeAttendanceHistory({
    required int employeeId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await database;
    final conditions = ['ea.employee_id = ?'];
    final args = <dynamic>[employeeId];
    if (fromDate != null) { conditions.add('ea.attendance_date >= ?'); args.add(fromDate); }
    if (toDate != null) { conditions.add('ea.attendance_date <= ?'); args.add(toDate); }
    final maps = await db.rawQuery('''
      SELECT ea.*, e.full_name, e.phone, e.designation
      FROM employee_attendance ea
      JOIN employees e ON ea.employee_id = e.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY ea.attendance_date DESC
    ''', args);
    return maps.map((m) => EmployeeAttendance.fromMap(m)).toList();
  }

  Future<Map<String, int>> getEmployeeAttendanceSummary(int employeeId, {String? fromDate, String? toDate}) async {
    final db = await database;
    final conditions = ['employee_id = ?'];
    final args = <dynamic>[employeeId];
    if (fromDate != null) { conditions.add('attendance_date >= ?'); args.add(fromDate); }
    if (toDate != null) { conditions.add('attendance_date <= ?'); args.add(toDate); }
    final results = await db.rawQuery(
        'SELECT status, COUNT(*) as cnt FROM employee_attendance WHERE ${conditions.join(' AND ')} GROUP BY status', args);
    final map = <String, int>{};
    for (final r in results) {
      map[r['status'] as String] = r['cnt'] as int;
    }
    return map;
  }

  Future<int> getPresentEmployeeCountToday(String date) async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM employee_attendance WHERE attendance_date = ? AND status = 'Present'", [date]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ============================================================
  // SALARY RECORDS
  // ============================================================
  Future<List<SalaryRecord>> getSalaryRecords({int? month, int? year, String? status}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (month != null) { conditions.add('sr.month = ?'); args.add(month); }
    if (year != null) { conditions.add('sr.year = ?'); args.add(year); }
    if (status != null && status != 'All') { conditions.add('sr.status = ?'); args.add(status); }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final maps = await db.rawQuery('''
      SELECT sr.*, e.full_name, e.phone, e.designation
      FROM salary_records sr
      JOIN employees e ON sr.employee_id = e.id
      $where ORDER BY e.full_name
    ''', args);
    return maps.map((m) => SalaryRecord.fromMap(m)).toList();
  }

  Future<SalaryRecord?> getSalaryRecord(int employeeId, int month, int year) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT sr.*, e.full_name, e.phone, e.designation FROM salary_records sr
      JOIN employees e ON sr.employee_id = e.id
      WHERE sr.employee_id = ? AND sr.month = ? AND sr.year = ?
    ''', [employeeId, month, year]);
    return maps.isEmpty ? null : SalaryRecord.fromMap(maps.first);
  }

  Future<SalaryRecord?> getSalaryRecordById(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT sr.*, e.full_name, e.phone, e.designation FROM salary_records sr
      JOIN employees e ON sr.employee_id = e.id WHERE sr.id = ?
    ''', [id]);
    return maps.isEmpty ? null : SalaryRecord.fromMap(maps.first);
  }

  Future<int> insertSalaryRecord(SalaryRecord r) async =>
      await (await database).insert('salary_records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<int> updateSalaryRecord(SalaryRecord r) async =>
      await (await database).update('salary_records', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<int> getPaidSalaryCountThisMonth(int month, int year) async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM salary_records WHERE month = ? AND year = ? AND status = 'Paid'", [month, year]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ============================================================
  // SALARY PAYMENTS
  // ============================================================
  Future<int> insertSalaryPayment(SalaryPayment p) async => await (await database).insert('salary_payments', p.toMap());
  Future<List<SalaryPayment>> getSalaryPaymentsByRecord(int salaryRecordId) async {
    final db = await database;
    final maps = await db.query('salary_payments', where: 'salary_record_id = ?', whereArgs: [salaryRecordId], orderBy: 'payment_date DESC');
    return maps.map((m) => SalaryPayment.fromMap(m)).toList();
  }

  // ============================================================
  // STUDENT TESTS
  // ============================================================
  Future<List<StudentTest>> getStudentTests({int? classId, int? sectionId, int? subjectId, String? date}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (classId != null) { conditions.add('st.class_id = ?'); args.add(classId); }
    if (sectionId != null) { conditions.add('st.section_id = ?'); args.add(sectionId); }
    if (subjectId != null) { conditions.add('st.subject_id = ?'); args.add(subjectId); }
    if (date != null) { conditions.add('st.test_date = ?'); args.add(date); }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final maps = await db.rawQuery('''
      SELECT st.*, c.class_name, sec.section_name, sub.subject_name
      FROM student_tests st
      JOIN classes c ON st.class_id = c.id
      JOIN sections sec ON st.section_id = sec.id
      JOIN subjects sub ON st.subject_id = sub.id
      $where ORDER BY st.test_date DESC
    ''', args);
    return maps.map((m) => StudentTest.fromMap(m)).toList();
  }

  Future<StudentTest?> getStudentTestById(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT st.*, c.class_name, sec.section_name, sub.subject_name
      FROM student_tests st
      JOIN classes c ON st.class_id = c.id
      JOIN sections sec ON st.section_id = sec.id
      JOIN subjects sub ON st.subject_id = sub.id
      WHERE st.id = ?
    ''', [id]);
    return maps.isEmpty ? null : StudentTest.fromMap(maps.first);
  }

  Future<int> insertStudentTest(StudentTest test) async => await (await database).insert('student_tests', test.toMap());

  Future<void> saveTestMarksBatch(List<StudentTestMark> marks) async {
    final db = await database;
    final batch = db.batch();
    for (final m in marks) {
      batch.insert('student_test_marks', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<StudentTestMark>> getTestMarksByTestId(int testId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT tm.*, s.full_name, s.guardian_phone, s.roll_no
      FROM student_test_marks tm
      JOIN students s ON tm.student_id = s.id
      WHERE tm.test_id = ?
      ORDER BY CAST(s.roll_no AS INTEGER)
    ''', [testId]);
    return maps.map((m) => StudentTestMark.fromMap(m)).toList();
  }

  Future<List<StudentTestMark>> getTestMarksByStudent(int studentId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT tm.*, s.full_name, s.guardian_phone, s.roll_no,
             st.test_date, st.title, sub.subject_name
      FROM student_test_marks tm
      JOIN students s ON tm.student_id = s.id
      JOIN student_tests st ON tm.test_id = st.id
      JOIN subjects sub ON st.subject_id = sub.id
      WHERE tm.student_id = ?
      ORDER BY st.test_date DESC
    ''', [studentId]);
    // re-use StudentTestMark but annotate with extra fields via toMap injection
    return maps.map((m) {
      final mark = StudentTestMark.fromMap(m);
      return mark;
    }).toList();
  }

  // ============================================================
  // BACKUP & RESTORE — extended to include new tables
  // ============================================================
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    return {
      'school_settings': await db.query('school_settings'),
      'classes': await db.query('classes'),
      'sections': await db.query('sections'),
      'students': await db.query('students'),
      'student_promotions': await db.query('student_promotions'),
      'attendance': await db.query('attendance'),
      'fee_structures': await db.query('fee_structures'),
      'fee_records': await db.query('fee_records'),
      'fee_payments': await db.query('fee_payments'),
      'exams': await db.query('exams'),
      'subjects': await db.query('subjects'),
      'marks': await db.query('marks'),
      'sms_templates': await db.query('sms_templates'),
      'sms_logs': await db.query('sms_logs'),
      'app_counters': await db.query('app_counters'),
      // New tables
      'employees': await db.query('employees'),
      'employee_attendance': await db.query('employee_attendance'),
      'salary_records': await db.query('salary_records'),
      'salary_payments': await db.query('salary_payments'),
      'student_tests': await db.query('student_tests'),
      'student_test_marks': await db.query('student_test_marks'),
    };
  }

  Future<void> restoreAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final clearOrder = [
        'student_test_marks', 'student_tests', 'salary_payments', 'salary_records',
        'employee_attendance', 'employees', 'marks', 'sms_logs', 'fee_payments',
        'fee_records', 'attendance', 'student_promotions', 'students',
        'fee_structures', 'subjects', 'exams', 'sections', 'classes',
        'school_settings', 'sms_templates', 'app_counters',
      ];
      for (final table in clearOrder) {
        try { await txn.delete(table); } catch (_) {}
      }
      final restoreOrder = [
        'school_settings', 'classes', 'sections', 'students', 'student_promotions',
        'attendance', 'fee_structures', 'fee_records', 'fee_payments', 'exams',
        'subjects', 'marks', 'sms_templates', 'sms_logs', 'app_counters',
        'employees', 'employee_attendance', 'salary_records', 'salary_payments',
        'student_tests', 'student_test_marks',
      ];
      for (final table in restoreOrder) {
        final rows = data[table] as List<dynamic>? ?? [];
        for (final row in rows) {
          try {
            await txn.insert(table, Map<String, dynamic>.from(row), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
        }
      }
    });
  }

  Future<void> closeDb() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
