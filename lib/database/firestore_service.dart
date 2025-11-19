import 'package:vevij/components/imports.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ========== EMPLOYEE MANAGEMENT ==========

  // Get all employees
  static Future<List<Employee>> getAllEmployees() async {
    try {
      final snapshot = await _db.collection('users').get();
      print('Fetched ${snapshot.docs.length} employees');
      return snapshot.docs.map((d) => Employee.fromMap(d.data())).toList();
    } catch (e) {
      print('Error fetching employees: $e');
      return [];
    }
  }

  // Get employee by ID
  static Future<Employee?> getEmployeeById(String employeeId) async {
    try {
      final doc = await _db.collection('users').doc(employeeId).get();
      if (doc.exists) {
        return Employee.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error fetching employee by ID: $e');
      return null;
    }
  }

  // Debug method to check employee data
  static Future<void> debugEmployeeData(String employeeId) async {
    try {
      final doc = await _db.collection('users').doc(employeeId).get();
      if (doc.exists) {
        print('=== DEBUG: Employee Data for $employeeId ===');
        print('Document exists: ${doc.exists}');
        print('Data: ${doc.data()}');
      } else {
        print('=== DEBUG: Employee document does not exist ===');
      }
    } catch (e) {
      print('Debug error: $e');
    }
  }
}