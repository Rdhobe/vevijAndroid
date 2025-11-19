import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:vevij/components/imports.dart';

class AdminSalaryManagementPage extends StatefulWidget {
  const AdminSalaryManagementPage({super.key});

  @override
  State<AdminSalaryManagementPage> createState() => _AdminSalaryManagementPageState();
}

class _AdminSalaryManagementPageState extends State<AdminSalaryManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Data state
  List<SalaryRecord> _salaryRecords = [];
  List<Employee> _employees = [];
  List<EmployeeSalaryConfig> _employeeConfigs = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // UI state
  String _searchQuery = '';
  Employee? _selectedEmployee;
  SalaryRecord? _selectedSalaryRecord;
  bool _showConfigPanel = false;

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _baseSalaryController = TextEditingController();
  final TextEditingController _daysPerMonthController = TextEditingController(text: '31');
  final TextEditingController _presentDaysController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Allowances Controllers
  final TextEditingController _foodAllowanceController = TextEditingController();
  final TextEditingController _petrolAllowanceController = TextEditingController();
  final TextEditingController _travelAllowanceController = TextEditingController();
  final TextEditingController _specialAllowanceController = TextEditingController();
  final TextEditingController _rentAllowanceController = TextEditingController();
  final TextEditingController _overtimeAllowanceController = TextEditingController();

  // Deductions Controllers
  final TextEditingController _tdsController = TextEditingController();
  final TextEditingController _pfController = TextEditingController();
  final TextEditingController _ptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _baseSalaryController.dispose();
    _daysPerMonthController.dispose();
    _presentDaysController.dispose();
    _remarksController.dispose();
    _foodAllowanceController.dispose();
    _petrolAllowanceController.dispose();
    _travelAllowanceController.dispose();
    _specialAllowanceController.dispose();
    _rentAllowanceController.dispose();
    _overtimeAllowanceController.dispose();
    _tdsController.dispose();
    _pfController.dispose();
    _ptController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadEmployees(),
        _loadEmployeeConfigs(),
        _loadSalaryRecords(),
      ]);
    } catch (e) {
      _showError('Failed to load data: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadEmployees() async {
    final snapshot = await _firestore.collection('users').get();
    setState(() {
      _employees = snapshot.docs
          .map((doc) => Employee.fromMap(doc.data()))
          .toList();
    });
  }

  Future<void> _loadEmployeeConfigs() async {
    final snapshot = await _firestore.collection('employee_salary_configs').get();
    setState(() {
      _employeeConfigs = snapshot.docs
          .map((doc) => EmployeeSalaryConfig.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> _loadSalaryRecords() async {
    final snapshot = await _firestore
        .collection('salary_records')
        .where('month', isEqualTo: _selectedMonth)
        .where('year', isEqualTo: _selectedYear)
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _salaryRecords = snapshot.docs
          .map((doc) => SalaryRecord.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  List<Employee> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    return _employees.where((employee) =>
        employee.empName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        employee.empCode.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  EmployeeSalaryConfig? _getEmployeeConfig(String employeeId) {
    try {
      return _employeeConfigs.firstWhere(
        (config) => config.employeeId == employeeId,
      );
    } catch (e) {
      return EmployeeSalaryConfig(
        id: '',
        employeeId: employeeId,
        baseSalary: 0,
        daysPerMonth: 31,
        foodAllowance: 0,
        petrolAllowance: 0,
        travelAllowance: 0,
        specialAllowance: 0,
        rentAllowance: 0,
        overtimeAllowance: 0,
        tds: 0,
        pf: 0,
        pt: 0,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Salary Management',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.indigo),
            onPressed: _showMonthYearPicker,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : isTablet ? _buildTabletLayout() : _buildMobileLayout(),
    );
  }

  void _showMonthYearPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Period',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...List.generate(6, (index) {
                final date = DateTime(
                  DateTime.now().year,
                  DateTime.now().month - index,
                );
                final isSelected = date.month == _selectedMonth && 
                                  date.year == _selectedYear;
                
                return ListTile(
                  leading: Icon(
                    Icons.calendar_month,
                    color: isSelected ? Colors.indigo : Colors.grey,
                  ),
                  title: Text(
                    DateFormat('MMMM yyyy').format(date),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.indigo : Colors.black87,
                    ),
                  ),
                  trailing: isSelected 
                      ? Icon(Icons.check_circle, color: Colors.indigo)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedMonth = date.month;
                      _selectedYear = date.year;
                    });
                    _loadSalaryRecords();
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        // Left Panel - Employee List
        SizedBox(
          width: 380,
          child: _buildEmployeeListView(),
        ),
        
        // Right Panel - Details
        Expanded(
          child: _buildDetailsPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedEmployee != null && (_showConfigPanel || _selectedSalaryRecord != null)) {
      return _buildDetailsPanel();
    }
    return _buildEmployeeListView();
  }

  Widget _buildEmployeeListView() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Period Chip
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.calendar_today, size: 16, color: Colors.indigo),
                label: Text(
                  DateFormat('MMMM yyyy').format(
                    DateTime(_selectedYear, _selectedMonth),
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
                backgroundColor: Colors.indigo[50],
              ),
            ),
          ),

          // Employee List
          Expanded(
            child: _filteredEmployees.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredEmployees.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildEmployeeCard(_filteredEmployees[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee) {
    final salaryRecord = _salaryRecords.firstWhere(
      (record) => record.userId == employee.uid,
      orElse: () => SalaryRecord.empty(),
    );
    final isSelected = _selectedEmployee?.uid == employee.uid;
    final hasSalaryRecord = salaryRecord.id.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedEmployee = employee;
            _selectedSalaryRecord = hasSalaryRecord ? salaryRecord : null;
            _showConfigPanel = !hasSalaryRecord;
            if (hasSalaryRecord) {
              _loadSalaryRecordDetails(salaryRecord);
            } else {
              _loadEmployeeConfig(employee);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: isSelected ? Colors.indigo : Colors.grey[300],
                child: Text(
                  employee.empName.isNotEmpty ? employee.empName[0].toUpperCase() : 'E',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
              
              SizedBox(width: 16),
              
              // Employee Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.empName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ID: ${employee.empCode}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (hasSalaryRecord) ...[
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Rs.${salaryRecord.netSalary.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Status Icon
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasSalaryRecord 
                      ? Colors.green[50] 
                      : Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasSalaryRecord ? Icons.check_circle : Icons.pending,
                  color: hasSalaryRecord ? Colors.green : Colors.orange,
                  size: 20,
                ),
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
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No employees found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your search',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    if (_selectedEmployee == null) {
      return _buildEmptySelectionState();
    }

    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: !isTablet
          ? AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _selectedEmployee = null;
                    _selectedSalaryRecord = null;
                    _showConfigPanel = false;
                    _clearForm();
                  });
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedEmployee!.empName,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'ID: ${_selectedEmployee!.empCode}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: _showConfigPanel 
          ? _buildSalaryConfigPanel() 
          : _buildSalaryDetailsPanel(),
    );
  }

  Widget _buildSalaryConfigPanel() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure Salary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM yyyy').format(
                      DateTime(_selectedYear, _selectedMonth),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Basic Information
          _buildConfigSection(
            'Basic Information',
            Icons.info_outline,
            [
              _buildConfigField(
                'Base Salary (Rs.)',
                _baseSalaryController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.baseSalary.toString(),
              ),
              _buildConfigField(
                'Days in Month',
                _daysPerMonthController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.daysPerMonth.toString(),
              ),
              _buildConfigField(
                'Present Days',
                _presentDaysController,
                hint: 'Enter present days for this month',
              ),
            ],
          ),

          SizedBox(height: 16),

          // Allowances
          _buildConfigSection(
            'Allowances',
            Icons.add_circle_outline,
            [
              _buildConfigField(
                'Food Allowance (Rs.)',
                _foodAllowanceController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.foodAllowance.toString(),
              ),
              _buildConfigField(
                'Petrol Allowance (Rs.)',
                _petrolAllowanceController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.petrolAllowance.toString(),
              ),
              _buildConfigField(
                'Travel Allowance (Rs.)',
                _travelAllowanceController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.travelAllowance.toString(),
              ),
              _buildConfigField(
                'Special Allowance (Rs.)',
                _specialAllowanceController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.specialAllowance.toString(),
              ),
              _buildConfigField(
                'Rent Allowance (Rs.)',
                _rentAllowanceController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.rentAllowance.toString(),
              ),
              _buildConfigField(
                'Overtime/Sunday (Rs.)',
                _overtimeAllowanceController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.overtimeAllowance.toString(),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Deductions
          _buildConfigSection(
            'Deductions',
            Icons.remove_circle_outline,
            [
              _buildConfigField(
                'TDS (Rs.)',
                _tdsController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.tds.toString(),
              ),
              _buildConfigField(
                'Provident Fund (Rs.)',
                _pfController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.pf.toString(),
              ),
              _buildConfigField(
                'Professional Tax (Rs.)',
                _ptController,
                value: _getEmployeeConfig(_selectedEmployee!.uid)?.pt.toString(),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Remarks
          _buildConfigSection(
            'Remarks',
            Icons.note_outlined,
            [
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any remarks for this salary record...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.indigo, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Salary Preview
          _buildSalaryPreview(),

          SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _clearForm();
                    setState(() {
                      _showConfigPanel = false;
                      if (MediaQuery.of(context).size.width <= 600) {
                        _selectedEmployee = null;
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saveSalaryRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Salary Record',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildConfigSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children.map((child) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: child,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigField(
    String label,
    TextEditingController controller, {
    String? value,
    String? hint,
  }) {
    if (value != null && controller.text.isEmpty) {
      controller.text = value;
    }

    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.indigo, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSalaryPreview() {
    final baseSalary = double.tryParse(_baseSalaryController.text) ?? 0;
    final daysPerMonth = int.tryParse(_daysPerMonthController.text) ?? 31;
    final presentDays = int.tryParse(_presentDaysController.text) ?? 0;
    
    final foodAllowance = double.tryParse(_foodAllowanceController.text) ?? 0;
    final petrolAllowance = double.tryParse(_petrolAllowanceController.text) ?? 0;
    final travelAllowance = double.tryParse(_travelAllowanceController.text) ?? 0;
    final specialAllowance = double.tryParse(_specialAllowanceController.text) ?? 0;
    final rentAllowance = double.tryParse(_rentAllowanceController.text) ?? 0;
    final overtimeAllowance = double.tryParse(_overtimeAllowanceController.text) ?? 0;
    
    final tds = double.tryParse(_tdsController.text) ?? 0;
    final pf = double.tryParse(_pfController.text) ?? 0;
    final pt = double.tryParse(_ptController.text) ?? 0;

    final perDaySalary = daysPerMonth > 0 ? baseSalary / daysPerMonth : 0;
    final salaryAsPerPresent = perDaySalary * presentDays;
    final totalAllowances = foodAllowance + petrolAllowance + travelAllowance + 
                           specialAllowance + rentAllowance + overtimeAllowance;
    final grossSalary = salaryAsPerPresent + totalAllowances;
    final totalDeductions = tds + pf + pt;
    final netSalary = grossSalary - totalDeductions;

    return Card(
      elevation: 3,
      color: Colors.indigo[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, size: 20, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Salary Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[900],
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: Colors.indigo[200]),
            _buildPreviewRow('Per Day Salary', 'Rs.${perDaySalary.toStringAsFixed(2)}'),
            _buildPreviewRow('Salary as per Present', 'Rs.${salaryAsPerPresent.toStringAsFixed(0)}'),
            _buildPreviewRow('Total Allowances', 'Rs.${totalAllowances.toStringAsFixed(0)}', Colors.green[700]),
            _buildPreviewRow('Gross Salary', 'Rs.${grossSalary.toStringAsFixed(0)}', Colors.green[700], true),
            _buildPreviewRow('Total Deductions', 'Rs.${totalDeductions.toStringAsFixed(0)}', Colors.red[700]),
            Divider(height: 24, color: Colors.indigo[200]),
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NET SALARY',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Rs.${netSalary.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, [Color? color, bool isBold = false]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryDetailsPanel() {
    if (_selectedSalaryRecord == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No Salary Record',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Configure salary for this employee',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final record = _selectedSalaryRecord!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Net Salary
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.indigo[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Salary',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Rs.${record.netSalary.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM yyyy').format(
                      DateTime(record.year, record.month),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Salary Breakdown
          _buildDetailSection(
            'Salary Breakdown',
            Icons.account_balance_wallet_outlined,
            [
              _buildDetailRow('Base Salary', 'Rs.${record.baseSalary.toStringAsFixed(0)}'),
              _buildDetailRow('Days in Month', '${record.daysPerMonth}'),
              _buildDetailRow('Per Day Salary', 'Rs.${record.perDaySalary.toStringAsFixed(2)}'),
              _buildDetailRow('Present Days', '${record.presentDays}', Colors.blue[700]),
              Divider(),
              _buildDetailRow('Salary as per Present', 'Rs.${record.salaryAsPerPresent.toStringAsFixed(0)}', Colors.blue[700], true),
            ],
          ),

          SizedBox(height: 16),

          // Allowances
          _buildDetailSection(
            'Allowances',
            Icons.add_circle_outline,
            [
              _buildDetailRow('Food Allowance', 'Rs.${record.foodAllowance.toStringAsFixed(0)}', Colors.green[700]),
              _buildDetailRow('Petrol Allowance', 'Rs.${record.petrolAllowance.toStringAsFixed(0)}', Colors.green[700]),
              _buildDetailRow('Travel Allowance', 'Rs.${record.travelAllowance.toStringAsFixed(0)}', Colors.green[700]),
              _buildDetailRow('Special Allowance', 'Rs.${record.specialAllowance.toStringAsFixed(0)}', Colors.green[700]),
              _buildDetailRow('Rent Allowance', 'Rs.${record.rentAllowance.toStringAsFixed(0)}', Colors.green[700]),
              _buildDetailRow('Overtime/Sunday', 'Rs.${record.overtimeAllowance.toStringAsFixed(0)}', Colors.green[700]),
              Divider(),
              _buildDetailRow('Total Allowances', 'Rs.${record.totalAllowances.toStringAsFixed(0)}', Colors.green[700], true),
            ],
          ),

          SizedBox(height: 16),

          // Gross Salary
          Card(
            elevation: 2,
            color: Colors.green[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.green[700]),
                      SizedBox(width: 8),
                      Text(
                        'Gross Salary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rs.${record.grossSalary.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Deductions
          _buildDetailSection(
            'Deductions',
            Icons.remove_circle_outline,
            [
              _buildDetailRow('TDS', 'Rs.${record.tds.toStringAsFixed(0)}', Colors.red[700]),
              _buildDetailRow('Provident Fund', 'Rs.${record.pf.toStringAsFixed(0)}', Colors.red[700]),
              _buildDetailRow('Professional Tax', 'Rs.${record.pt.toStringAsFixed(0)}', Colors.red[700]),
              Divider(),
              _buildDetailRow('Total Deductions', 'Rs.${record.totalDeductions.toStringAsFixed(0)}', Colors.red[700], true),
            ],
          ),

          if (record.remarks.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildDetailSection(
              'Remarks',
              Icons.note_outlined,
              [
                Text(
                  record.remarks,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _editSalaryRecord(record),
                  icon: Icon(Icons.edit, size: 20),
                  label: Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _generateAndDownloadSlip(record),
                  icon: Icon(Icons.download, size: 20),
                  label: Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? color, bool isBold = false]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySelectionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 100, color: Colors.grey[300]),
          SizedBox(height: 24),
          Text(
            'Select an Employee',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Choose an employee from the list to configure or view salary details',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Core Functions
  void _loadEmployeeConfig(Employee employee) {
    final config = _getEmployeeConfig(employee.uid);
    if (config != null) {
      _baseSalaryController.text = config.baseSalary?.toStringAsFixed(0) ?? '0';
      _daysPerMonthController.text = config.daysPerMonth.toString();
      
      _foodAllowanceController.text = config.foodAllowance?.toStringAsFixed(0) ?? '0';
      _petrolAllowanceController.text = config.petrolAllowance?.toStringAsFixed(0) ?? '0';
      _travelAllowanceController.text = config.travelAllowance?.toStringAsFixed(0) ?? '0';
      _specialAllowanceController.text = config.specialAllowance?.toStringAsFixed(0) ?? '0';
      _rentAllowanceController.text = config.rentAllowance?.toStringAsFixed(0) ?? '0';
      _overtimeAllowanceController.text = config.overtimeAllowance?.toStringAsFixed(0) ?? '0';
      
      _tdsController.text = config.tds?.toStringAsFixed(0) ?? '0';
      _pfController.text = config.pf?.toStringAsFixed(0) ?? '0';
      _ptController.text = config.pt?.toStringAsFixed(0) ?? '0';
    }
    
    _presentDaysController.clear();
    _remarksController.clear();
  }

  void _loadSalaryRecordDetails(SalaryRecord record) {
    _baseSalaryController.text = record.baseSalary.toStringAsFixed(0);
    _daysPerMonthController.text = record.daysPerMonth.toString();
    
    _foodAllowanceController.text = record.foodAllowance.toStringAsFixed(0);
    _petrolAllowanceController.text = record.petrolAllowance.toStringAsFixed(0);
    _travelAllowanceController.text = record.travelAllowance.toStringAsFixed(0);
    _specialAllowanceController.text = record.specialAllowance.toStringAsFixed(0);
    _rentAllowanceController.text = record.rentAllowance.toStringAsFixed(0);
    _overtimeAllowanceController.text = record.overtimeAllowance.toStringAsFixed(0);
    
    _tdsController.text = record.tds.toStringAsFixed(0);
    _pfController.text = record.pf.toStringAsFixed(0);
    _ptController.text = record.pt.toStringAsFixed(0);
    
    _presentDaysController.text = record.presentDays.toString();
    _remarksController.text = record.remarks;
  }

  Future<void> _saveSalaryRecord() async {
    if (_selectedEmployee == null) return;

    try {
      final baseSalary = double.tryParse(_baseSalaryController.text) ?? 0;
      final daysPerMonth = int.tryParse(_daysPerMonthController.text) ?? 31;
      final presentDays = int.tryParse(_presentDaysController.text) ?? 0;
      
      final foodAllowance = double.tryParse(_foodAllowanceController.text) ?? 0;
      final petrolAllowance = double.tryParse(_petrolAllowanceController.text) ?? 0;
      final travelAllowance = double.tryParse(_travelAllowanceController.text) ?? 0;
      final specialAllowance = double.tryParse(_specialAllowanceController.text) ?? 0;
      final rentAllowance = double.tryParse(_rentAllowanceController.text) ?? 0;
      final overtimeAllowance = double.tryParse(_overtimeAllowanceController.text) ?? 0;
      
      final tds = double.tryParse(_tdsController.text) ?? 0;
      final pf = double.tryParse(_pfController.text) ?? 0;
      final pt = double.tryParse(_ptController.text) ?? 0;
      
      final remarks = _remarksController.text;

      final perDaySalary = baseSalary / daysPerMonth;
      final salaryAsPerPresent = perDaySalary * presentDays;
      final totalAllowances = foodAllowance + petrolAllowance + travelAllowance + 
                             specialAllowance + rentAllowance + overtimeAllowance;
      final grossSalary = salaryAsPerPresent + totalAllowances;
      final totalDeductions = tds + pf + pt;
      final netSalary = grossSalary - totalDeductions;

      final salaryRecord = SalaryRecord(
        id: _selectedSalaryRecord?.id ?? '',
        userId: _selectedEmployee!.uid,
        employeeName: _selectedEmployee!.empName,
        employeeCode: _selectedEmployee!.empCode,
        month: _selectedMonth,
        year: _selectedYear,
        baseSalary: baseSalary,
        daysPerMonth: daysPerMonth,
        perDaySalary: perDaySalary,
        presentDays: presentDays,
        salaryAsPerPresent: salaryAsPerPresent,
        foodAllowance: foodAllowance,
        petrolAllowance: petrolAllowance,
        travelAllowance: travelAllowance,
        specialAllowance: specialAllowance,
        rentAllowance: rentAllowance,
        overtimeAllowance: overtimeAllowance,
        totalAllowances: totalAllowances,
        grossSalary: grossSalary,
        tds: tds,
        pf: pf,
        pt: pt,
        totalDeductions: totalDeductions,
        netSalary: netSalary,
        remarks: remarks,
        createdAt: _selectedSalaryRecord?.createdAt ?? Timestamp.now(),
      );

      if (_selectedSalaryRecord?.id != null && _selectedSalaryRecord!.id.isNotEmpty) {
        await _firestore.collection('salary_records').doc(_selectedSalaryRecord!.id).update(salaryRecord.toMap());
      } else {
        await _firestore.collection('salary_records').add(salaryRecord.toMap());
      }

      _showSuccess('Salary saved for ${_selectedEmployee!.empName}');
      _clearForm();
      await _loadSalaryRecords();
      
      setState(() {
        _showConfigPanel = false;
        _selectedSalaryRecord = salaryRecord;
      });

    } catch (e) {
      _showError('Failed to save salary: $e');
    }
  }

  Future<void> _generateAndDownloadSlip(SalaryRecord record) async {
    try {
      setState(() => _isLoading = true);
      
      final pdf = await _generateSalarySlipPdf(record);
      
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/salary_slip_${record.employeeCode}_${record.month}_${record.year}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Salary Slip - ${record.employeeName}',
        text: 'Salary slip for ${DateFormat('MMMM yyyy').format(DateTime(record.year, record.month))}',
      );

      _showSuccess('Salary slip generated successfully');
      
    } catch (e) {
      _showError('Failed to generate salary slip: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<pw.Document> _generateSalarySlipPdf(SalaryRecord record) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SALARY SLIP', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Employee: ${record.employeeName}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Employee ID: ${record.employeeCode}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Period: ${DateFormat('MMMM yyyy').format(DateTime(record.year, record.month))}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10)),
                  pw.Divider(),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            pw.Text('EARNINGS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Amount (Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                _buildPdfTableRow('Basic Salary', record.baseSalary),
                _buildPdfTableRow('Present Days', record.presentDays.toDouble(), isAmount: false),
                _buildPdfTableRow('Per Day Salary', record.perDaySalary),
                _buildPdfTableRow('Salary as per Present', record.salaryAsPerPresent),
                _buildPdfTableRow('Food Allowance', record.foodAllowance),
                _buildPdfTableRow('Petrol Allowance', record.petrolAllowance),
                _buildPdfTableRow('Travel Allowance', record.travelAllowance),
                _buildPdfTableRow('Special Allowance', record.specialAllowance),
                _buildPdfTableRow('Rent Allowance', record.rentAllowance),
                _buildPdfTableRow('Overtime/Sunday', record.overtimeAllowance),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Total Earnings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Rs.${record.grossSalary.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            pw.Text('DEDUCTIONS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Amount (Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                _buildPdfTableRow('TDS', record.tds),
                _buildPdfTableRow('Provident Fund', record.pf),
                _buildPdfTableRow('Professional Tax', record.pt),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Total Deductions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Rs.${record.totalDeductions.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                color: PdfColors.blue50,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET SALARY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs.${record.netSalary.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                ],
              ),
            ),
            
            if (record.remarks.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Remarks:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(record.remarks),
            ],
          ];
        },
      ),
    );
    
    return pdf;
  }

  pw.TableRow _buildPdfTableRow(String label, double value, {bool isAmount = true}) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(label)),
        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(isAmount ? 'Rs.${value.toStringAsFixed(0)}' : value.toStringAsFixed(0))),
      ],
    );
  }

  Future<void> _editSalaryRecord(SalaryRecord record) async {
    setState(() {
      _showConfigPanel = true;
      _loadSalaryRecordDetails(record);
    });
  }

  void _clearForm() {
    _baseSalaryController.clear();
    _daysPerMonthController.text = '31';
    _presentDaysController.clear();
    _remarksController.clear();
    
    _foodAllowanceController.clear();
    _petrolAllowanceController.clear();
    _travelAllowanceController.clear();
    _specialAllowanceController.clear();
    _rentAllowanceController.clear();
    _overtimeAllowanceController.clear();
    
    _tdsController.clear();
    _pfController.clear();
    _ptController.clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Data Models (keep existing models from your original code)
class EmployeeSalaryConfig {
  final String id;
  final String employeeId;
  final double? baseSalary;
  final int daysPerMonth;
  final double? foodAllowance;
  final double? petrolAllowance;
  final double? travelAllowance;
  final double? specialAllowance;
  final double? rentAllowance;
  final double? overtimeAllowance;
  final double? tds;
  final double? pf;
  final double? pt;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  EmployeeSalaryConfig({
    required this.id,
    required this.employeeId,
    required this.baseSalary,
    required this.daysPerMonth,
    required this.foodAllowance,
    required this.petrolAllowance,
    required this.travelAllowance,
    required this.specialAllowance,
    required this.rentAllowance,
    required this.overtimeAllowance,
    required this.tds,
    required this.pf,
    required this.pt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'baseSalary': baseSalary,
      'daysPerMonth': daysPerMonth,
      'foodAllowance': foodAllowance,
      'petrolAllowance': petrolAllowance,
      'travelAllowance': travelAllowance,
      'specialAllowance': specialAllowance,
      'rentAllowance': rentAllowance,
      'overtimeAllowance': overtimeAllowance,
      'tds': tds,
      'pf': pf,
      'pt': pt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory EmployeeSalaryConfig.fromMap(String id, Map<String, dynamic> map) {
    return EmployeeSalaryConfig(
      id: id,
      employeeId: map['employeeId'] as String,
      baseSalary: (map['baseSalary'] as num?)?.toDouble() ?? 0,
      daysPerMonth: (map['daysPerMonth'] as num?)?.toInt() ?? 31,
      foodAllowance: (map['foodAllowance'] as num?)?.toDouble() ?? 0,
      petrolAllowance: (map['petrolAllowance'] as num?)?.toDouble() ?? 0,
      travelAllowance: (map['travelAllowance'] as num?)?.toDouble() ?? 0,
      specialAllowance: (map['specialAllowance'] as num?)?.toDouble() ?? 0,
      rentAllowance: (map['rentAllowance'] as num?)?.toDouble() ?? 0,
      overtimeAllowance: (map['overtimeAllowance'] as num?)?.toDouble() ?? 0,
      tds: (map['tds'] as num?)?.toDouble() ?? 0,
      pf: (map['pf'] as num?)?.toDouble() ?? 0,
      pt: (map['pt'] as num?)?.toDouble() ?? 0,
      createdAt: map['createdAt'] as Timestamp,
      updatedAt: map['updatedAt'] as Timestamp,
    );
  }
}

class SalaryRecord {
  final String id;
  final String userId;
  final String employeeName;
  final String employeeCode;
  final int month;
  final int year;
  final double baseSalary;
  final int daysPerMonth;
  final double perDaySalary;
  final int presentDays;
  final double salaryAsPerPresent;
  
  final double foodAllowance;
  final double petrolAllowance;
  final double travelAllowance;
  final double specialAllowance;
  final double rentAllowance;
  final double overtimeAllowance;
  final double totalAllowances;
  
  final double grossSalary;
  
  final double tds;
  final double pf;
  final double pt;
  final double totalDeductions;
  
  final double netSalary;
  final String remarks;
  final Timestamp createdAt;

  SalaryRecord({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.employeeCode,
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.daysPerMonth,
    required this.perDaySalary,
    required this.presentDays,
    required this.salaryAsPerPresent,
    required this.foodAllowance,
    required this.petrolAllowance,
    required this.travelAllowance,
    required this.specialAllowance,
    required this.rentAllowance,
    required this.overtimeAllowance,
    required this.totalAllowances,
    required this.grossSalary,
    required this.tds,
    required this.pf,
    required this.pt,
    required this.totalDeductions,
    required this.netSalary,
    required this.remarks,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'employeeName': employeeName,
      'employeeCode': employeeCode,
      'month': month,
      'year': year,
      'baseSalary': baseSalary,
      'daysPerMonth': daysPerMonth,
      'perDaySalary': perDaySalary,
      'presentDays': presentDays,
      'salaryAsPerPresent': salaryAsPerPresent,
      'foodAllowance': foodAllowance,
      'petrolAllowance': petrolAllowance,
      'travelAllowance': travelAllowance,
      'specialAllowance': specialAllowance,
      'rentAllowance': rentAllowance,
      'overtimeAllowance': overtimeAllowance,
      'totalAllowances': totalAllowances,
      'grossSalary': grossSalary,
      'tds': tds,
      'pf': pf,
      'pt': pt,
      'totalDeductions': totalDeductions,
      'netSalary': netSalary,
      'remarks': remarks,
      'createdAt': createdAt,
    };
  }

  factory SalaryRecord.fromMap(String id, Map<String, dynamic> map) {
    return SalaryRecord(
      id: id,
      userId: map['userId'] as String,
      employeeName: map['employeeName'] as String,
      employeeCode: map['employeeCode'] as String,
      month: (map['month'] as num).toInt(),
      year: (map['year'] as num).toInt(),
      baseSalary: (map['baseSalary'] as num).toDouble(),
      daysPerMonth: (map['daysPerMonth'] as num).toInt(),
      perDaySalary: (map['perDaySalary'] as num).toDouble(),
      presentDays: (map['presentDays'] as num).toInt(),
      salaryAsPerPresent: (map['salaryAsPerPresent'] as num).toDouble(),
      foodAllowance: (map['foodAllowance'] as num).toDouble(),
      petrolAllowance: (map['petrolAllowance'] as num).toDouble(),
      travelAllowance: (map['travelAllowance'] as num).toDouble(),
      specialAllowance: (map['specialAllowance'] as num).toDouble(),
      rentAllowance: (map['rentAllowance'] as num).toDouble(),
      overtimeAllowance: (map['overtimeAllowance'] as num).toDouble(),
      totalAllowances: (map['totalAllowances'] as num).toDouble(),
      grossSalary: (map['grossSalary'] as num).toDouble(),
      tds: (map['tds'] as num).toDouble(),
      pf: (map['pf'] as num).toDouble(),
      pt: (map['pt'] as num).toDouble(),
      totalDeductions: (map['totalDeductions'] as num).toDouble(),
      netSalary: (map['netSalary'] as num).toDouble(),
      remarks: map['remarks'] as String? ?? '',
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  static SalaryRecord empty() {
    return SalaryRecord(
      id: '',
      userId: '',
      employeeName: '',
      employeeCode: '',
      month: 0,
      year: 0,
      baseSalary: 0,
      daysPerMonth: 0,
      perDaySalary: 0,
      presentDays: 0,
      salaryAsPerPresent: 0,
      foodAllowance: 0,
      petrolAllowance: 0,
      travelAllowance: 0,
      specialAllowance: 0,
      rentAllowance: 0,
      overtimeAllowance: 0,
      totalAllowances: 0,
      grossSalary: 0,
      tds: 0,
      pf: 0,
      pt: 0,
      totalDeductions: 0,
      netSalary: 0,
      remarks: '',
      createdAt: Timestamp.now(),
    );
  }
}