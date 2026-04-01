import 'dart:developer' as dev;
import '../db/extended_database_helper.dart';
import '../../models/extended_models.dart';
import 'sms_service.dart';

class StudentTestService {
  static final StudentTestService instance = StudentTestService._();
  StudentTestService._();

  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  /// Save a complete test with all marks in one transaction.
  /// Returns {testId, smsSent, smsFailed}
  Future<Map<String, int>> saveTestWithMarks({
    required StudentTest test,
    required List<StudentTestMark> marks,
    bool sendSms = false,
  }) async {
    // Insert the test header
    final testId = await _db.insertStudentTest(test);
    dev.log('[TestService] Inserted test id=$testId');

    // Update marks with correct testId
    final updatedMarks = marks.map((m) => StudentTestMark(
      testId: testId,
      studentId: m.studentId,
      totalMarks: m.totalMarks,
      obtainedMarks: m.obtainedMarks,
      remarks: m.remarks,
      studentName: m.studentName,
      guardianPhone: m.guardianPhone,
      rollNo: m.rollNo,
    )).toList();

    await _db.saveTestMarksBatch(updatedMarks);
    dev.log('[TestService] Saved ${updatedMarks.length} marks');

    int smsSent = 0, smsFailed = 0;

    if (sendSms) {
      final template = await _db.getSmsTemplateByKey('test_result');
      final savedTest = await _db.getStudentTestById(testId);
      if (template != null && savedTest != null) {
        for (final mark in updatedMarks) {
          if (mark.guardianPhone == null || mark.guardianPhone!.isEmpty) continue;
          final msg = SmsService.instance.resolvePlaceholders(template.templateBody, {
            'student_name': mark.studentName ?? '',
            'obtained_marks': mark.obtainedMarks.toStringAsFixed(0),
            'total_marks': mark.totalMarks.toStringAsFixed(0),
            'subject_name': savedTest.subjectName ?? '',
            'test_date': savedTest.testDate,
            'remarks': mark.remarks ?? 'N/A',
          });
          final ok = await SmsService.instance.sendSms(
            phone: mark.guardianPhone!,
            message: msg,
            studentId: mark.studentId,
            purpose: 'test_result',
          );
          if (ok) {
            smsSent++;
          } else {
            smsFailed++;
          }
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }
    }

    return {'testId': testId, 'smsSent': smsSent, 'smsFailed': smsFailed};
  }
}
