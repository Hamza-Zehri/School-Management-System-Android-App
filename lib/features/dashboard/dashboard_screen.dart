import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/extended_providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../students/students_screen.dart';
import '../classes/classes_screen.dart';
import '../attendance/attendance_screen.dart';
import '../fees/fees_screen.dart';
import '../marks/marks_screen.dart';
import '../sms/sms_screen.dart';
import '../backup_restore/backup_restore_screen.dart';
import '../settings/settings_screen.dart';
import '../promotion/promotion_screen.dart';
import '../students/student_import_screen.dart';
import '../employees/employees_screen.dart';
import '../student_tests/test_history_screen.dart';
import '../attendance_history/student_attendance_history_screen.dart';

// Inline dashboard stats provider using ExtendedDatabaseHelper
final extDashboardStatsProvider = FutureProvider<ExtDashboardStats>((ref) async {
  final db = ExtendedExtendedDatabaseHelper.instance;
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final now = DateTime.now();

  final totalStudents = await db.getTotalStudentCount(isActive: true);
  final attSummary = await db.getAttendanceSummaryForToday(today);
  final feeSummary = await db.getFeeMonthSummary(now.month, now.year);
  final smsSentToday = await db.getSmsCountToday(today);
  final classes = await db.getAllClasses();
  final totalEmployees = await db.getTotalEmployeeCount(isActive: true);
  final presentEmpToday = await db.getPresentEmployeeCountToday(today);
  final salaryPaidCount = await db.getPaidSalaryCountThisMonth(now.month, now.year);

  return ExtDashboardStats(
    totalStudents: totalStudents,
    presentToday: attSummary['present'] ?? 0,
    absentToday: attSummary['absent'] ?? 0,
    feePaidCount: (feeSummary['paid'] as int?) ?? 0,
    feeUnpaidCount: (feeSummary['unpaid'] as int?) ?? 0,
    feePartialCount: (feeSummary['partial'] as int?) ?? 0,
    smsSentToday: smsSentToday,
    totalClasses: classes.length,
    totalEmployees: totalEmployees,
    presentEmployeesToday: presentEmpToday,
    salaryPaidThisMonth: salaryPaidCount,
  );
});

class ExtDashboardStats {
  final int totalStudents, presentToday, absentToday, feePaidCount, feeUnpaidCount, feePartialCount, smsSentToday, totalClasses, totalEmployees, presentEmployeesToday, salaryPaidThisMonth;
  ExtDashboardStats({required this.totalStudents, required this.presentToday, required this.absentToday, required this.feePaidCount, required this.feeUnpaidCount, required this.feePartialCount, required this.smsSentToday, required this.totalClasses, required this.totalEmployees, required this.presentEmployeesToday, required this.salaryPaidThisMonth});
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(extDashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Manager'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      drawer: _AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(extDashboardStatsProvider),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Welcome Back! 👋', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Today: ${_todayFormatted()}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Students Overview'),
          statsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (stats) => Column(children: [
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
                children: [
                  StatCard(label: 'Total Students', value: '${stats.totalStudents}', icon: Icons.people_outline, color: AppTheme.primary, onTap: () => _go(context, const StudentsScreen())),
                  StatCard(label: 'Present Today', value: '${stats.presentToday}', icon: Icons.check_circle_outline, color: AppTheme.accent, onTap: () => _go(context, const AttendanceScreen())),
                  StatCard(label: 'Absent Today', value: '${stats.absentToday}', icon: Icons.cancel_outlined, color: AppTheme.danger, onTap: () => _go(context, const AttendanceScreen())),
                  StatCard(label: 'Fee Unpaid', value: '${stats.feeUnpaidCount}', icon: Icons.money_off_outlined, color: AppTheme.danger, onTap: () => _go(context, const FeesScreen())),
                  StatCard(label: 'Fee Paid', value: '${stats.feePaidCount}', icon: Icons.payments_outlined, color: AppTheme.paid, onTap: () => _go(context, const FeesScreen())),
                  StatCard(label: 'SMS Today', value: '${stats.smsSentToday}', icon: Icons.sms_outlined, color: AppTheme.info, onTap: () => _go(context, const SmsScreen())),
                ],
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Employees Overview'),
              GridView.count(
                crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4,
                children: [
                  StatCard(label: 'Total Staff', value: '${stats.totalEmployees}', icon: Icons.badge_outlined, color: AppTheme.primaryDark, onTap: () => _go(context, const EmployeesScreen())),
                  StatCard(label: 'Present Today', value: '${stats.presentEmployeesToday}', icon: Icons.how_to_reg_outlined, color: AppTheme.accent, onTap: () => _go(context, const EmployeesScreen())),
                  StatCard(label: 'Salary Paid', value: '${stats.salaryPaidThisMonth}', icon: Icons.account_balance_wallet_outlined, color: AppTheme.paid, onTap: () => _go(context, const EmployeesScreen())),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Quick Actions'),
          _QuickActionsGrid(),
        ]),
      ),
    );
  }

  void _go(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  String _todayFormatted() {
    final now = DateTime.now();
    const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month]} ${now.year}';
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA('Attendance', Icons.fact_check_outlined, AppTheme.accent, const AttendanceScreen()),
      _QA('Add Student', Icons.person_add_outlined, AppTheme.primary, const StudentsScreen()),
      _QA('Collect Fee', Icons.payment_outlined, AppTheme.warning, const FeesScreen()),
      _QA('Daily Test', Icons.quiz_outlined, AppTheme.info, const TestHistoryScreen()),
      _QA('Employees', Icons.badge_outlined, AppTheme.primaryDark, const EmployeesScreen()),
      _QA('Import Excel', Icons.upload_file_outlined, AppTheme.accent, const StudentImportScreen()),
      _QA('Promotion', Icons.upgrade_outlined, AppTheme.primary, const PromotionScreen()),
      _QA('Att. History', Icons.history_outlined, AppTheme.warning, const StudentAttendanceHistoryScreen()),
      _QA('Backup', Icons.backup_outlined, AppTheme.accent, const BackupRestoreScreen()),
    ];
    return GridView.builder(
      itemCount: actions.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.0, mainAxisSpacing: 10, crossAxisSpacing: 10),
      itemBuilder: (ctx, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => a.screen)),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: a.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(a.icon, color: a.color, size: 24)),
              const SizedBox(height: 6),
              Text(a.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            ]),
          ),
        );
      },
    );
  }
}
class _QA { final String label; final IconData icon; final Color color; final Widget screen; _QA(this.label, this.icon, this.color, this.screen); }

class _AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: AppTheme.primary),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            Icon(Icons.school, size: 40, color: Colors.white),
            SizedBox(height: 8),
            Text('School Manager', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Offline Management System', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        _tile(context, 'Dashboard', Icons.dashboard_outlined, const DashboardScreen()),
        _tile(context, 'Classes & Sections', Icons.class_outlined, const ClassesScreen()),
        _tile(context, 'Students', Icons.people_outlined, const StudentsScreen()),
        _tile(context, 'Student Promotion', Icons.upgrade_outlined, const PromotionScreen()),
        _tile(context, 'Import from Excel', Icons.upload_file_outlined, const StudentImportScreen()),
        _tile(context, 'Attendance', Icons.fact_check_outlined, const AttendanceScreen()),
        _tile(context, 'Attendance History', Icons.history_outlined, const StudentAttendanceHistoryScreen()),
        _tile(context, 'Fee Management', Icons.payments_outlined, const FeesScreen()),
        _tile(context, 'Marks & Exams', Icons.grade_outlined, const MarksScreen()),
        _tile(context, 'Daily Tests', Icons.quiz_outlined, const TestHistoryScreen()),
        const Divider(),
        const Padding(padding: EdgeInsets.fromLTRB(16, 8, 0, 4), child: Text('EMPLOYEES', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
        _tile(context, 'Employee Management', Icons.badge_outlined, const EmployeesScreen()),
        const Divider(),
        _tile(context, 'Send SMS', Icons.sms_outlined, const SmsScreen()),
        _tile(context, 'Backup & Restore', Icons.backup_outlined, const BackupRestoreScreen()),
        _tile(context, 'Settings', Icons.settings_outlined, const SettingsScreen()),
      ]),
    );
  }

  Widget _tile(BuildContext context, String label, IconData icon, Widget screen) => ListTile(
    leading: Icon(icon, color: AppTheme.primary, size: 22),
    title: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
    onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => screen)); },
    dense: true,
  );
}
