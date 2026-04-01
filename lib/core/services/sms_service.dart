import 'package:telephony/telephony.dart';
import '../db/extended_database_helper.dart';
import '../../models/models.dart';

class SmsService {
  static final SmsService instance = SmsService._();
  SmsService._();

  final Telephony _telephony = Telephony.instance;
  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  Future<bool> requestPermission() async {
    final granted = await _telephony.requestSmsPermissions;
    return granted ?? false;
  }

  String resolvePlaceholders(String template, Map<String, String> values) {
    String resolved = template;
    values.forEach((key, value) { resolved = resolved.replaceAll('{$key}', value); });
    return resolved;
  }

  Future<bool> sendSms({required String phone, required String message, int? studentId, String? purpose}) async {
    try {
      final cleanPhone = _normalizePhone(phone);
      if (cleanPhone == null) return false;
      await _telephony.sendSms(to: cleanPhone, message: message, statusListener: (SendStatus status) {});
      await _db.insertSmsLog(SmsLog(phoneNumber: cleanPhone, message: message, sentAt: DateTime.now().toIso8601String(), status: 'sent', studentId: studentId, purpose: purpose));
      return true;
    } catch (e) {
      await _db.insertSmsLog(SmsLog(phoneNumber: phone, message: message, sentAt: DateTime.now().toIso8601String(), status: 'failed', studentId: studentId, purpose: purpose));
      return false;
    }
  }

  Future<Map<String, int>> sendBulkSms({required List<Map<String, dynamic>> recipients}) async {
    int sent = 0, failed = 0;
    for (final r in recipients) {
      final ok = await sendSms(phone: r['phone'] as String, message: r['message'] as String, studentId: r['studentId'] as int?, purpose: r['purpose'] as String?);
      if (ok) sent++; else failed++;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return {'sent': sent, 'failed': failed};
  }

  Future<Map<String, int>> sendAbsentSmsBatch({required List<Attendance> absentStudents, required String date}) async {
    final template = await _db.getSmsTemplateByKey('attendance_absent');
    if (template == null) return {'sent': 0, 'failed': 0};
    final recipients = <Map<String, dynamic>>[];
    for (final a in absentStudents) {
      if (a.guardianPhone == null || a.guardianPhone!.isEmpty) continue;
      final message = resolvePlaceholders(template.templateBody, {'student_name': a.studentName ?? '', 'class_name': a.className ?? '', 'section_name': a.sectionName ?? '', 'date': date});
      recipients.add({'phone': a.guardianPhone!, 'message': message, 'studentId': a.studentId, 'purpose': 'attendance_absent'});
    }
    return sendBulkSms(recipients: recipients);
  }

  Future<bool> sendFeeReminderSms(FeeRecord feeRecord) async {
    if (feeRecord.guardianPhone == null || feeRecord.guardianPhone!.isEmpty) return false;
    final template = await _db.getSmsTemplateByKey('fee_unpaid');
    if (template == null) return false;
    final message = resolvePlaceholders(template.templateBody, {
      'student_name': feeRecord.studentName ?? '', 'class_name': feeRecord.className ?? '',
      'section_name': feeRecord.sectionName ?? '', 'due_amount': feeRecord.dueAmount.toStringAsFixed(0),
      'month_name': _monthName(feeRecord.month), 'year': feeRecord.year.toString(), 'due_date': feeRecord.dueDate ?? '',
    });
    return sendSms(phone: feeRecord.guardianPhone!, message: message, studentId: feeRecord.studentId, purpose: 'fee_reminder');
  }

  Future<bool> sendFeeConfirmationSms({required FeeRecord feeRecord, required FeePayment payment}) async {
    if (feeRecord.guardianPhone == null || feeRecord.guardianPhone!.isEmpty) return false;
    final templateKey = feeRecord.dueAmount <= 0 ? 'fee_paid' : 'fee_partial';
    final template = await _db.getSmsTemplateByKey(templateKey);
    if (template == null) return false;
    final message = resolvePlaceholders(template.templateBody, {
      'student_name': feeRecord.studentName ?? '', 'class_name': feeRecord.className ?? '',
      'section_name': feeRecord.sectionName ?? '', 'paid_amount': payment.paidAmount.toStringAsFixed(0),
      'due_amount': feeRecord.dueAmount.toStringAsFixed(0), 'month_name': _monthName(feeRecord.month),
      'year': feeRecord.year.toString(), 'payment_date': payment.paymentDate,
    });
    return sendSms(phone: feeRecord.guardianPhone!, message: message, studentId: feeRecord.studentId, purpose: templateKey);
  }

  String? _normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.startsWith('03') && cleaned.length == 11) return '+92${cleaned.substring(1)}';
    if (cleaned.startsWith('+92') && cleaned.length == 13) return cleaned;
    if (cleaned.startsWith('92') && cleaned.length == 12) return '+$cleaned';
    if (cleaned.length >= 10) return cleaned;
    return null;
  }

  static bool isValidPakistanPhone(String phone) => RegExp(r'^03[0-9]{9}$').hasMatch(phone.trim());

  String _monthName(int month) {
    const months = ['','January','February','March','April','May','June','July','August','September','October','November','December'];
    return month >= 1 && month <= 12 ? months[month] : '';
  }
}
