// ============================================================
// MODELS - All data models for School Management System
// ============================================================

// ---- SchoolSettings ----
class SchoolSettings {
  final int? id;
  final String schoolName;
  final String schoolAddress;
  final String schoolPhone;
  final String? schoolEmail;
  final String? logoPath;
  final String? currentSession;

  SchoolSettings({
    this.id,
    required this.schoolName,
    required this.schoolAddress,
    required this.schoolPhone,
    this.schoolEmail,
    this.logoPath,
    this.currentSession,
  });

  factory SchoolSettings.fromMap(Map<String, dynamic> map) => SchoolSettings(
        id: map['id'],
        schoolName: map['school_name'],
        schoolAddress: map['school_address'],
        schoolPhone: map['school_phone'],
        schoolEmail: map['school_email'],
        logoPath: map['logo_path'],
        currentSession: map['current_session'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'school_name': schoolName,
        'school_address': schoolAddress,
        'school_phone': schoolPhone,
        'school_email': schoolEmail,
        'logo_path': logoPath,
        'current_session': currentSession,
      };
}

// ---- SchoolClass ----
class SchoolClass {
  final int? id;
  final String className;
  final String? description;
  final int sortOrder;

  SchoolClass({
    this.id,
    required this.className,
    this.description,
    this.sortOrder = 0,
  });

  factory SchoolClass.fromMap(Map<String, dynamic> map) => SchoolClass(
        id: map['id'],
        className: map['class_name'],
        description: map['description'],
        sortOrder: map['sort_order'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'class_name': className,
        'description': description,
        'sort_order': sortOrder,
      };

  @override
  String toString() => className;
}

// ---- Section ----
class Section {
  final int? id;
  final int classId;
  final String sectionName;

  Section({
    this.id,
    required this.classId,
    required this.sectionName,
  });

  factory Section.fromMap(Map<String, dynamic> map) => Section(
        id: map['id'],
        classId: map['class_id'],
        sectionName: map['section_name'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'section_name': sectionName,
      };

  @override
  String toString() => sectionName;
}

// ---- Student ----
class Student {
  final int? id;
  final String registrationNo;
  final String rollNo;
  final String fullName;
  final String fatherName;
  final String guardianName;
  final String guardianPhone;
  final String? guardianPhone2;
  final int classId;
  final int sectionId;
  final String gender;
  final String? dob;
  final String? admissionDate;
  final String? address;
  final bool isActive;
  final bool noFee;

  // Joined fields (not stored in DB)
  String? className;
  String? sectionName;

  Student({
    this.id,
    required this.registrationNo,
    required this.rollNo,
    required this.fullName,
    required this.fatherName,
    required this.guardianName,
    required this.guardianPhone,
    this.guardianPhone2,
    required this.classId,
    required this.sectionId,
    required this.gender,
    this.dob,
    this.admissionDate,
    this.address,
    this.isActive = true,
    this.noFee = false,
    this.className,
    this.sectionName,
  });

  factory Student.fromMap(Map<String, dynamic> map) => Student(
        id: map['id'],
        registrationNo: map['registration_no'],
        rollNo: map['roll_no'],
        fullName: map['full_name'],
        fatherName: map['father_name'],
        guardianName: map['guardian_name'],
        guardianPhone: map['guardian_phone'],
        guardianPhone2: map['guardian_phone_2'],
        classId: map['class_id'],
        sectionId: map['section_id'],
        gender: map['gender'] ?? 'Male',
        dob: map['dob'],
        admissionDate: map['admission_date'],
        address: map['address'],
        isActive: (map['is_active'] ?? 1) == 1,
        noFee: (map['no_fee'] ?? 0) == 1,
        className: map['class_name'],
        sectionName: map['section_name'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'registration_no': registrationNo,
        'roll_no': rollNo,
        'full_name': fullName,
        'father_name': fatherName,
        'guardian_name': guardianName,
        'guardian_phone': guardianPhone,
        'guardian_phone_2': guardianPhone2,
        'class_id': classId,
        'section_id': sectionId,
        'gender': gender,
        'dob': dob,
        'admission_date': admissionDate,
        'address': address,
        'is_active': isActive ? 1 : 0,
        'no_fee': noFee ? 1 : 0,
      };

  Student copyWith({
    int? id,
    String? registrationNo,
    String? rollNo,
    String? fullName,
    String? fatherName,
    String? guardianName,
    String? guardianPhone,
    String? guardianPhone2,
    int? classId,
    int? sectionId,
    String? gender,
    String? dob,
    String? admissionDate,
    String? address,
    bool? isActive,
    bool? noFee,
  }) =>
      Student(
        id: id ?? this.id,
        registrationNo: registrationNo ?? this.registrationNo,
        rollNo: rollNo ?? this.rollNo,
        fullName: fullName ?? this.fullName,
        fatherName: fatherName ?? this.fatherName,
        guardianName: guardianName ?? this.guardianName,
        guardianPhone: guardianPhone ?? this.guardianPhone,
        guardianPhone2: guardianPhone2 ?? this.guardianPhone2,
        classId: classId ?? this.classId,
        sectionId: sectionId ?? this.sectionId,
        gender: gender ?? this.gender,
        dob: dob ?? this.dob,
        admissionDate: admissionDate ?? this.admissionDate,
        address: address ?? this.address,
        isActive: isActive ?? this.isActive,
        noFee: noFee ?? this.noFee,
      );
}

// ---- StudentPromotion ----
class StudentPromotion {
  final int? id;
  final int studentId;
  final int oldClassId;
  final int oldSectionId;
  final int newClassId;
  final int newSectionId;
  final String promotionYear;
  final String promotedOn;
  final String? remarks;
  final String status; // promoted | repeated | inactive | transferred

  StudentPromotion({
    this.id,
    required this.studentId,
    required this.oldClassId,
    required this.oldSectionId,
    required this.newClassId,
    required this.newSectionId,
    required this.promotionYear,
    required this.promotedOn,
    this.remarks,
    this.status = 'promoted',
  });

  factory StudentPromotion.fromMap(Map<String, dynamic> map) => StudentPromotion(
        id: map['id'],
        studentId: map['student_id'],
        oldClassId: map['old_class_id'],
        oldSectionId: map['old_section_id'],
        newClassId: map['new_class_id'],
        newSectionId: map['new_section_id'],
        promotionYear: map['promotion_year'],
        promotedOn: map['promoted_on'],
        remarks: map['remarks'],
        status: map['status'] ?? 'promoted',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'old_class_id': oldClassId,
        'old_section_id': oldSectionId,
        'new_class_id': newClassId,
        'new_section_id': newSectionId,
        'promotion_year': promotionYear,
        'promoted_on': promotedOn,
        'remarks': remarks,
        'status': status,
      };
}

// ---- Attendance ----
class Attendance {
  final int? id;
  final int studentId;
  final String attendanceDate;
  final String status; // present | absent | late | leave
  final String? remarks;

  // Joined
  String? studentName;
  String? guardianPhone;
  String? className;
  String? sectionName;

  Attendance({
    this.id,
    required this.studentId,
    required this.attendanceDate,
    required this.status,
    this.remarks,
    this.studentName,
    this.guardianPhone,
    this.className,
    this.sectionName,
  });

  factory Attendance.fromMap(Map<String, dynamic> map) => Attendance(
        id: map['id'],
        studentId: map['student_id'],
        attendanceDate: map['attendance_date'],
        status: map['status'],
        remarks: map['remarks'],
        studentName: map['full_name'],
        guardianPhone: map['guardian_phone'],
        className: map['class_name'],
        sectionName: map['section_name'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'attendance_date': attendanceDate,
        'status': status,
        'remarks': remarks,
      };
}

// ---- FeeStructure ----
class FeeStructure {
  final int? id;
  final int classId;
  final double monthlyFee;
  final double examFee;
  final double transportFee;
  final double otherFee;

  FeeStructure({
    this.id,
    required this.classId,
    this.monthlyFee = 0,
    this.examFee = 0,
    this.transportFee = 0,
    this.otherFee = 0,
  });

  double get totalFee => monthlyFee + examFee + transportFee + otherFee;

  factory FeeStructure.fromMap(Map<String, dynamic> map) => FeeStructure(
        id: map['id'],
        classId: map['class_id'],
        monthlyFee: (map['monthly_fee'] ?? 0).toDouble(),
        examFee: (map['exam_fee'] ?? 0).toDouble(),
        transportFee: (map['transport_fee'] ?? 0).toDouble(),
        otherFee: (map['other_fee'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'monthly_fee': monthlyFee,
        'exam_fee': examFee,
        'transport_fee': transportFee,
        'other_fee': otherFee,
      };
}

// ---- FeeRecord ----
class FeeRecord {
  final int? id;
  final int studentId;
  final int classId;
  final int sectionId;
  final int month;
  final int year;
  final double totalAmount;
  final double discountAmount;
  final double fineAmount;
  final double paidAmount;
  final String? dueDate;
  final String? paymentDate;
  final String status; // unpaid | partial | paid | overdue
  final String? remarks;

  // Joined
  String? studentName;
  String? fatherName;
  String? guardianPhone;
  String? className;
  String? sectionName;
  String? registrationNo;

  double get finalTotal => totalAmount + fineAmount - discountAmount;
  double get dueAmount => finalTotal - paidAmount;

  FeeRecord({
    this.id,
    required this.studentId,
    required this.classId,
    required this.sectionId,
    required this.month,
    required this.year,
    required this.totalAmount,
    this.discountAmount = 0,
    this.fineAmount = 0,
    this.paidAmount = 0,
    this.dueDate,
    this.paymentDate,
    this.status = 'unpaid',
    this.remarks,
    this.studentName,
    this.fatherName,
    this.guardianPhone,
    this.className,
    this.sectionName,
    this.registrationNo,
  });

  factory FeeRecord.fromMap(Map<String, dynamic> map) => FeeRecord(
        id: map['id'],
        studentId: map['student_id'],
        classId: map['class_id'],
        sectionId: map['section_id'],
        month: map['month'],
        year: map['year'],
        totalAmount: (map['total_amount'] ?? 0).toDouble(),
        discountAmount: (map['discount_amount'] ?? 0).toDouble(),
        fineAmount: (map['fine_amount'] ?? 0).toDouble(),
        paidAmount: (map['paid_amount'] ?? 0).toDouble(),
        dueDate: map['due_date'],
        paymentDate: map['payment_date'],
        status: map['status'] ?? 'unpaid',
        remarks: map['remarks'],
        studentName: map['full_name'],
        fatherName: map['father_name'],
        guardianPhone: map['guardian_phone'],
        className: map['class_name'],
        sectionName: map['section_name'],
        registrationNo: map['registration_no'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'class_id': classId,
        'section_id': sectionId,
        'month': month,
        'year': year,
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'fine_amount': fineAmount,
        'paid_amount': paidAmount,
        'due_date': dueDate,
        'payment_date': paymentDate,
        'status': status,
        'remarks': remarks,
      };
}

// ---- FeePayment ----
class FeePayment {
  final int? id;
  final int feeRecordId;
  final String receiptNo;
  final double paidAmount;
  final String paymentDate;
  final String? paymentMethod;
  final String? remarks;

  FeePayment({
    this.id,
    required this.feeRecordId,
    required this.receiptNo,
    required this.paidAmount,
    required this.paymentDate,
    this.paymentMethod,
    this.remarks,
  });

  factory FeePayment.fromMap(Map<String, dynamic> map) => FeePayment(
        id: map['id'],
        feeRecordId: map['fee_record_id'],
        receiptNo: map['receipt_no'],
        paidAmount: (map['paid_amount'] ?? 0).toDouble(),
        paymentDate: map['payment_date'],
        paymentMethod: map['payment_method'],
        remarks: map['remarks'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'fee_record_id': feeRecordId,
        'receipt_no': receiptNo,
        'paid_amount': paidAmount,
        'payment_date': paymentDate,
        'payment_method': paymentMethod,
        'remarks': remarks,
      };
}

// ---- Exam ----
class Exam {
  final int? id;
  final String examName;
  final int classId;
  final int sectionId;
  final String? examDate;
  final String? description;

  Exam({
    this.id,
    required this.examName,
    required this.classId,
    required this.sectionId,
    this.examDate,
    this.description,
  });

  factory Exam.fromMap(Map<String, dynamic> map) => Exam(
        id: map['id'],
        examName: map['exam_name'],
        classId: map['class_id'],
        sectionId: map['section_id'],
        examDate: map['exam_date'],
        description: map['description'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'exam_name': examName,
        'class_id': classId,
        'section_id': sectionId,
        'exam_date': examDate,
        'description': description,
      };
}

// ---- Subject ----
class Subject {
  final int? id;
  final String subjectName;
  final int classId;

  Subject({this.id, required this.subjectName, required this.classId});

  factory Subject.fromMap(Map<String, dynamic> map) => Subject(
        id: map['id'],
        subjectName: map['subject_name'],
        classId: map['class_id'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'subject_name': subjectName,
        'class_id': classId,
      };
}

// ---- Mark ----
class Mark {
  final int? id;
  final int examId;
  final int studentId;
  final int subjectId;
  final double totalMarks;
  final double obtainedMarks;
  final String? remarks;

  // Joined
  String? studentName;
  String? subjectName;

  Mark({
    this.id,
    required this.examId,
    required this.studentId,
    required this.subjectId,
    required this.totalMarks,
    required this.obtainedMarks,
    this.remarks,
    this.studentName,
    this.subjectName,
  });

  double get percentage => totalMarks > 0 ? (obtainedMarks / totalMarks) * 100 : 0;

  String get grade {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  factory Mark.fromMap(Map<String, dynamic> map) => Mark(
        id: map['id'],
        examId: map['exam_id'],
        studentId: map['student_id'],
        subjectId: map['subject_id'],
        totalMarks: (map['total_marks'] ?? 0).toDouble(),
        obtainedMarks: (map['obtained_marks'] ?? 0).toDouble(),
        remarks: map['remarks'],
        studentName: map['full_name'],
        subjectName: map['subject_name'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'exam_id': examId,
        'student_id': studentId,
        'subject_id': subjectId,
        'total_marks': totalMarks,
        'obtained_marks': obtainedMarks,
        'remarks': remarks,
      };
}

// ---- SmsTemplate ----
class SmsTemplate {
  final int? id;
  final String templateKey;
  final String templateName;
  final String templateBody;

  SmsTemplate({
    this.id,
    required this.templateKey,
    required this.templateName,
    required this.templateBody,
  });

  factory SmsTemplate.fromMap(Map<String, dynamic> map) => SmsTemplate(
        id: map['id'],
        templateKey: map['template_key'],
        templateName: map['template_name'],
        templateBody: map['template_body'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'template_key': templateKey,
        'template_name': templateName,
        'template_body': templateBody,
      };
}

// ---- SmsLog ----
class SmsLog {
  final int? id;
  final String phoneNumber;
  final String message;
  final String sentAt;
  final String status; // sent | failed
  final int? studentId;
  final String? purpose;

  SmsLog({
    this.id,
    required this.phoneNumber,
    required this.message,
    required this.sentAt,
    required this.status,
    this.studentId,
    this.purpose,
  });

  factory SmsLog.fromMap(Map<String, dynamic> map) => SmsLog(
        id: map['id'],
        phoneNumber: map['phone_number'],
        message: map['message'],
        sentAt: map['sent_at'],
        status: map['status'],
        studentId: map['student_id'],
        purpose: map['purpose'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'phone_number': phoneNumber,
        'message': message,
        'sent_at': sentAt,
        'status': status,
        'student_id': studentId,
        'purpose': purpose,
      };
}
