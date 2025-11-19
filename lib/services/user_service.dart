import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vevij/models/employee/employee.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all employees
  Future<List<Employee>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('empName')
          .get();

      return querySnapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting all users: $e');
      throw Exception('Failed to load users: $e');
    }
  }

  // Get employees by department
  Future<List<Employee>> getUsersByDepartment(String department) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('department', isEqualTo: department)
          .orderBy('empName')
          .get();

      return querySnapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting users by department: $e');
      throw Exception('Failed to load department users: $e');
    }
  }

  // Get employees by branch
  Future<List<Employee>> getUsersByBranch(String branch) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('branch', isEqualTo: branch)
          .orderBy('empName')
          .get();

      return querySnapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting users by branch: $e');
      throw Exception('Failed to load branch users: $e');
    }
  }

  // Get user by ID
  Future<Employee?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return Employee.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      throw Exception('Failed to load user: $e');
    }
  }

  // Get users by designation (for monitors selection)
  Future<List<Employee>> getManagersAndAdmins() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('designation', whereIn: ['Manager', 'Admin', 'HR', 'Team Lead', 'Supervisor'])
          .orderBy('empName')
          .get();

      return querySnapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting managers and admins: $e');
      // Fallback: get all users and filter locally
      final allUsers = await getAllUsers();
      return allUsers.where((user) {
        final designation = user.designation.toLowerCase();
        return designation.contains('manager') || 
               designation.contains('admin') || 
               designation.contains('hr') ||
               designation.contains('lead') ||
               designation.contains('supervisor');
      }).toList();
    }
  }

  // Stream all users (real-time updates)
  Stream<List<Employee>> streamAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('empName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Employee.fromMap(doc.data()))
            .toList());
  }

  // Stream users by department (real-time updates)
  Stream<List<Employee>> streamUsersByDepartment(String department) {
    return _firestore
        .collection('users')
        .where('department', isEqualTo: department)
        .orderBy('empName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Employee.fromMap(doc.data()))
            .toList());
  }

  // Search users by name, email, or employee code
  Future<List<Employee>> searchUsers(String query) async {
    try {
      if (query.isEmpty) {
        return getAllUsers();
      }

      final lowercaseQuery = query.toLowerCase();

      // Get all users and filter locally for more flexible search
      final allUsers = await getAllUsers();
      
      return allUsers.where((user) {
        return user.empName.toLowerCase().contains(lowercaseQuery) ||
               user.email.toLowerCase().contains(lowercaseQuery) ||
               user.empCode.toLowerCase().contains(lowercaseQuery) ||
               user.designation.toLowerCase().contains(lowercaseQuery) ||
               user.department.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      print('Error updating user profile: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Update user's department
  Future<void> updateUserDepartment(String userId, String department) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'department': department,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating user department: $e');
      throw Exception('Failed to update user department: $e');
    }
  }

  // Update user's designation
  Future<void> updateUserDesignation(String userId, String designation) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'designation': designation,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating user designation: $e');
      throw Exception('Failed to update user designation: $e');
    }
  }

  // Get active employees (status based)
  Future<List<Employee>> getActiveEmployees() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('status', whereIn: ['Active', 'active', 'Working', 'working'])
          .orderBy('empName')
          .get();

      return querySnapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting active employees: $e');
      // Fallback: get all users and filter
      final allUsers = await getAllUsers();
      return allUsers.where((user) {
        final status = user.status.toLowerCase();
        return status.contains('active') || status.contains('working');
      }).toList();
    }
  }

  // Get employees by status
  Future<List<Employee>> getUsersByStatus(String status) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('status', isEqualTo: status)
          .orderBy('empName')
          .get();

      return querySnapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting users by status: $e');
      throw Exception('Failed to load users by status: $e');
    }
  }

  // Get user by employee code
  Future<Employee?> getUserByEmpCode(String empCode) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('empCode', isEqualTo: empCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Employee.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user by employee code: $e');
      throw Exception('Failed to load user by employee code: $e');
    }
  }

  // Get user by email
  Future<Employee?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Employee.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      throw Exception('Failed to load user by email: $e');
    }
  }

  // Get multiple users by their IDs
  Future<List<Employee>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];

      // Firestore has limit of 10 for 'in' queries, so we need to batch
      final batches = <List<String>>[];
      for (var i = 0; i < userIds.length; i += 10) {
        batches.add(userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10));
      }

      final allUsers = <Employee>[];
      for (final batch in batches) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('uid', whereIn: batch)
            .get();

        allUsers.addAll(querySnapshot.docs.map((doc) => Employee.fromMap(doc.data())));
      }

      return allUsers;
    } catch (e) {
      print('Error getting users by IDs: $e');
      throw Exception('Failed to load users by IDs: $e');
    }
  }

  // Update user status
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating user status: $e');
      throw Exception('Failed to update user status: $e');
    }
  }

  // Get user count by department
  Future<Map<String, int>> getUserCountByDepartment() async {
    try {
      final allUsers = await getAllUsers();
      final departmentCount = <String, int>{};
      
      for (final user in allUsers) {
        departmentCount[user.department] = (departmentCount[user.department] ?? 0) + 1;
      }
      
      return departmentCount;
    } catch (e) {
      print('Error getting user count by department: $e');
      return {};
    }
  }

  // Get user count by designation
  Future<Map<String, int>> getUserCountByDesignation() async {
    try {
      final allUsers = await getAllUsers();
      final designationCount = <String, int>{};
      
      for (final user in allUsers) {
        designationCount[user.designation] = (designationCount[user.designation] ?? 0) + 1;
      }
      
      return designationCount;
    } catch (e) {
      print('Error getting user count by designation: $e');
      return {};
    }
  }
}