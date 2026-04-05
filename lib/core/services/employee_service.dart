import 'dart:developer' as dev;
import '../db/extended_database_helper.dart';
import '../../models/extended_models.dart';
import 'sms_service.dart';

class EmployeeService {
  static final EmployeeService instance = EmployeeService._();
  EmployeeService._();

  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  // ---- Generate next employee ID ----
  Future<String> generateEmployeeId() async {
    final employees = await _db.getAllEmployees();
    final n = employees.length + 1;
    return 'EMP-${n.toString().padLeft(3, '0')}';
  }

  // ---- Generate monthly salary records for all active employees ----
  Future<Map<String, int>> generateMonthlySalaryRecords({
    required int month,
    required int year,
  }) async {
    int created = 0, skipped = 0;
    final employees = await _db.getAllEmployees(isActive: true);
    for (final emp in employees) {
      final existing = await _db.getSalaryRecord(emp.id!, month, year);
      if (existing != null) { skipped++; continue; }
      final record = SalaryRecord(
        employeeId: emp.id!,
        month: month,
        year: year,
        basicSalary: emp.salary,
        status: 'Unpaid',
      );
      await _db.insertSalaryRecord(record);
      created++;
    }
    dev.log('[SalaryService] Generated: $created, Skipped: $skipped');
    return {'created': created, 'skipped': skipped};
  }

  // ---- Record a salary payment ----
  Future<SalaryRecord?> recordSalaryPayment({
    required int salaryRecordId,
    required double amount,
    required String paymentDate,
    String? method,
    String? remarks,
    bool sendSms = true,
  }) async {
    final record = await _db.getSalaryRecordById(salaryRecordId);
    if (record == null) return null;

    // Insert payment
    await _db.insertSalaryPayment(SalaryPayment(
      salaryRecordId: salaryRecordId,
      amount: amount,
      paymentDate: paymentDate,
      method: method,
      remarks: remarks,
    ));

    // Recalculate
    final newPaid = record.paidAmount + amount;
    final total = record.totalPayable;
    String newStatus;
    if (newPaid <= 0) {
      newStatus = 'Unpaid';
    } else if (newPaid >= total) newStatus = 'Paid';
    else newStatus = 'Partial';

    final updated = SalaryRecord(
      id: record.id,
      employeeId: record.employeeId,
      month: record.month,
      year: record.year,
      basicSalary: record.basicSalary,
      bonus: record.bonus,
      deduction: record.deduction,
      paidAmount: newPaid,
      paymentDate: newStatus == 'Paid' ? paymentDate : record.paymentDate,
      status: newStatus,
      remarks: record.remarks,
      employeeName: record.employeeName,
      employeePhone: record.employeePhone,
    );
    await _db.updateSalaryRecord(updated);

    // SMS if fully paid
    if (sendSms && newStatus == 'Paid' && record.employeePhone != null) {
      final template = await _db.getSmsTemplateByKey('salary_paid');
      if (template != null) {
        const months = ['','January','February','March','April','May','June','July','August','September','October','November','December'];
        final msg = SmsService.instance.resolvePlaceholders(template.templateBody, {
          'employee_name': record.employeeName ?? '',
          'amount': amount.toStringAsFixed(0),
          'month': months[record.month],
        });
        await SmsService.instance.sendSms(phone: record.employeePhone!, message: msg, purpose: 'salary_paid');
      }
    }
    return updated;
  }

  // ---- Send absent SMS to employee ----
  Future<bool> sendEmployeeAbsentSms(EmployeeAttendance attendance) async {
    final emp = await _db.getEmployeeById(attendance.employeeId);
    if (emp == null || emp.phone.isEmpty) return false;
    final template = await _db.getSmsTemplateByKey('employee_absent');
    if (template == null) return false;
    final msg = SmsService.instance.resolvePlaceholders(template.templateBody, {
      'employee_name': emp.fullName,
      'date': attendance.attendanceDate,
    });
    return SmsService.instance.sendSms(phone: emp.phone, message: msg, purpose: 'employee_absent');
  }

  Future<SalaryRecord?> deleteSalaryPayment(int paymentId, int salaryRecordId) async {
    final payments = await _db.getSalaryPaymentsByRecord(salaryRecordId);
    final payment = payments.firstWhere((p) => p.id == paymentId);

    await _db.deleteSalaryPayment(paymentId);

    final record = await _db.getSalaryRecordById(salaryRecordId);
    if (record == null) return null;

    final newPaid = (record.paidAmount - payment.amount).clamp(0.0, double.infinity);
    final total = record.totalPayable;
    String newStatus;
    if (newPaid <= 0) {
      newStatus = 'Unpaid';
    } else if (newPaid >= total) {
      newStatus = 'Paid';
    } else {
      newStatus = 'Partial';
    }

    final updated = SalaryRecord(
      id: record.id,
      employeeId: record.employeeId,
      month: record.month,
      year: record.year,
      basicSalary: record.basicSalary,
      bonus: record.bonus,
      deduction: record.deduction,
      paidAmount: newPaid,
      paymentDate: newStatus == 'Paid' ? record.paymentDate : null,
      status: newStatus,
      remarks: record.remarks,
    );
    await _db.updateSalaryRecord(updated);
    return updated;
  }

  Future<SalaryRecord?> updateSalaryRecordTotals({
    required int recordId, required double bonus, required double deduction,
  }) async {
    final record = await _db.getSalaryRecordById(recordId);
    if (record == null) return null;

    final total = record.basicSalary + bonus - deduction;
    final newDue = total - record.paidAmount;

    String newStatus;
    if (record.paidAmount <= 0) {
      newStatus = 'Unpaid';
    } else if (newDue <= 0) {
      newStatus = 'Paid';
    } else {
      newStatus = 'Partial';
    }

    final updated = SalaryRecord(
      id: record.id,
      employeeId: record.employeeId,
      month: record.month,
      year: record.year,
      basicSalary: record.basicSalary,
      bonus: bonus,
      deduction: deduction,
      paidAmount: record.paidAmount,
      status: newStatus,
      remarks: record.remarks,
    );
    await _db.updateSalaryRecord(updated);
    return updated;
  }
}
