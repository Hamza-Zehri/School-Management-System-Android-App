// ============================================================
// EXTENDED MODELS — Employee, Salary, Student Tests
// Added as extension to existing models.dart — DO NOT modify models.dart
// ============================================================

// ---- Employee ----
class Employee {
  final int? id;
  final String employeeId; // unique, e.g. EMP-001
  final String fullName;
  final String fatherName;
  final String phone;
  final String? cnic;
  final String designation; // Teacher, Clerk, Peon, etc.
  final String? joiningDate;
  final double salary;
  final String? address;
  final bool isActive;
  final String? createdAt;

  Employee({
    this.id,
    required this.employeeId,
    required this.fullName,
    required this.fatherName,
    required this.phone,
    this.cnic,
    required this.designation,
    this.joiningDate,
    this.salary = 0,
    this.address,
    this.isActive = true,
    this.createdAt,
  });

  factory Employee.fromMap(Map<String, dynamic> map) => Employee(
        id: map['id'],
        employeeId: map['employee_id'],
        fullName: map['full_name'],
        fatherName: map['father_name'],
        phone: map['phone'],
        cnic: map['cnic'],
        designation: map['designation'],
        joiningDate: map['joining_date'],
        salary: (map['salary'] ?? 0).toDouble(),
        address: map['address'],
        isActive: (map['is_active'] ?? 1) == 1,
        createdAt: map['created_at'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'employee_id': employeeId,
        'full_name': fullName,
        'father_name': fatherName,
        'phone': phone,
        'cnic': cnic,
        'designation': designation,
        'joining_date': joiningDate,
        'salary': salary,
        'address': address,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };

  Employee copyWith({
    int? id,
    String? employeeId,
    String? fullName,
    String? fatherName,
    String? phone,
    String? cnic,
    String? designation,
    String? joiningDate,
    double? salary,
    String? address,
    bool? isActive,
  }) =>
      Employee(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        fullName: fullName ?? this.fullName,
        fatherName: fatherName ?? this.fatherName,
        phone: phone ?? this.phone,
        cnic: cnic ?? this.cnic,
        designation: designation ?? this.designation,
        joiningDate: joiningDate ?? this.joiningDate,
        salary: salary ?? this.salary,
        address: address ?? this.address,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

// ---- EmployeeAttendance ----
class EmployeeAttendance {
  final int? id;
  final int employeeId;
  final String attendanceDate;
  final String status; // Present | Absent | Leave
  final String? remarks;

  // Joined fields
  String? employeeName;
  String? employeePhone;
  String? designation;

  EmployeeAttendance({
    this.id,
    required this.employeeId,
    required this.attendanceDate,
    required this.status,
    this.remarks,
    this.employeeName,
    this.employeePhone,
    this.designation,
  });

  factory EmployeeAttendance.fromMap(Map<String, dynamic> map) =>
      EmployeeAttendance(
        id: map['id'],
        employeeId: map['employee_id'],
        attendanceDate: map['attendance_date'],
        status: map['status'],
        remarks: map['remarks'],
        employeeName: map['full_name'],
        employeePhone: map['phone'],
        designation: map['designation'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'employee_id': employeeId,
        'attendance_date': attendanceDate,
        'status': status,
        'remarks': remarks,
      };
}

// ---- SalaryRecord ----
class SalaryRecord {
  final int? id;
  final int employeeId;
  final int month;
  final int year;
  final double basicSalary;
  final double bonus;
  final double deduction;
  final double paidAmount;
  final String? paymentDate;
  final String status; // Unpaid | Partial | Paid
  final String? remarks;

  // Joined
  String? employeeName;
  String? employeePhone;
  String? designation;

  double get totalPayable => basicSalary + bonus - deduction;
  double get dueAmount => totalPayable - paidAmount;

  SalaryRecord({
    this.id,
    required this.employeeId,
    required this.month,
    required this.year,
    required this.basicSalary,
    this.bonus = 0,
    this.deduction = 0,
    this.paidAmount = 0,
    this.paymentDate,
    this.status = 'Unpaid',
    this.remarks,
    this.employeeName,
    this.employeePhone,
    this.designation,
  });

  factory SalaryRecord.fromMap(Map<String, dynamic> map) => SalaryRecord(
        id: map['id'],
        employeeId: map['employee_id'],
        month: map['month'],
        year: map['year'],
        basicSalary: (map['basic_salary'] ?? 0).toDouble(),
        bonus: (map['bonus'] ?? 0).toDouble(),
        deduction: (map['deduction'] ?? 0).toDouble(),
        paidAmount: (map['paid_amount'] ?? 0).toDouble(),
        paymentDate: map['payment_date'],
        status: map['status'] ?? 'Unpaid',
        remarks: map['remarks'],
        employeeName: map['full_name'],
        employeePhone: map['phone'],
        designation: map['designation'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'employee_id': employeeId,
        'month': month,
        'year': year,
        'basic_salary': basicSalary,
        'bonus': bonus,
        'deduction': deduction,
        'paid_amount': paidAmount,
        'payment_date': paymentDate,
        'status': status,
        'remarks': remarks,
      };
}

// ---- SalaryPayment ----
class SalaryPayment {
  final int? id;
  final int salaryRecordId;
  final double amount;
  final String paymentDate;
  final String? method;
  final String? remarks;

  SalaryPayment({
    this.id,
    required this.salaryRecordId,
    required this.amount,
    required this.paymentDate,
    this.method,
    this.remarks,
  });

  factory SalaryPayment.fromMap(Map<String, dynamic> map) => SalaryPayment(
        id: map['id'],
        salaryRecordId: map['salary_record_id'],
        amount: (map['amount'] ?? 0).toDouble(),
        paymentDate: map['payment_date'],
        method: map['method'],
        remarks: map['remarks'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'salary_record_id': salaryRecordId,
        'amount': amount,
        'payment_date': paymentDate,
        'method': method,
        'remarks': remarks,
      };
}

// ---- StudentTest ----
class StudentTest {
  final int? id;
  final String testDate;
  final int classId;
  final int sectionId;
  final int subjectId;
  final String? title;
  final String? createdAt;

  // Joined
  String? className;
  String? sectionName;
  String? subjectName;

  StudentTest({
    this.id,
    required this.testDate,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    this.title,
    this.createdAt,
    this.className,
    this.sectionName,
    this.subjectName,
  });

  factory StudentTest.fromMap(Map<String, dynamic> map) => StudentTest(
        id: map['id'],
        testDate: map['test_date'],
        classId: map['class_id'],
        sectionId: map['section_id'],
        subjectId: map['subject_id'],
        title: map['title'],
        createdAt: map['created_at'],
        className: map['class_name'],
        sectionName: map['section_name'],
        subjectName: map['subject_name'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'test_date': testDate,
        'class_id': classId,
        'section_id': sectionId,
        'subject_id': subjectId,
        'title': title,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };
}

// ---- StudentTestMark ----
class StudentTestMark {
  final int? id;
  final int testId;
  final int studentId;
  final double totalMarks;
  final double obtainedMarks;
  final String? remarks;

  // Joined
  String? studentName;
  String? guardianPhone;
  String? rollNo;

  double get percentage => totalMarks > 0 ? (obtainedMarks / totalMarks) * 100 : 0;

  String get grade {
    final p = percentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B';
    if (p >= 60) return 'C';
    if (p >= 50) return 'D';
    return 'F';
  }

  StudentTestMark({
    this.id,
    required this.testId,
    required this.studentId,
    required this.totalMarks,
    required this.obtainedMarks,
    this.remarks,
    this.studentName,
    this.guardianPhone,
    this.rollNo,
  });

  factory StudentTestMark.fromMap(Map<String, dynamic> map) => StudentTestMark(
        id: map['id'],
        testId: map['test_id'],
        studentId: map['student_id'],
        totalMarks: (map['total_marks'] ?? 0).toDouble(),
        obtainedMarks: (map['obtained_marks'] ?? 0).toDouble(),
        remarks: map['remarks'],
        studentName: map['full_name'],
        guardianPhone: map['guardian_phone'],
        rollNo: map['roll_no'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'test_id': testId,
        'student_id': studentId,
        'total_marks': totalMarks,
        'obtained_marks': obtainedMarks,
        'remarks': remarks,
      };
}
