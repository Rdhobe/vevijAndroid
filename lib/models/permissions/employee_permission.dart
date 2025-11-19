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
  static Future<bool> can(String userId, EmployeePermission permission, {Employee? targetEmployee}) async {
    final employee = await _getEmployee(userId);
    if (employee == null) return false;

    final userPermissions = employee.permissions.functions;
    final requiredPermission = permission.name;

    if (!userPermissions.contains(requiredPermission)) {
      return false;
    }

    switch (permission) {
      case EmployeePermission.viewOwnProfile:
      case EmployeePermission.viewSalary:
      default:
        return true;
    }
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