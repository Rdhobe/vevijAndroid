import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CreateEmployeePage extends StatefulWidget {
  const CreateEmployeePage({super.key});

  @override
  State<CreateEmployeePage> createState() => _CreateEmployeePageState();
}

class _CreateEmployeePageState extends State<CreateEmployeePage> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentSection = 0;
  final int _totalSections = 5;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _empNameController = TextEditingController();
  final TextEditingController _empCodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _joinDateController = TextEditingController();
  final TextEditingController _lastWorkingDateController = TextEditingController();
  final TextEditingController _resignOfferDateController = TextEditingController();
  final TextEditingController _lastIncrementDateController = TextEditingController();
  final TextEditingController _probationDateController = TextEditingController();
  final TextEditingController _serviceMonthController = TextEditingController();
  final TextEditingController _ifscCodeController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _bankBranchController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _panController = TextEditingController();

  // Dropdown values
  String? _selectedTitle = 'Mr';
  String? _selectedGrade;
  String? _selectedBranch;
  String? _selectedDepartment;
  String? _selectedDesignation;
  String? _selectedGender;
  String? _selectedStatus = 'Active';
  String? _selectedPaymentMode;

  // Dropdown options
  final List<String> _titles = ['Mr', 'Mrs', 'Ms'];
  final List<String> _genders = ['Male', 'Female', 'Other'];
  List<String> _designations = [];
  List<String> _departments = [];
  List<String> _branches = [];
  List<String> _statuses = [];
  List<String> _paymentModes = [];
  List<String> _grades = [];
  String? _selectedPermission;
  final List<String> _permissions = ['All', 'View Only'];
  bool _showPermissionField = false;

  @override
  void dispose() {
    _empNameController.dispose();
    _empCodeController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    _joinDateController.dispose();
    _lastWorkingDateController.dispose();
    _resignOfferDateController.dispose();
    _lastIncrementDateController.dispose();
    _probationDateController.dispose();
    _serviceMonthController.dispose();
    _ifscCodeController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _bankBranchController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _pageController.dispose();
    super.dispose();
  }
Future<void> _loadDropdownData() async {
  try {
    // Fetch all dropdown collections
    final futures = await Future.wait([
      FirebaseFirestore.instance.collection('dropdowns').doc('designations').get(),
      FirebaseFirestore.instance.collection('dropdowns').doc('departments').get(),
      FirebaseFirestore.instance.collection('dropdowns').doc('branches').get(),
      FirebaseFirestore.instance.collection('dropdowns').doc('statuses').get(),
      FirebaseFirestore.instance.collection('dropdowns').doc('paymentModes').get(),
      FirebaseFirestore.instance.collection('dropdowns').doc('grades').get(),
    ]);

    setState(() {
      _designations = List<String>.from(futures[0].data()?['values'] ?? []);
      _departments = List<String>.from(futures[1].data()?['values'] ?? []);
      _branches = List<String>.from(futures[2].data()?['values'] ?? []);
      _statuses = List<String>.from(futures[3].data()?['values'] ?? []);
      _paymentModes = List<String>.from(futures[4].data()?['values'] ?? []);
      _grades = List<String>.from(futures[5].data()?['values'] ?? []);
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dropdown data: $e')),
      );
    }
  }
}
// Add this method to check if permission field should be shown
void _checkPermissionVisibility() {
  setState(() {
    _showPermissionField = _selectedDepartment == 'Admin' && _selectedDesignation == 'Admin';
    if (!_showPermissionField) {
      _selectedPermission = null;
    }
  });
}

  String _generatePassword() {
    if (_empNameController.text.isEmpty || _birthDateController.text.isEmpty) {
      return '';
    }
    
    String name = _empNameController.text.toUpperCase();
    String firstFourLetters = name.replaceAll(' ', '').substring(0, 4);
    
    DateTime birthDate = DateFormat('dd/MM/yyyy').parse(_birthDateController.text);
    String year = birthDate.year.toString();
    
    return '$firstFourLetters@$year';
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
      setState(() {});
    }
  }

  void _nextSection() {
    if (_currentSection < _totalSections - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousSection() {
    if (_currentSection > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
@override
void initState() {
  super.initState();
  _loadDropdownData();
  _checkPermissionVisibility();
  // Only set default status if it exists in the loaded statuses and current value is null
    if (_selectedStatus == null && _statuses.contains('Active')) {
      _selectedStatus = 'Active';
    }
  }

  Future<void> _saveEmployee() async {
  if (!_formKey.currentState!.validate()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all required fields')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    String password = _generatePassword();
    String email = _emailController.text.trim();

    // Create user in Firebase Auth
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    // Prepare employee data
    Map<String, dynamic> employeeData = {
      'uid': userCredential.user!.uid,
      'title': _selectedTitle,
      'empName': _empNameController.text.trim(),
      'empCode': _empCodeController.text.trim(),
      'email': email,
      'grade': _selectedGrade,
      'branch': _selectedBranch,
      'department': _selectedDepartment,
      'designation': _selectedDesignation,
      'gender': _selectedGender,
      'status': _selectedStatus,
      'birthDate': _birthDateController.text,
      'joinDate': _joinDateController.text,
      'lastWorkingDate': _lastWorkingDateController.text,
      'resignOfferDate': _resignOfferDateController.text,
      'lastIncrementDate': _lastIncrementDateController.text,
      'probationDate': _probationDateController.text,
      'serviceMonth': _serviceMonthController.text,
      'paymentMode': _selectedPaymentMode,
      'bankDetails': {
        'ifscCode': _ifscCodeController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'branch': _bankBranchController.text.trim(),
      },
      'aadharNumber': _aadharController.text.trim(),
      'panNumber': _panController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Add permission field if user is Admin
    if (_showPermissionField && _selectedPermission != null) {
      employeeData['permission'] = _selectedPermission;
    }

    // Save to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set(employeeData);

    if (!mounted) return;

    // Show success dialog
    _showCreateAnotherDialog();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating employee: $e')),
      );
    }
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
void _showCreateAnotherDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Employee Created'),
        content: const Text('Do you want to create another employee?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Yes'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showLoginAgainDialog();
            },
            child: const Text('No'),
          ),
        ],
      );
    },
  );
}

void _showLoginAgainDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please log in again to continue.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void _resetForm() {
  _formKey.currentState?.reset();
  _empNameController.clear();
  _empCodeController.clear();
  _emailController.clear();
  _birthDateController.clear();
  _joinDateController.clear();
  _lastWorkingDateController.clear();
  _resignOfferDateController.clear();
  _lastIncrementDateController.clear();
  _probationDateController.clear();
  _serviceMonthController.clear();
  _ifscCodeController.clear();
  _bankNameController.clear();
  _accountNumberController.clear();
  _bankBranchController.clear();
  _aadharController.clear();
  _panController.clear();

  setState(() {
    _selectedTitle = 'Mr';
    _selectedGrade = null;
    _selectedBranch = null;
    _selectedDepartment = null;
    _selectedDesignation = null;
    _selectedGender = null;
    _selectedStatus = 'Active';
    _selectedPaymentMode = null;
    _currentSection = 0;
  });

  _pageController.jumpToPage(0);
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Employee'),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Section ${_currentSection + 1} of $_totalSections',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentSection + 1) / _totalSections,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                ),
              ],
            ),
          ),
          
          // Form Sections
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentSection = index;
                  });
                },
                children: [
                  _buildBasicInfoSection(),
                  _buildWorkDetailsSection(),
                  _buildDatesSection(),
                  _buildPaymentSection(),
                  _buildDocumentsSection(),
                ],
              ),
            ),
          ),
          
          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentSection > 0)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _previousSection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentSection > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_currentSection == _totalSections - 1
                            ? _saveEmployee
                            : _nextSection),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_currentSection == _totalSections - 1
                            ? 'Save Employee'
                            : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              SizedBox(
                width: 80,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedTitle,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  items: _titles.map((title) {
                    return DropdownMenuItem(value: title, child: Text(title));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTitle = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _empNameController,
                  decoration: const InputDecoration(
                    labelText: 'Employee Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value?.isEmpty == true ? 'Name is required' : null,
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _empCodeController,
            decoration: const InputDecoration(
              labelText: 'Employee Code *',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.isEmpty == true ? 'Employee code is required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty == true) return 'Email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                return 'Enter valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedGrade,
            decoration: const InputDecoration(
              labelText: 'Grade *',
              border: OutlineInputBorder(),
            ),
            items: _grades.map((grade) {
              return DropdownMenuItem(value: grade, child: Text(grade));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGrade = value;
              });
            },
            validator: (value) => value == null ? 'Grade is required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender *',
              border: OutlineInputBorder(),
            ),
            items: _genders.map((gender) {
              return DropdownMenuItem(value: gender, child: Text(gender));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
            validator: (value) => value == null ? 'Gender is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkDetailsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Work Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<String>(
            value: _selectedBranch,
            decoration: const InputDecoration(
              labelText: 'Branch *',
              border: OutlineInputBorder(),
            ),
            items: _branches.map((branch) {
              return DropdownMenuItem(value: branch, child: Text(branch));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBranch = value;
              });
            },
            validator: (value) => value == null ? 'Branch is required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedDepartment,
            decoration: const InputDecoration(
              labelText: 'Department *',
              border: OutlineInputBorder(),
            ),
            items: _departments.map((dept) {
              return DropdownMenuItem(value: dept, child: Text(dept));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDepartment = value;
              });
            },
            validator: (value) => value == null ? 'Department is required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedDesignation,
            decoration: const InputDecoration(
              labelText: 'Designation *',
              border: OutlineInputBorder(),
            ),
            items: _designations.map((designation) {
              return DropdownMenuItem(value: designation, child: Text(designation));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDesignation = value;
              });
            },
            validator: (value) => value == null ? 'Designation is required' : null,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status *',
              border: OutlineInputBorder(),
            ),
            items: _statuses.map((status) {
              return DropdownMenuItem(value: status, child: Text(status));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value;
              });
            },
            validator: (value) => value == null ? 'Status is required' : null,
          ),
          const SizedBox(height: 16),
          // Permission field - only visible when department and designation are both Admin
        if (_showPermissionField) ...[
          DropdownButtonFormField<String>(
            value: _selectedPermission,
            decoration: const InputDecoration(
              labelText: 'Permission *',
              border: OutlineInputBorder(),
            ),
            items: _permissions.map((permission) {
              return DropdownMenuItem(value: permission, child: Text(permission));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPermission = value;
              });
            },
            validator: (value) => value == null ? 'Permission is required for Admin' : null,
          ),
          const SizedBox(height: 16),
        ],
  ]
        ),
    );
  }

  Widget _buildDatesSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Important Dates',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          TextFormField(
            controller: _birthDateController,
            decoration: const InputDecoration(
              labelText: 'Birth Date *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(_birthDateController),
            validator: (value) =>
                value?.isEmpty == true ? 'Birth date is required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _joinDateController,
            decoration: const InputDecoration(
              labelText: 'Join Date *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(_joinDateController),
            validator: (value) =>
                value?.isEmpty == true ? 'Join date is required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _lastWorkingDateController,
            decoration: const InputDecoration(
              labelText: 'Last Working Date',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(_lastWorkingDateController),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _resignOfferDateController,
            decoration: const InputDecoration(
              labelText: 'Resign Offer Date',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(_resignOfferDateController),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _lastIncrementDateController,
            decoration: const InputDecoration(
              labelText: 'Last Increment Date',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(_lastIncrementDateController),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _probationDateController,
            decoration: const InputDecoration(
              labelText: 'Probation Date',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(_probationDateController),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _serviceMonthController,
            decoration: const InputDecoration(
              labelText: 'Service Months',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment & Bank Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<String>(
            value: _selectedPaymentMode,
            decoration: const InputDecoration(
              labelText: 'Payment Mode *',
              border: OutlineInputBorder(),
            ),
            items: _paymentModes.map((mode) {
              return DropdownMenuItem(value: mode, child: Text(mode));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPaymentMode = value;
              });
            },
            validator: (value) => value == null ? 'Payment mode is required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _ifscCodeController,
            decoration: const InputDecoration(
              labelText: 'IFSC Code *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) =>
                value?.isEmpty == true ? 'IFSC code is required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _bankNameController,
            decoration: const InputDecoration(
              labelText: 'Bank Name *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                value?.isEmpty == true ? 'Bank name is required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _accountNumberController,
            decoration: const InputDecoration(
              labelText: 'Account Number *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) =>
                value?.isEmpty == true ? 'Account number is required' : null,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _bankBranchController,
            decoration: const InputDecoration(
              labelText: 'Bank Branch *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                value?.isEmpty == true ? 'Bank branch is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          TextFormField(
            controller: _aadharController,
            decoration: const InputDecoration(
              labelText: 'Aadhar Number *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            validator: (value) {
              if (value?.isEmpty == true) return 'Aadhar number is required';
              if (value?.length != 12) return 'Aadhar must be 12 digits';
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _panController,
            decoration: const InputDecoration(
              labelText: 'PAN Number *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(10),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            ],
            validator: (value) {
              if (value?.isEmpty == true) return 'PAN number is required';
              if (value?.length != 10) return 'PAN must be 10 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Password Preview
          if (_empNameController.text.isNotEmpty && _birthDateController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generated Password:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _generatePassword(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Password format: First 4 letters of name + @ + birth year',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}