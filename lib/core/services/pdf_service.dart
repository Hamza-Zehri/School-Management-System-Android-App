import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/models.dart';
import '../../models/extended_models.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  Future<String> _getReportsDir() async {
    const path = '/storage/emulated/0/Download/School\'s Files/Reports';
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<String> _getReceiptsDir() async {
    const path = '/storage/emulated/0/Download/School\'s Files/Receipts';
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<String> generateFeeReceipt({required FeeRecord feeRecord, required FeePayment payment, required SchoolSettings school}) async {
    final pdf = pw.Document();
    final monthName = _monthName(feeRecord.month);
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Column(children: [
          pw.Text(school.schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(school.schoolAddress, style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Ph: ${school.schoolPhone}', style: const pw.TextStyle(fontSize: 10)),
        ])),
        pw.Divider(thickness: 1), pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('FEE RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        _lv('Receipt No', payment.receiptNo), _lv('Payment Date', payment.paymentDate),
        pw.Divider(),
        _lv('Student Name', feeRecord.studentName ?? '-'), _lv('Father Name', feeRecord.fatherName ?? '-'),
        _lv('Class / Section', '${feeRecord.className ?? ''} - ${feeRecord.sectionName ?? ''}'),
        _lv('Registration No', feeRecord.registrationNo ?? '-'),
        pw.Divider(),
        _lv('Month', '$monthName ${feeRecord.year}'),
        _lv('Total Fee', 'Rs. ${feeRecord.totalAmount.toStringAsFixed(0)}'),
        if (feeRecord.discountAmount > 0) _lv('Discount', 'Rs. ${feeRecord.discountAmount.toStringAsFixed(0)}'),
        if (feeRecord.fineAmount > 0) _lv('Fine', 'Rs. ${feeRecord.fineAmount.toStringAsFixed(0)}'),
        _lv('Amount Paid', 'Rs. ${payment.paidAmount.toStringAsFixed(0)}'),
        _lv('Balance Due', 'Rs. ${feeRecord.dueAmount.toStringAsFixed(0)}'),
        _lv('Status', feeRecord.status.toUpperCase()),
        pw.SizedBox(height: 16),
        pw.Center(child: pw.Text('Thank you for your payment!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey600))),
        pw.Spacer(),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Received By: ________________', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Printed: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ]),
      ]),
    ));
    final dir = await _getReceiptsDir();
    final filePath = '$dir/${payment.receiptNo}.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<String> generateFeeStatusReport({required List<FeeRecord> records, required String status, required int month, required int year, required SchoolSettings school}) async {
    final pdf = pw.Document();
    final monthName = _monthName(month);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _header(school, '$status Fee Report - $monthName $year'),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellHeight: 24,
          headers: ['#', 'Student', 'Class', 'Total', 'Paid', 'Due', 'Status'],
          data: records.asMap().entries.map((e) {
            final r = e.value;
            return ['${e.key+1}', r.studentName ?? '', '${r.className ?? ''}-${r.sectionName ?? ''}', 'Rs.${r.finalTotal.toStringAsFixed(0)}', 'Rs.${r.paidAmount.toStringAsFixed(0)}', 'Rs.${r.dueAmount.toStringAsFixed(0)}', r.status];
          }).toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('Total Paid: Rs.${records.fold<double>(0, (s, r) => s + r.paidAmount).toStringAsFixed(0)}  |  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Total Due: Rs.${records.fold<double>(0, (s, r) => s + r.dueAmount).toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
        ]),
      ],
    ));
    final dir = await _getReportsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$dir/fee_${status}_${month}_${year}_$ts.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<String> generateAttendanceReport({required List<Attendance> records, required String date, required SchoolSettings school, String? className, String? sectionName}) async {
    final pdf = pw.Document();
    final title = 'Attendance Report - $date${className != null ? ' | $className${sectionName != null ? '-$sectionName' : ''}' : ''}';
    final present = records.where((r) => r.status == 'present').length;
    final absent = records.where((r) => r.status == 'absent').length;
    final late = records.where((r) => r.status == 'late').length;
    final leave = records.where((r) => r.status == 'leave').length;
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _header(school, title),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _sb('Total', '${records.length}', PdfColors.blueGrey), _sb('Present', '$present', PdfColors.green),
          _sb('Absent', '$absent', PdfColors.red), _sb('Late', '$late', PdfColors.orange), _sb('Leave', '$leave', PdfColors.purple),
        ]),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          cellHeight: 22,
          headers: ['#', 'Student Name', 'Class', 'Section', 'Status'],
          data: records.asMap().entries.map((e) {
            final r = e.value;
            return ['${e.key+1}', r.studentName ?? '', r.className ?? '', r.sectionName ?? '', r.status.toUpperCase()];
          }).toList(),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ));
    final dir = await _getReportsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$dir/attendance_${date.replaceAll('-', '')}_$ts.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<String> generateStudentListPdf({required List<Student> students, required SchoolSettings school, String title = 'Student List'}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _header(school, title),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellHeight: 22,
          headers: ['#', 'Reg No', 'Student Name', 'Father', 'Class', 'Sec', 'Phone'],
          data: students.asMap().entries.map((e) {
            final s = e.value;
            return ['${e.key+1}', s.registrationNo, s.fullName, s.fatherName, s.className ?? '', s.sectionName ?? '', s.guardianPhone];
          }).toList(),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Total Students: ${students.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ));
    final dir = await _getReportsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$dir/students_$ts.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<String> generateTestResultPdf({required StudentTest test, required List<StudentTestMark> marks, required SchoolSettings school}) async {
    final pdf = pw.Document();
    final title = '${test.title ?? 'Test Result'} — ${test.subjectName ?? ''} — ${test.testDate}';
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _header(school, title),
      build: (ctx) => [
        pw.SizedBox(height: 4),
        pw.Text('Class: ${test.className ?? ''} - ${test.sectionName ?? ''}', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellHeight: 22,
          headers: ['#', 'Roll', 'Student Name', 'Total', 'Obtained', '%', 'Grade', 'Remarks'],
          data: marks.asMap().entries.map((e) {
            final m = e.value;
            return ['${e.key+1}', m.rollNo ?? '', m.studentName ?? '', m.totalMarks.toStringAsFixed(0), m.obtainedMarks.toStringAsFixed(0), '${m.percentage.toStringAsFixed(1)}%', m.grade, m.remarks ?? ''];
          }).toList(),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Total Students: ${marks.length}  |  Class Average: ${(marks.isEmpty ? 0 : marks.fold<double>(0, (s, m) => s + m.percentage) / marks.length).toStringAsFixed(1)}%',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ],
    ));
    final dir = await _getReportsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$dir/test_result_$ts.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<String> generatePromotionSummaryPdf({required int promoted, required int repeated, required int inactive, required int transferred, required String promotionYear, required SchoolSettings school}) async {
    final pdf = pw.Document();
    final total = promoted + repeated + inactive + transferred;
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5, margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header(school, 'Promotion Summary $promotionYear'),
        pw.SizedBox(height: 16),
        _lv('Total Students Processed', '$total'), pw.Divider(),
        _lv('Promoted', '$promoted'), _lv('Repeated Class', '$repeated'),
        _lv('Marked Inactive', '$inactive'), _lv('Transferred', '$transferred'),
        pw.SizedBox(height: 16),
        pw.Text('Generated on: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      ]),
    ));
    final dir = await _getReportsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$dir/promotion_summary_${promotionYear}_$ts.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<void> previewPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  pw.Widget _header(SchoolSettings school, String reportTitle) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
    pw.Text(school.schoolName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    pw.Text(school.schoolAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    pw.SizedBox(height: 4),
    pw.Text(reportTitle, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
    pw.Divider(thickness: 1),
  ]);

  pw.Widget _lv(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(children: [
      pw.SizedBox(width: 120, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
      pw.Text(': ', style: const pw.TextStyle(fontSize: 10)),
      pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
    ]),
  );

  pw.Widget _sb(String label, String value, PdfColor color) => pw.Expanded(child: pw.Container(
    margin: const pw.EdgeInsets.only(right: 4),
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
    child: pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
      pw.Text(label, style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
    ]),
  ));

  String _monthName(int month) {
    const months = ['','January','February','March','April','May','June','July','August','September','October','November','December'];
    return month >= 1 && month <= 12 ? months[month] : '';
  }
}
