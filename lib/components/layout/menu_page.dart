// menu_page.dart
import 'package:flutter/material.dart';
import 'package:vevij/models/permissions/employee_permission.dart';
import 'package:vevij/components/pages/permission_management_page.dart';
import 'package:vevij/components/pages/atttendance/mark_attendance.dart';
import 'package:vevij/components/pages/atttendance/empattandance.dart';
import 'package:vevij/components/pages/atttendance/employeeattendancereportpage.dart';
import 'package:vevij/components/pages/atttendance/admin_attendace_report_page.dart';
import 'package:vevij/components/pages/atttendance/lateloginapprovalpage.dart';
import 'package:vevij/components/pages/employee management/employee_request_page.dart';
import 'package:vevij/components/pages/employee management/admin_request_page.dart';
import 'package:vevij/components/pages/employee management/admin_hr_location_montering.dart';
import 'package:vevij/components/pages/task management/team_list_page.dart';
import 'package:vevij/components/pages/salary%20management/salary_management.dart';
import 'package:vevij/components/pages/salary%20management/admin_salary_management.dart';
import 'package:vevij/components/pages/project management/project_view_page.dart';
import 'package:vevij/components/pages/project management/project_management.dart';
import 'package:vevij/components/pages/project management/project_report.dart';
import 'package:vevij/components/chat/chat_page.dart';
class MenuPage extends StatefulWidget {
  final String userId;
  final String userName;
  final Map<String, dynamic> employeeData;
  const MenuPage({super.key, required this.userId, required this.userName, required this.employeeData});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    setState(() => _isLoading = true);
    
    final items = <MenuItem>[];

    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.manageAttendance)) {
      items.add(MenuItem(
        title: 'Attendance overview',
        icon: Icons.access_time,
        color: Colors.blue,
        page: EmployeeAttendancePage( 
          employeeId: widget.userId,
          employeeName: widget.userName,
        ),
        requiredPermission: EmployeePermission.manageAttendance,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.manageAttendance)) {
      items.add(MenuItem(
        title: 'Attendance Report',
        icon: Icons.access_time,
        color: Colors.orange,
        page: AttendanceReportPage(),
        requiredPermission: EmployeePermission.manageAttendance,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.manageAttendance)) {
      items.add(MenuItem(
        title: 'Attendance',
        icon: Icons.access_time,
        color: Colors.green,
        page: const MarkAttendancePage(),
        requiredPermission: EmployeePermission.manageAttendance,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.adminManageAttendance)) {
      items.add(MenuItem(
        title: 'Attendance Report(Admin)',
        icon: Icons.access_time,
        color: Colors.purple,
        page: const AdminAttendanceReportPage(),
        requiredPermission: EmployeePermission.adminManageAttendance,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.adminManageAttendance)) {
      items.add(MenuItem(
        title: 'Late Login Approval(Admin)',
        icon: Icons.access_time,
        color: Colors.purple,
        page: const LateLoginApprovalPage(),
        requiredPermission: EmployeePermission.adminManageAttendance,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.managePermissions)) {
      items.add(MenuItem(
        title: 'Permissions',
        icon: Icons.admin_panel_settings,
        color: Colors.red,
        page: PermissionManagementPage(),
        requiredPermission: EmployeePermission.managePermissions,
      ));
    }

    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.monitorLocations)) {
      items.add(MenuItem(
        title: 'location Monitoring',
        icon: Icons.location_on,
        color: Colors.teal,
        page: HRLocationMonitorPage(),
        requiredPermission: EmployeePermission.monitorLocations,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.adminManageLeaves)) {
      items.add(MenuItem(
        title: 'Employee Requests - Admin',
        icon: Icons.request_page,
        color: Colors.greenAccent,
        page: AdminRequestManagementPage(),
        requiredPermission: EmployeePermission.adminManageLeaves,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.tasksManagement)) {
      items.add(MenuItem(
        title: 'Tasks management',
        icon: Icons.task,
        color: Colors.orangeAccent,
        page: TeamListPage(),
        requiredPermission: EmployeePermission.tasksManagement,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.viewSalary)) {
      items.add(MenuItem(
        title: 'Employee Salary',
        icon: Icons.attach_money,
        color: Colors.brown,
        page: EmployeeSalaryPage(userId: widget.userId),
        requiredPermission: EmployeePermission.viewSalary,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.adminSalary)) {
      items.add(MenuItem(
        title: 'admin salary management',
        icon: Icons.manage_accounts_outlined,
        color: Colors.cyan,
        page: AdminSalaryManagementPage(),
        requiredPermission: EmployeePermission.adminSalary,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.viewProjects)) {
      items.add(MenuItem(
        title: 'Projects',
        icon: Icons.folder_open,
        color: Colors.purpleAccent,
        page: ProjectViewPage(),
        requiredPermission: EmployeePermission.viewProjects,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.manageProjects)) {
      items.add(MenuItem(
        title: 'Projects Management',
        icon: Icons.settings_applications,
        color: Colors.purpleAccent,
        page: ProjectManagementPage(),
        requiredPermission: EmployeePermission.manageProjects,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.reportProjects)) {
      items.add(MenuItem(
        title: 'Project Reports',
        icon: Icons.folder_open,
        color: Colors.redAccent,
        page: ProjectReportPage(),
        requiredPermission: EmployeePermission.reportProjects,
      ));
    }
    if (await EmployeePermissionChecker.can(widget.userId, EmployeePermission.manageLeaves)) {
      items.add(MenuItem(
        title: 'Employee Requests',
        icon: Icons.request_page,
        color: Colors.blueAccent,
        page: EmployeeRequestsPage(userId: widget.userId, userName: widget.userName, employeeData: widget.employeeData,),
        requiredPermission: EmployeePermission.manageLeaves,
      ));
    }

    setState(() {
      _menuItems = items;
      _isLoading = false;
    });
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vevij ERP'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMenuItems,
            tooltip: 'Refresh Menu',
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPage())),
            tooltip: 'Chat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _menuItems.isEmpty
              ? _buildEmptyState()
              : _buildMenuGrid(),
    );
  }

  Widget _buildMenuGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.2,
        ),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          return _buildMenuCard(item);
        },
      ),
    );
  }

  Widget _buildMenuCard(MenuItem item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToPage(item.page),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [item.color.withOpacity(0.1), item.color.withOpacity(0.3)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 32, color: item.color),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
                softWrap: true,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (item.requiredPermission != null)
                FutureBuilder<bool>(
                  future: EmployeePermissionChecker.can(widget.userId, item.requiredPermission!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Authorized',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Access Granted',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact administrator to get access to modules',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadMenuItems,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Permissions Again'),
          ),
        ],
      ),
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;
  final EmployeePermission? requiredPermission;

  MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.page,
    this.requiredPermission,
  });
}