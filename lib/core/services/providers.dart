import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/extended_database_helper.dart';
import '../../models/models.dart';

// Use ExtendedDatabaseHelper as the single source of truth
final dbProvider = Provider<ExtendedDatabaseHelper>((ref) => ExtendedDatabaseHelper.instance);

// ---- Theme Mode Provider ----
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ---- School Settings ----
final schoolSettingsProvider = FutureProvider<SchoolSettings?>((ref) {
  return ref.read(dbProvider).getSchoolSettings();
});

// ---- Classes ----
final classesProvider = FutureProvider<List<SchoolClass>>((ref) {
  return ref.read(dbProvider).getAllClasses();
});

// ---- Sections by class ----
final sectionsByClassProvider = FutureProvider.family<List<Section>, int>((ref, classId) {
  return ref.read(dbProvider).getSectionsByClass(classId);
});

// ---- All Students ----
final allStudentsProvider = FutureProvider<List<Student>>((ref) {
  return ref.read(dbProvider).getAllStudents(isActive: true);
});

// ---- Students by class+section ----
final studentsByClassSectionProvider =
    FutureProvider.family<List<Student>, ({int classId, int sectionId})>((ref, args) {
  return ref.read(dbProvider).getStudentsByClassSection(args.classId, args.sectionId, isActive: true);
});

// ---- SMS Templates ----
final smsTemplatesProvider = FutureProvider<List<SmsTemplate>>((ref) {
  return ref.read(dbProvider).getAllSmsTemplates();
});

// ---- Fee Records ----
final feeRecordsProvider = FutureProvider.family<List<FeeRecord>, FeeFilter>((ref, filter) {
  return ref.read(dbProvider).getFeeRecords(
    classId: filter.classId, sectionId: filter.sectionId,
    month: filter.month, year: filter.year, status: filter.status,
  );
});

class FeeFilter {
  final int? classId, sectionId, month, year;
  final String? status;
  const FeeFilter({this.classId, this.sectionId, this.month, this.year, this.status});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeeFilter &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          sectionId == other.sectionId &&
          month == other.month &&
          year == other.year &&
          status == other.status;

  @override
  int get hashCode =>
      classId.hashCode ^
      sectionId.hashCode ^
      month.hashCode ^
      year.hashCode ^
      status.hashCode;
}

// ---- Exams ----
final examsProvider = FutureProvider.family<List<Exam>, int?>((ref, classId) {
  return ref.read(dbProvider).getExams(classId: classId);
});

// ---- Subjects ----
final subjectsProvider = FutureProvider.family<List<Subject>, int>((ref, classId) {
  return ref.read(dbProvider).getSubjectsByClass(classId);
});

// ---- Marks by exam ----
final marksByExamProvider = FutureProvider.family<List<Mark>, int>((ref, examId) {
  return ref.read(dbProvider).getMarksByExam(examId);
});
