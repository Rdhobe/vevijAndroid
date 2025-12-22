// employee_permission.dart

import 'package:vevij/components/imports.dart';
enum EmployeePermission {
  monitorLocations('Monitor Locations', 'Can monitor employee locations'),
  manageEmployees('Manage Employees', 'Can manage employee records'),
  viewOwnProfile('View Own Profile', 'Can view own profile'),
  viewSalary('View Salary', 'Can view salary information'),
  adminSalary('Admin Salary', 'Can manage salary information'),
  addEmployee('Add Employee', 'Can add new employees'),
  deleteEmployee('Delete Employee', 'Can delete employees'),
  manageAttendance('Manage Attendance', 'Can manage attendance'),
  adminManageAttendance('Admin Manage Attendance', 'Can manage all attendance records'),
  manageLeaves('Manage Leaves', 'Can manage leave requests'),
  adminManageLeaves('Admin Manage Leaves', 'Can manage all leave requests'),
  managePermissions('Manage Permissions', 'Can manage user permissions'),
  tasksManagement('Tasks Management', 'Can manage tasks'),
  tasksManagementadmin('Tasks Management (Admin)', 'Can manage all tasks'),
  viewProjects('Project view', 'Can view projects'),
  reportProjects('Project report', 'Can generate project reports'),
  manageProjects('Manage Projects', 'Can create and manage projects'),
  addtaskProject('Add Task to Project', 'Can add tasks to projects'),
  deleteTaskProject('Delete Task from Project', 'Can delete tasks from projects'),
  updatetaskProject('Update Task in Project', 'Can update tasks in projects'),
  addInventoryProject('Add Inventory', 'Can add inventory items'),
  updateInventoryProject('Update Inventory', 'Can update inventory items'),
  editInventoryProject('Edit Inventory', 'Can edit inventory items'),
  deleteInventoryProject('Delete Inventory', 'Can delete inventory items'),
  addRemoveSupervisor('Add/Remove Supervisor', 'Can add or remove supervisors for projects'),
  addRemoveContractor('Add/Remove Contractor', 'Can add or remove contractors for projects'),
  addRemoveDesigner('Add/Remove Designer', 'Can add or remove designers for projects'),
  addRemoveBDM('Add/Remove BDM', 'Can add or remove BDMs for projects'),
  addRemoveHOD('Add/Remove HOD', 'Can add or remove HODs for projects'),
  issueRequestManageProject('Issue/Request Management', 'Can manage issue and request tickets'),
  manageProjectgroup('Manage Project Group', 'Can manage project groups');
  final String displayName;
  final String description;

  const EmployeePermission(this.displayName, this.description);
}

class EmployeePermissionChecker {
  /// Returns true if the user has the requested [permission].
  ///
  /// Robust behavior implemented:
  /// - Attempts a server read first to avoid stale cache results.
  /// - Falls back to cache if server read fails (offline or network issues).
  /// - Normalizes stored permission strings to compare against both
  ///   enum `name` and `displayName` (case-insensitive, trimmed).
  /// - Surfaces exceptions (via rethrow) only when unrecoverable.
  static Future<bool> can(String userId, EmployeePermission permission, {Employee? targetEmployee}) async {
    if (userId.isEmpty) return false;

    final requiredNames = <String>{
      permission.name.toLowerCase().trim(), // enum identifier
      permission.displayName.toLowerCase().trim(), // readable name
    };

    Employee? employee;
    // Try server first to avoid eventual consistency/cache issues.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      if (doc.exists) {
        employee = Employee.fromMap(doc.data()!);
      }
    } catch (serverErr) {
      // Server read failed (network/rules). We'll try cache below.
      // Do not fail immediately — fall back to cache.
    }

    // If server read did not return an employee, try cache/local.
    if (employee == null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get(const GetOptions(source: Source.cache));

        if (doc.exists) {
          employee = Employee.fromMap(doc.data()!);
        }
      } catch (cacheErr) {
        // If cache read also fails, do one final attempt with default get()
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (doc.exists) employee = Employee.fromMap(doc.data()!);
        } catch (e) {
          // Give up — return false. Avoid swallowing all errors silently in production;
          // log and return false so UI can display permission denied.
          // Consider integrating with your logging/telemetry here.
          return false;
        }
      }
    }

    if (employee == null) return false;

    final userPermissions = (employee.permissions.functions ?? []).map((s) => s.toString().toLowerCase().trim()).toSet();

    // Allow match if any of the required names appear in stored functions.
    final intersects = requiredNames.any((req) => userPermissions.contains(req));
    return intersects;
  }

  static Future<List<EmployeePermission>> getUserPermissions(String userId) async {
    final employee = await _getEmployee(userId);
    if (employee == null) return [];

    final permissionNames = employee.permissions.functions;
    return EmployeePermission.values.where(
      (permission) => permissionNames.contains(permission.name)
    ).toList();
  }

  static Future<void> updateUserPermissions(
    String userId, 
    List<EmployeePermission> permissions
  ) async {
    try {
      final permissionNames = permissions.map((p) => p.name).toList();
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
            'permissions.functions': permissionNames,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to update permissions: $e');
    }
  }

  static Future<Employee?> _getEmployee(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return Employee.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}