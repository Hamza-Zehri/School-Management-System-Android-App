import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/extended_database_helper.dart';
import '../../models/models.dart';
import '../../models/extended_models.dart';

final extDbProvider = Provider<ExtendedDatabaseHelper>((ref) => ExtendedDatabaseHelper.instance);

// ---- Employees ----
final employeesProvider = FutureProvider.family<List<Employee>, bool?>((ref, isActive) {
  return ref.read(extDbProvider).getAllEmployees(isActive: isActive);
});

// ---- Employee Attendance by date ----
final employeeAttendanceByDateProvider =
    FutureProvider.family<List<EmployeeAttendance>, String>((ref, date) {
  return ref.read(extDbProvider).getEmployeeAttendanceByDate(date);
});

// ---- Employee Attendance History ----
class EmpAttHistoryFilter {
  final int employeeId;
  final String? fromDate;
  final String? toDate;
  const EmpAttHistoryFilter({required this.employeeId, this.fromDate, this.toDate});
}

final empAttHistoryProvider =
    FutureProvider.family<List<EmployeeAttendance>, EmpAttHistoryFilter>((ref, f) {
  return ref.read(extDbProvider).getEmployeeAttendanceHistory(
    employeeId: f.employeeId,
    fromDate: f.fromDate,
    toDate: f.toDate,
  );
});

// ---- Salary Records ----
class SalaryFilter {
  final int? month;
  final int? year;
  final String? status;
  const SalaryFilter({this.month, this.year, this.status});
}

final salaryRecordsProvider =
    FutureProvider.family<List<SalaryRecord>, SalaryFilter>((ref, f) {
  return ref.read(extDbProvider).getSalaryRecords(
    month: f.month,
    year: f.year,
    status: f.status,
  );
});

// ---- Student Tests ----
class TestFilter {
  final int? classId;
  final int? sectionId;
  final int? subjectId;
  final String? date;
  const TestFilter({this.classId, this.sectionId, this.subjectId, this.date});
}

final studentTestsProvider =
    FutureProvider.family<List<StudentTest>, TestFilter>((ref, f) {
  return ref.read(extDbProvider).getStudentTests(
    classId: f.classId,
    sectionId: f.sectionId,
    subjectId: f.subjectId,
    date: f.date,
  );
});

// ---- Test Marks by test ID ----
final testMarksByTestProvider =
    FutureProvider.family<List<StudentTestMark>, int>((ref, testId) {
  return ref.read(extDbProvider).getTestMarksByTestId(testId);
});

// ---- Student Attendance History ----
class StudentAttHistoryFilter {
  final int studentId;
  final String? fromDate;
  final String? toDate;
  const StudentAttHistoryFilter({
    required this.studentId,
    this.fromDate,
    this.toDate,
  });
}

final studentAttHistoryProvider =
    FutureProvider.family<List<Attendance>, StudentAttHistoryFilter>((ref, f) {
  return ref.read(extDbProvider).getStudentAttendanceHistory(
    studentId: f.studentId,
    fromDate: f.fromDate,
    toDate: f.toDate,
  );
});
