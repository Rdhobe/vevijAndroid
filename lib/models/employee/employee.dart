import 'package:vevij/components/imports.dart';
import 'package:vevij/models/permissions/permissions.dart';
// Update your Employee class - add permissions field
class Employee {
  double? salary;
  final String aadharNumber;
  final BankDetails bankDetails;
  final String birthDate;
  final String branch;
  final String shift;
  final String workLocation;
  final DateTime createdAt;
  final String department;
  final String designation;
  final String email;
  final String empCode;
  final String empName;
  final String gender;
  final String grade;
  final String joinDate;
  final String lastIncrementDate;
  final String lastWorkingDate;
  final String panNumber;
  final String paymentMode;
  final Permission permissions; // Add this line
  final String probationDate;
  final String resignOfferDate;
  final String serviceMonth;
  final String status;
  final String title;
  final String uid;

  Employee({
    this.salary,
    required this.aadharNumber,
    required this.bankDetails,
    required this.birthDate,
    required this.branch,
    required this.shift,
    required this.workLocation,
    required this.createdAt,
    required this.department,
    required this.designation,
    required this.email,
    required this.empCode,
    required this.empName,
    required this.gender,
    required this.grade,
    required this.joinDate,
    required this.lastIncrementDate,
    required this.lastWorkingDate,
    required this.panNumber,
    required this.paymentMode,
    required this.permissions, // Add this
    required this.probationDate,
    required this.resignOfferDate,
    required this.serviceMonth,
    required this.status,
    required this.title,
    required this.uid,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      aadharNumber: map['aadharNumber'] ?? '',
      bankDetails: BankDetails.fromMap(Map<String, dynamic>.from(map['bankDetails'] ?? {})),
      birthDate: map['birthDate'] ?? '',
      branch: map['branch'] ?? '',
      shift: map['shift'] ?? '',
      workLocation: map['workLocation'] ?? '',
      createdAt: map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : (map['createdAt'] is String
            ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
            : DateTime.now()),
      department: map['department'] ?? '',
      designation: map['designation'] ?? '',
      email: map['email'] ?? '',
      empCode: map['empCode'] ?? '',
      empName: map['empName'] ?? '',
      gender: map['gender'] ?? '',
      grade: map['grade'] ?? '',
      joinDate: map['joinDate'] ?? '',
      lastIncrementDate: map['lastIncrementDate'] ?? '',
      lastWorkingDate: map['lastWorkingDate'] ?? '',
      panNumber: map['panNumber'] ?? '',
      paymentMode: map['paymentMode'] ?? '',
      permissions: Permission.fromMap(Map<String, dynamic>.from(map['permissions'] ?? {}), map['uid'] ?? ''), // Add this
      probationDate: map['probationDate'] ?? '',
      resignOfferDate: map['resignOfferDate'] ?? '',
      serviceMonth: map['serviceMonth'] ?? '',
      status: map['status'] ?? '',
      title: map['title'] ?? '',
      uid: map['uid'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aadharNumber': aadharNumber,
      'bankDetails': bankDetails.toMap(),
      'birthDate': birthDate,
      'branch': branch,
      'shift': shift,
      'workLocation': workLocation,
      'createdAt': Timestamp.fromDate(createdAt),
      'department': department,
      'designation': designation,
      'email': email,
      'empCode': empCode,
      'empName': empName,
      'gender': gender,
      'grade': grade,
      'joinDate': joinDate,
      'lastIncrementDate': lastIncrementDate,
      'lastWorkingDate': lastWorkingDate,
      'panNumber': panNumber,
      'paymentMode': paymentMode,
      'permissions': permissions.toMap(), // Add this
      'probationDate': probationDate,
      'resignOfferDate': resignOfferDate,
      'serviceMonth': serviceMonth,
      'status': status,
      'title': title,
      'uid': uid,
    };
  }

  // Also update the copyWith method to include permissions
  Employee copyWith({
    String? aadharNumber,
    BankDetails? bankDetails,
    String? birthDate,
    String? branch,
    String? shift,
    String? workLocation,
    DateTime? createdAt,
    String? department,
    String? designation,
    String? email,
    String? empCode,
    String? empName,
    String? gender,
    String? grade,
    String? joinDate,
    String? lastIncrementDate,
    String? lastWorkingDate,
    String? panNumber,
    String? paymentMode,
    Permission? permissions, // Add this
    String? probationDate,
    String? resignOfferDate,
    String? serviceMonth,
    String? status,
    String? title,
    String? uid,
  }) {
    return Employee(
      salary: salary?.toDouble(),
      aadharNumber: aadharNumber ?? this.aadharNumber,
      bankDetails: bankDetails ?? this.bankDetails,
      birthDate: birthDate ?? this.birthDate,
      branch: branch ?? this.branch,
      shift: shift ?? this.shift,
      workLocation: workLocation ?? this.workLocation,
      createdAt: createdAt ?? this.createdAt,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      email: email ?? this.email,
      empCode: empCode ?? this.empCode,
      empName: empName ?? this.empName,
      gender: gender ?? this.gender,
      grade: grade ?? this.grade,
      joinDate: joinDate ?? this.joinDate,
      lastIncrementDate: lastIncrementDate ?? this.lastIncrementDate,
      lastWorkingDate: lastWorkingDate ?? this.lastWorkingDate,
      panNumber: panNumber ?? this.panNumber,
      paymentMode: paymentMode ?? this.paymentMode,
      permissions: permissions ?? this.permissions, // Add this
      probationDate: probationDate ?? this.probationDate,
      resignOfferDate: resignOfferDate ?? this.resignOfferDate,
      serviceMonth: serviceMonth ?? this.serviceMonth,
      status: status ?? this.status,
      title: title ?? this.title,
      uid: uid ?? this.uid,
    );
  }

  // Update the static methods to include permissions
  static String getEmployeeName(String userId, List<Employee> employees) {
    final employee = employees.firstWhere(
      (emp) => emp.uid == userId, 
      orElse: () => Employee(
        uid: '',
        empName: 'Unknown',
        empCode: '',
        email: '',
        aadharNumber: '',
        bankDetails: BankDetails(accountNumber: '', bankName: '', branch: '', ifscCode: ''),
        birthDate: '',
        branch: '',
        shift: '',
        workLocation: '',
        createdAt: DateTime.now(),
        department: '',
        designation: '',
        gender: '',
        grade: '',
        joinDate: '',
        lastIncrementDate: '',
        lastWorkingDate: '',
        panNumber: '',
        paymentMode: '',
        permissions: Permission(id: '', name: '', type: '', functions: [], createdAt: DateTime.now()), // Add this
        probationDate: '',
        resignOfferDate: '',
        serviceMonth: '',
        status: '',
        title: '',
      )
    );
    return employee.empName;
  }

  factory Employee.unknown() {
    return Employee(
      uid: '',
      empName: 'Unknown',
      empCode: '',
      email: '',
      aadharNumber: '',
      bankDetails: BankDetails(accountNumber: '', bankName: '', branch: '', ifscCode: ''),
      birthDate: '',
      branch: '',
      shift: '',
      workLocation: '',
      createdAt: DateTime.now(),
      department: '',
      designation: '',
      gender: '',
      grade: '',
      joinDate: '',
      lastIncrementDate: '',
      lastWorkingDate: '',
      panNumber: '',
      paymentMode: '',
      permissions: Permission(id: '', name: '', type: '', functions: [], createdAt: DateTime.now()), // Add this
      probationDate: '',
      resignOfferDate: '',
      serviceMonth: '',
      status: '',
      title: '',
    );
  }
  static String getEmployeeCode(String userId, List<Employee> employees) {
    final employee = employees.firstWhere(
      (emp) => emp.uid == userId,
      orElse: () => Employee(
        uid: '',
        empName: 'Unknown',
        empCode: '',
        email: '',
        aadharNumber: '',
        bankDetails: BankDetails(accountNumber: '', bankName: '', branch: '', ifscCode: ''),
        birthDate: '',
        branch: '',
        shift: '',
        workLocation: '',
        createdAt: DateTime.now(),
        department: '',
        designation: '',
        gender: '',
        grade: '',
        joinDate: '',
        lastIncrementDate: '',
        lastWorkingDate: '',
        panNumber: '',
        paymentMode: '',
        probationDate: '',
        resignOfferDate: '',
        serviceMonth: '',
        status: '',
        title: '',
        permissions: Permission(id: '', name: '', type: '', functions: [], createdAt: DateTime.now()), // Add this
      )
    );
    return employee.empCode;
  }
}

class BankDetails {
  final String accountNumber;
  final String bankName;
  final String branch;
  final String ifscCode;

  BankDetails({
    required this.accountNumber,
    required this.bankName,
    required this.branch,
    required this.ifscCode,
  });

  factory BankDetails.fromMap(Map<String, dynamic> map) {
    return BankDetails(
      accountNumber: map['accountNumber'] ?? '',
      bankName: map['bankName'] ?? '',
      branch: map['branch'] ?? '',
      ifscCode: map['ifscCode'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountNumber': accountNumber,
      'bankName': bankName,
      'branch': branch,
      'ifscCode': ifscCode,
    };
  }

  BankDetails copyWith({
    String? accountNumber,
    String? bankName,
    String? branch,
    String? ifscCode,
  }) {
    return BankDetails(
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      ifscCode: ifscCode ?? this.ifscCode,
    );
  }
}

