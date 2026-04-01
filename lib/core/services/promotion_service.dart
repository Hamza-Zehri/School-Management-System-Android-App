import '../db/extended_database_helper.dart';
import '../../models/models.dart';

class PromotionResult {
  final int promoted, repeated, inactive, transferred;
  PromotionResult({required this.promoted, required this.repeated, required this.inactive, required this.transferred});
}

class PromotionEntry {
  final Student student;
  final String action;
  final int? newClassId;
  final int? newSectionId;
  final String? remarks;
  PromotionEntry({required this.student, required this.action, this.newClassId, this.newSectionId, this.remarks});
}

class PromotionService {
  static final PromotionService instance = PromotionService._();
  PromotionService._();
  final ExtendedDatabaseHelper _db = ExtendedDatabaseHelper.instance;

  Future<PromotionResult> promoteStudents({required List<PromotionEntry> entries, required String promotionYear}) async {
    int promoted = 0, repeated = 0, inactive = 0, transferred = 0;
    final now = DateTime.now().toIso8601String();
    for (final entry in entries) {
      final student = entry.student;
      int newClassId = student.classId, newSectionId = student.sectionId;
      bool updateStudent = true;
      switch (entry.action) {
        case 'promote': newClassId = entry.newClassId ?? student.classId; newSectionId = entry.newSectionId ?? student.sectionId; promoted++; break;
        case 'repeat': newClassId = student.classId; newSectionId = student.sectionId; repeated++; break;
        case 'inactive': await _db.updateStudent(student.copyWith(isActive: false)); inactive++; updateStudent = false; break;
        case 'transfer': newClassId = entry.newClassId ?? student.classId; newSectionId = entry.newSectionId ?? student.sectionId; transferred++; break;
      }
      if (updateStudent) await _db.updateStudent(student.copyWith(classId: newClassId, sectionId: newSectionId));
      await _db.insertPromotion(StudentPromotion(
        studentId: student.id!, oldClassId: student.classId, oldSectionId: student.sectionId,
        newClassId: newClassId, newSectionId: newSectionId,
        promotionYear: promotionYear, promotedOn: now, remarks: entry.remarks, status: entry.action,
      ));
    }
    return PromotionResult(promoted: promoted, repeated: repeated, inactive: inactive, transferred: transferred);
  }

  Future<PromotionResult> promoteWholeClass({required int fromClassId, required int fromSectionId, required int toClassId, required int toSectionId, required String promotionYear}) async {
    final students = await _db.getStudentsByClassSection(fromClassId, fromSectionId, isActive: true);
    final entries = students.map((s) => PromotionEntry(student: s, action: 'promote', newClassId: toClassId, newSectionId: toSectionId)).toList();
    return promoteStudents(entries: entries, promotionYear: promotionYear);
  }
}
