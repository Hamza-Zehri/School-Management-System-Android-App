import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/extended_database_helper.dart';
import '../../models/models.dart';

/// SMS Service — sends SMS via native Android SmsManager through MethodChannel.
/// Replaces the discontinued 'telephony' package.
class SmsService {
  static final SmsService instance = SmsService._();
  SmsService._();

  static const _channel = MethodChannel('com.hamza.schoolmanager.app/sms');
  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  /// Request SMS send permission
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Check if SMS permission is already granted
  Future<bool> hasPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Replace {placeholders} in template with actual values
  String resolvePlaceholders(String template, Map<String, String> values) {
    String resolved = template;
    values.forEach((key, value) {
      resolved = resolved.replaceAll('{$key}', value);
    });
    return resolved;
  }

  /// Send a single SMS — logs result to DB regardless of outcome
  Future<bool> sendSms({
    required String phone,
    required String message,
    int? studentId,
    String? purpose,
  }) async {
    // Ensure permission is granted before sending
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        dev.log('[SMS] Permission denied. Cannot send.');
        await _log(phone, message, 'failed (no permission)', studentId, purpose);
        return false;
      }
    }

    final cleanPhone = _normalizePhone(phone);
    if (cleanPhone == null) {
      dev.log('[SMS] Invalid phone: $phone');
      await _log(phone, message, 'failed', studentId, purpose);
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('sendSms', {
        'phone': cleanPhone,
        'message': message,
      });
      final ok = result == true;
      await _log(cleanPhone, message, ok ? 'sent' : 'failed', studentId, purpose);
      dev.log('[SMS] ${ok ? 'Sent' : 'Failed'} → $cleanPhone');
      return ok;
    } on PlatformException catch (e) {
      dev.log('[SMS] PlatformException: ${e.message}');
      await _log(cleanPhone, message, 'failed', studentId, purpose);
      return false;
    } catch (e) {
      dev.log('[SMS] Error: $e');
      await _log(cleanPhone, message, 'failed', studentId, purpose);
      return false;
    }
  }

  /// Send to multiple recipients. Returns {sent, failed} counts.
  Future<Map<String, int>> sendBulkSms({
    required List<Map<String, dynamic>> recipients,
  }) async {
    int sent = 0, failed = 0;
    for (final r in recipients) {
      final ok = await sendSms(
        phone: r['phone'] as String,
        message: r['message'] as String,
        studentId: r['studentId'] as int?,
        purpose: r['purpose'] as String?,
      );
      if (ok) {
        sent++;
      } else {
        failed++;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return {'sent': sent, 'failed': failed};
  }

  /// Send absence SMS to a list of absent students using the template
  Future<Map<String, int>> sendAbsentSmsBatch({
    required List<Attendance> absentStudents,
    required String date,
  }) async {
    final template = await _db.getSmsTemplateByKey('attendance_absent');
    if (template == null) return {'sent': 0, 'failed': 0};

    final recipients = <Map<String, dynamic>>[];
    for (final a in absentStudents) {
      if (a.guardianPhone == null || a.guardianPhone!.isEmpty) continue;
      final message = resolvePlaceholders(template.templateBody, {
        'student_name': a.studentName ?? '',
        'class_name': a.className ?? '',
        'section_name': a.sectionName ?? '',
        'date': date,
      });
      recipients.add({
        'phone': a.guardianPhone!,
        'message': message,
        'studentId': a.studentId,
        'purpose': 'attendance_absent',
      });
    }
    return sendBulkSms(recipients: recipients);
  }

  /// Send fee unpaid reminder SMS
  Future<bool> sendFeeReminderSms(FeeRecord feeRecord) async {
    if (feeRecord.guardianPhone == null || feeRecord.guardianPhone!.isEmpty) return false;
    final template = await _db.getSmsTemplateByKey('fee_unpaid');
    if (template == null) return false;

    final message = resolvePlaceholders(template.templateBody, {
      'student_name': feeRecord.studentName ?? '',
      'class_name': feeRecord.className ?? '',
      'section_name': feeRecord.sectionName ?? '',
      'due_amount': feeRecord.dueAmount.toStringAsFixed(0),
      'month_name': _monthName(feeRecord.month),
      'year': feeRecord.year.toString(),
      'due_date': feeRecord.dueDate ?? '',
    });
    return sendSms(
      phone: feeRecord.guardianPhone!,
      message: message,
      studentId: feeRecord.studentId,
      purpose: 'fee_reminder',
    );
  }

  /// Send fee paid / partial confirmation SMS
  Future<bool> sendFeeConfirmationSms({
    required FeeRecord feeRecord,
    required FeePayment payment,
  }) async {
    if (feeRecord.guardianPhone == null || feeRecord.guardianPhone!.isEmpty) return false;
    final templateKey = feeRecord.dueAmount <= 0 ? 'fee_paid' : 'fee_partial';
    final template = await _db.getSmsTemplateByKey(templateKey);
    if (template == null) return false;

    final message = resolvePlaceholders(template.templateBody, {
      'student_name': feeRecord.studentName ?? '',
      'class_name': feeRecord.className ?? '',
      'section_name': feeRecord.sectionName ?? '',
      'paid_amount': payment.paidAmount.toStringAsFixed(0),
      'due_amount': feeRecord.dueAmount.toStringAsFixed(0),
      'month_name': _monthName(feeRecord.month),
      'year': feeRecord.year.toString(),
      'payment_date': payment.paymentDate,
    });
    return sendSms(
      phone: feeRecord.guardianPhone!,
      message: message,
      studentId: feeRecord.studentId,
      purpose: templateKey,
    );
  }

  // ---- Helpers ----

  Future<void> _log(
      String phone, String message, String status, int? studentId, String? purpose) async {
    await _db.insertSmsLog(SmsLog(
      phoneNumber: phone,
      message: message,
      sentAt: DateTime.now().toIso8601String(),
      status: status,
      studentId: studentId,
      purpose: purpose,
    ));
  }

  /// Normalize Pakistan numbers: 03xxxxxxxxx → +923xxxxxxxxx
  String? _normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-().]'), '');
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('03') && cleaned.length == 11) {
      return '+92${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('+92') && cleaned.length == 13) return cleaned;
    if (cleaned.startsWith('92') && cleaned.length == 12) return '+$cleaned';
    if (cleaned.length >= 10) return cleaned; // fallback for other formats
    return null;
  }

  static bool isValidPakistanPhone(String phone) =>
      RegExp(r'^03[0-9]{9}$').hasMatch(phone.trim());

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }
}
