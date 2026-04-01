# School Manager v2 — Changes & Extensions

## What's New in v2

### 1. Fee Management Fix
- **Root cause fixed**: `getStudentsByClassSection()` now uses explicit `INNER JOIN` with correct column aliases
- Added `dart:developer` debug logs: logs `classId`, `sectionId`, and student count on every query
- `getFeeRecords()` also has explicit column SELECT to prevent ambiguous column errors
- `getFeeRecordById()` new helper for payment lookup
- All queries use parameterized args (no string interpolation)

### 2. Employee Management Module (`lib/features/employees/`)
**New screens:**
- `employees_screen.dart` — tabbed: Staff List, Attendance, Salaries
- `add_edit_employee_screen.dart` — full form with designation picker, auto-generate EMP-ID
- `employee_detail_screen.dart` — profile view with edit/delete

**Database table: `employees`**
```sql
id, employee_id (UNIQUE), full_name, father_name, phone, cnic,
designation, joining_date, salary, address, is_active, created_at
```

### 3. Employee Attendance Module
**New screen:** `employee_attendance_screen.dart` (inside employees tab)
- Select date, load all active employees
- P/A/L segmented toggle per employee
- Save batch with duplicate prevention (`UNIQUE employee_id, attendance_date`)
- Auto-sends Absent SMS to employee phone

**Database table: `employee_attendance`**
```sql
id, employee_id, attendance_date, status (Present/Absent/Leave), remarks
UNIQUE(employee_id, attendance_date)
```

### 4. Salary Management Module
**New screen:** `salary_screen.dart` (inside employees tab)
- Generate monthly salary records for all active employees
- Record partial/full payments with method (Cash/Bank/Cheque)
- Auto-calculates: `total = basic + bonus - deduction`
- Status: Unpaid → Partial → Paid
- Sends "Salary Paid" SMS when fully paid

**Database tables:**
```sql
salary_records: id, employee_id, month, year, basic_salary, bonus,
                deduction, paid_amount, payment_date, status, remarks
                UNIQUE(employee_id, month, year)

salary_payments: id, salary_record_id, amount, payment_date, method, remarks
```

### 5. Student Daily Test Module (`lib/features/student_tests/`)
**New screens:**
- `create_test_screen.dart` — select class/section/subject/date, inline marks entry grid
- `test_history_screen.dart` — filterable list of all tests
- `test_result_screen.dart` — per-test results with grade, %, highest/lowest

**Database tables:**
```sql
student_tests: id, test_date, class_id, section_id, subject_id, title, created_at

student_test_marks: id, test_id, student_id, total_marks, obtained_marks, remarks
                    UNIQUE(test_id, student_id)
```

**SMS after saving test:**
Template: `"Dear Parent, {student_name} scored {obtained_marks}/{total_marks} in {subject_name} test on {test_date}. Remarks: {remarks}"`

### 6. Attendance History (`lib/features/attendance_history/`)
**New screens:**
- `student_attendance_history_screen.dart` — pick student + date range, summary stats
- `employee_attendance_history_screen.dart` — pick employee + date range, summary stats

Both show Present/Absent/Late/Leave count summary and date-by-date list.

### 7. Dashboard Updates
- New stat cards: Total Employees, Present Employees Today, Salary Paid This Month
- New quick actions: Daily Tests, Attendance History, Employees
- Extended drawer with all new sections

### 8. New SMS Templates (auto-seeded on upgrade)
| Key | Template |
|---|---|
| `test_result` | Student test score notification |
| `salary_paid` | Salary payment confirmation |
| `employee_absent` | Employee absent alert |

---

## Architecture Notes

### Database Migration (Safe)
- DB version bumped: `1 → 2`
- `onUpgrade` only adds new tables using `CREATE TABLE IF NOT EXISTS`
- Existing data is **never touched** during upgrade
- All new tables use `IF NOT EXISTS` — safe to run multiple times

### Single DB Entry Point
`ExtendedDatabaseHelper` replaces `DatabaseHelper`:
- `database_helper.dart` is now a thin re-export stub: `export 'extended_database_helper.dart'`
- All screens use `ExtendedDatabaseHelper.instance`
- Providers updated to use `ExtendedDatabaseHelper`

### New Services
| Service | File |
|---|---|
| Employee CRUD + Salary | `employee_service.dart` |
| Student Test + SMS | `student_test_service.dart` |
| Extended Providers | `extended_providers.dart` |

---

## New SQL Tables Summary

```sql
-- Employees
CREATE TABLE IF NOT EXISTS employees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL, father_name TEXT NOT NULL,
  phone TEXT NOT NULL, cnic TEXT, designation TEXT NOT NULL,
  joining_date TEXT, salary REAL DEFAULT 0,
  address TEXT, is_active INTEGER DEFAULT 1, created_at TEXT
);

-- Employee Attendance
CREATE TABLE IF NOT EXISTS employee_attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL, attendance_date TEXT NOT NULL,
  status TEXT NOT NULL, remarks TEXT,
  UNIQUE(employee_id, attendance_date),
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

-- Salary Records
CREATE TABLE IF NOT EXISTS salary_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL, month INTEGER NOT NULL, year INTEGER NOT NULL,
  basic_salary REAL DEFAULT 0, bonus REAL DEFAULT 0, deduction REAL DEFAULT 0,
  paid_amount REAL DEFAULT 0, payment_date TEXT, status TEXT DEFAULT 'Unpaid',
  remarks TEXT, UNIQUE(employee_id, month, year),
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

-- Salary Payments
CREATE TABLE IF NOT EXISTS salary_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  salary_record_id INTEGER NOT NULL, amount REAL NOT NULL,
  payment_date TEXT NOT NULL, method TEXT, remarks TEXT,
  FOREIGN KEY (salary_record_id) REFERENCES salary_records(id)
);

-- Student Tests
CREATE TABLE IF NOT EXISTS student_tests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  test_date TEXT NOT NULL, class_id INTEGER NOT NULL,
  section_id INTEGER NOT NULL, subject_id INTEGER NOT NULL,
  title TEXT, created_at TEXT,
  FOREIGN KEY (class_id) REFERENCES classes(id),
  FOREIGN KEY (section_id) REFERENCES sections(id),
  FOREIGN KEY (subject_id) REFERENCES subjects(id)
);

-- Student Test Marks
CREATE TABLE IF NOT EXISTS student_test_marks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  test_id INTEGER NOT NULL, student_id INTEGER NOT NULL,
  total_marks REAL DEFAULT 0, obtained_marks REAL DEFAULT 0,
  remarks TEXT, UNIQUE(test_id, student_id),
  FOREIGN KEY (test_id) REFERENCES student_tests(id),
  FOREIGN KEY (student_id) REFERENCES students(id)
);
```

---

## Upgrade Path (Existing Install)

If upgrading from v1:
1. Replace all files in `lib/` with v2 files
2. On next app launch, `onUpgrade` runs automatically
3. New tables are created, new SMS templates are seeded
4. **All existing data is preserved** — no data loss

If doing fresh install:
1. `flutter pub get`
2. `flutter build apk --release`
3. Install APK on Android device

