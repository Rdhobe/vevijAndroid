// permission_management_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vevij/models/employee/employee.dart';
import 'package:vevij/models/permissions/employee_permission.dart';

class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({super.key});

  @override
  State<PermissionManagementPage> createState() => _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Employee> _allEmployees = [];
  List<Employee> _filteredEmployees = [];
  Employee? _selectedEmployee;
  Map<EmployeePermission, bool> _permissionStates = {};
  bool _isLoading = false;
  bool _showPermissionsPage = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _initializePermissionStates();
  }

  void _initializePermissionStates() {
    for (final permission in EmployeePermission.values) {
      _permissionStates[permission] = false;
    }
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('empName')
          .get();

      _allEmployees = querySnapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
      
      _filteredEmployees = _allEmployees;
    } catch (e) {
      _showError('Failed to load employees: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _searchEmployees(String query) {
    if (query.isEmpty) {
      setState(() => _filteredEmployees = _allEmployees);
      return;
    }

    setState(() {
      _filteredEmployees = _allEmployees.where((employee) {
        final name = employee.empName.toLowerCase();
        final code = employee.empCode.toLowerCase();
        final searchTerm = query.toLowerCase();
        return name.contains(searchTerm) || code.contains(searchTerm);
      }).toList();
    });
  }

  Future<void> _selectEmployee(Employee employee) async {
    setState(() {
      _selectedEmployee = employee;
      _isLoading = true;
    });

    try {
      final userPermissions = await EmployeePermissionChecker.getUserPermissions(employee.uid);
      
      for (final permission in EmployeePermission.values) {
        _permissionStates[permission] = userPermissions.contains(permission);
      }
      
      // Navigate to permissions page
      setState(() {
        _showPermissionsPage = true;
      });
    } catch (e) {
      _showError('Failed to load permissions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goBackToEmployeeList() {
    setState(() {
      _showPermissionsPage = false;
      _selectedEmployee = null;
      _searchController.clear();
      _filteredEmployees = _allEmployees;
    });
  }

  void _togglePermission(EmployeePermission permission, bool value) {
    setState(() {
      _permissionStates[permission] = value;
    });
  }

  Future<void> _savePermissions() async {
    if (_selectedEmployee == null) return;

    setState(() => _isLoading = true);
    try {
      final selectedPermissions = _permissionStates.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      await EmployeePermissionChecker.updateUserPermissions(
        _selectedEmployee!.uid,
        selectedPermissions,
      );

      _showSuccess('Permissions updated successfully!');
      _goBackToEmployeeList();
    } catch (e) {
      _showError('Failed to update permissions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showPermissionsPage 
            ? Text('Manage ${_selectedEmployee?.empName ?? ""} Permissions')
            : const Text('Select Employee'),
        leading: _showPermissionsPage
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBackToEmployeeList,
              )
            : null,
      ),
      body: _showPermissionsPage 
          ? _buildPermissionPanel()
          : _buildEmployeeList(),
    );
  }

  Widget _buildEmployeeList() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search employees by name or code...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: _searchEmployees,
          ),
        ),
        
        // Employee List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEmployees.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No employees found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = _filteredEmployees[index];
                        return _buildEmployeeListItem(employee);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmployeeListItem(Employee employee) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            employee.empName.isNotEmpty ? employee.empName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          employee.empName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Employee Code: ${employee.empCode}'),
            Text('Department: ${employee.department}'),
            Text('Current Role: ${employee.permissions.type}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _selectEmployee(employee),
      ),
    );
  }

  Widget _buildPermissionPanel() {
    return Column(
      children: [
        // Employee Summary Card
        Card(
          margin: const EdgeInsets.all(16.0),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  radius: 24,
                  child: Text(
                    _selectedEmployee!.empName[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedEmployee!.empName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Employee Code: ${_selectedEmployee!.empCode}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'Department: ${_selectedEmployee!.department}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Permissions Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage Permissions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _savePermissions,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Permissions List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: EmployeePermission.values.length,
                  itemBuilder: (context, index) {
                    final permission = EmployeePermission.values[index];
                    final isEnabled = _permissionStates[permission] ?? false;
                    
                    return _buildPermissionItem(permission, isEnabled);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem(EmployeePermission permission, bool isEnabled) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 1,
      child: ListTile(
        leading: Icon(
          isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isEnabled ? Colors.green : Colors.grey,
          size: 24,
        ),
        title: Text(
          permission.displayName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: isEnabled ? Colors.black : Colors.grey[600],
          ),
        ),
        subtitle: Text(
          permission.description,
          style: TextStyle(
            fontSize: 14,
            color: isEnabled ? Colors.grey[700] : Colors.grey[500],
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (value) => _togglePermission(permission, value),
          activeColor: Colors.green,
        ),
        onTap: () => _togglePermission(permission, !isEnabled),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}