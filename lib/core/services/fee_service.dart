import 'dart:developer' as dev;
import '../db/extended_database_helper.dart';
import '../../models/models.dart';
import 'sms_service.dart';

class FeeService {
  static final FeeService instance = FeeService._();
  FeeService._();

  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  Future<Map<String, int>> generateFeeRecords({
    required int month, required int year,
    int? classId, int? sectionId, String? dueDate,
  }) async {
    int created = 0, skipped = 0;
    List<Student> students;
    if (classId != null && sectionId != null) {
      students = await _db.getStudentsByClassSection(classId, sectionId, isActive: true);
    } else if (classId != null) {
      students = (await _db.getAllStudents(isActive: true)).where((s) => s.classId == classId).toList();
    } else {
      students = await _db.getAllStudents(isActive: true);
    }
    dev.log('[FeeService] Generating for ${students.length} students month=$month year=$year');
    for (final student in students) {
      final existing = await _db.getFeeRecord(student.id!, month, year);
      if (existing != null) { skipped++; continue; }
      final feeStructure = await _db.getFeeStructureByClass(student.classId);
      final totalAmount = feeStructure?.totalFee ?? 0;
      final record = FeeRecord(
        studentId: student.id!, classId: student.classId, sectionId: student.sectionId,
        month: month, year: year, totalAmount: totalAmount, dueDate: dueDate, status: 'unpaid',
      );
      await _db.insertFeeRecord(record);
      created++;
    }
    return {'created': created, 'skipped': skipped};
  }

  Future<FeeRecord?> recordPayment({
    required int feeRecordId, required double amount, required String paymentDate,
    String? paymentMethod, String? remarks, bool sendSms = true,
  }) async {
    final feeRecord = await _db.getFeeRecordById(feeRecordId);
    if (feeRecord == null) return null;

    final receiptNum = await _db.getNextReceiptNumber();
    final year = DateTime.now().year;
    final receiptNo = 'RCPT-$year-${receiptNum.toString().padLeft(4, '0')}';
    final payment = FeePayment(feeRecordId: feeRecordId, receiptNo: receiptNo, paidAmount: amount, paymentDate: paymentDate, paymentMethod: paymentMethod, remarks: remarks);
    await _db.insertFeePayment(payment);

    final newPaidAmount = feeRecord.paidAmount + amount;
    final finalTotal = feeRecord.totalAmount + feeRecord.fineAmount - feeRecord.discountAmount;
    final newDue = finalTotal - newPaidAmount;
    String newStatus;
    if (newPaidAmount <= 0) newStatus = 'unpaid';
    else if (newDue <= 0) newStatus = 'paid';
    else newStatus = 'partial';

    final updatedRecord = FeeRecord(
      id: feeRecord.id, studentId: feeRecord.studentId, classId: feeRecord.classId,
      sectionId: feeRecord.sectionId, month: feeRecord.month, year: feeRecord.year,
      totalAmount: feeRecord.totalAmount, discountAmount: feeRecord.discountAmount,
      fineAmount: feeRecord.fineAmount, paidAmount: newPaidAmount,
      dueDate: feeRecord.dueDate, paymentDate: newStatus == 'paid' ? paymentDate : feeRecord.paymentDate,
      status: newStatus, remarks: feeRecord.remarks,
      studentName: feeRecord.studentName, fatherName: feeRecord.fatherName,
      guardianPhone: feeRecord.guardianPhone, className: feeRecord.className,
      sectionName: feeRecord.sectionName, registrationNo: feeRecord.registrationNo,
    );
    await _db.updateFeeRecord(updatedRecord);

    if (sendSms) {
      await SmsService.instance.sendFeeConfirmationSms(feeRecord: updatedRecord, payment: payment);
    }
    return updatedRecord;
  }

  Future<void> refreshOverdueStatus() async {
    final today = DateTime.now();
    final allRecords = await _db.getFeeRecords();
    for (final record in allRecords) {
      if ((record.status == 'unpaid' || record.status == 'partial') && record.dueDate != null) {
        try {
          final due = DateTime.parse(record.dueDate!);
          if (today.isAfter(due)) {
            await _db.updateFeeRecord(FeeRecord(
              id: record.id, studentId: record.studentId, classId: record.classId,
              sectionId: record.sectionId, month: record.month, year: record.year,
              totalAmount: record.totalAmount, discountAmount: record.discountAmount,
              fineAmount: record.fineAmount, paidAmount: record.paidAmount,
              dueDate: record.dueDate, status: 'overdue',
            ));
          }
        } catch (_) {}
      }
    }
  }
}
