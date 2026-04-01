import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/extended_providers.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'add_edit_employee_screen.dart';
import 'employee_detail_screen.dart';
import 'employee_attendance_screen.dart';
import 'salary_screen.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});
  @override
  ConsumerState<EmployeesScreen> createState() => _State();
}
class _State extends ConsumerState<EmployeesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _search = '';
  bool? _filterActive = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Staff List'),
          Tab(text: 'Attendance'),
          Tab(text: 'Salaries'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen()));
              ref.invalidate(employeesProvider);
            },
          ),
        ],
      ),
      body: TabBarView(controller: _tabs, children: [
        _StaffTab(search: _search, filterActive: _filterActive,
          onSearchChanged: (v) => setState(() => _search = v),
          onFilterChanged: (v) => setState(() => _filterActive = v)),
        const EmployeeAttendanceScreen(),
        const SalaryScreen(),
      ]),
    );
  }
}

class _StaffTab extends ConsumerWidget {
  final String search;
  final bool? filterActive;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool?> onFilterChanged;

  const _StaffTab({required this.search, required this.filterActive, required this.onSearchChanged, required this.onFilterChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(employeesProvider(filterActive));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search by name or employee ID...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
            suffixIcon: search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onSearchChanged('')) : null,
          ),
          onChanged: onSearchChanged,
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          FilterChip(label: const Text('Active'), selected: filterActive == true, onSelected: (_) => onFilterChanged(true)),
          const SizedBox(width: 8),
          FilterChip(label: const Text('Inactive'), selected: filterActive == false, onSelected: (_) => onFilterChanged(false)),
          const SizedBox(width: 8),
          FilterChip(label: const Text('All'), selected: filterActive == null, onSelected: (_) => onFilterChanged(null)),
        ]),
      ),
      Expanded(
        child: empAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (employees) {
            final filtered = search.isNotEmpty
                ? employees.where((e) => e.fullName.toLowerCase().contains(search.toLowerCase()) || e.employeeId.toLowerCase().contains(search.toLowerCase())).toList()
                : employees;
            if (filtered.isEmpty) {
              return EmptyState(message: 'No employees found', icon: Icons.people_outline,
              actionLabel: 'Add Employee',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen())).then((_) => ref.invalidate(employeesProvider)));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => _EmpTile(emp: filtered[i], onRefresh: () => ref.invalidate(employeesProvider)),
            );
          },
        ),
      ),
    ]);
  }
}

class _EmpTile extends StatelessWidget {
  final Employee emp;
  final VoidCallback onRefresh;
  const _EmpTile({required this.emp, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.12),
          child: Text(emp.fullName.substring(0,1).toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${emp.designation} • ${emp.employeeId}', style: const TextStyle(fontSize: 12)),
          Text('Rs. ${emp.salary.toStringAsFixed(0)}/month • ${emp.phone}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!emp.isActive) const StatusChip(status: 'inactive'),
          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employeeId: emp.id!))).then((_) => onRefresh()),
      ),
    );
  }
}
