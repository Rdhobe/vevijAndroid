import 'package:intl/intl.dart';
import 'package:vevij/components/imports.dart';

// Employee Requests Page
class EmployeeRequestsPage extends StatefulWidget {
  final String userId;
  final String userName;
  final Map<String, dynamic>? employeeData;

  const EmployeeRequestsPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.employeeData,
  });

  @override
  State<EmployeeRequestsPage> createState() => _EmployeeRequestsPageState();
}

class _EmployeeRequestsPageState extends State<EmployeeRequestsPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      MyRequestsTab(userId: widget.userId),
      LeaveRequestTab(userId: widget.userId, userName: widget.userName),
      ProfileUpdateRequestTab(
        userId: widget.userId,
        userName: widget.userName,
        employeeData: widget.employeeData,
      ),
      MisPunchRequestTab(userId: widget.userId, userName: widget.userName),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Requests',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Top Icon Buttons
          _buildTopButtons(),
          SizedBox(height: 8),
          // Current Page
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildTopButtons() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildIconButton(
            icon: Icons.list_alt_rounded,
            label: 'My Requests',
            index: 0,
            isSelected: _selectedIndex == 0,
          ),
          _buildIconButton(
            icon: Icons.event_note_rounded,
            label: 'Leave',
            index: 1,
            isSelected: _selectedIndex == 1,
          ),
          _buildIconButton(
            icon: Icons.person_rounded,
            label: 'Profile',
            index: 2,
            isSelected: _selectedIndex == 2,
          ),
          _buildIconButton(
            icon: Icons.fingerprint_rounded,
            label: 'Mis-Punch',
            index: 3,
            isSelected: _selectedIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppTheme.palePurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? AppTheme.primaryPurple : Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Leave Request Tab - Completely Restructured
class LeaveRequestTab extends StatefulWidget {
  final String userId;
  final String userName;

  const LeaveRequestTab({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<LeaveRequestTab> createState() => _LeaveRequestTabState();
}

class _LeaveRequestTabState extends State<LeaveRequestTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String selectedLeaveType = 'sick';
  String selectedSubType = 'full';
  int calculatedDuration = 0;
  bool isSubmitting = false;

  final List<Map<String, dynamic>> leaveTypes = [
    {'value': 'sick', 'label': 'Sick Leave', 'icon': Icons.healing, 'color': Color(0xFFEF4444)},
    {'value': 'casual', 'label': 'Casual Leave', 'icon': Icons.beach_access, 'color': Color(0xFF3B82F6)},
    {'value': 'emergency', 'label': 'Emergency Leave', 'icon': Icons.emergency, 'color': Color(0xFFF59E0B)},
    {'value': 'maternity', 'label': 'Maternity Leave', 'icon': Icons.family_restroom, 'color': Color(0xFFEC4899)},
    {'value': 'paternity', 'label': 'Paternity Leave', 'icon': Icons.people, 'color': Color(0xFF8B5CF6)},
    {'value': 'annual', 'label': 'Annual Leave', 'icon': Icons.work, 'color': Color(0xFF10B981)},
  ];

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _calculateDuration() {
    if (_startDateController.text.isNotEmpty && _endDateController.text.isNotEmpty) {
      try {
        DateTime startDate = DateFormat('dd/MM/yyyy').parse(_startDateController.text);
        DateTime endDate = DateFormat('dd/MM/yyyy').parse(_endDateController.text);
        
        int days = endDate.difference(startDate).inDays + 1;
        
        setState(() {
          calculatedDuration = selectedSubType == 'half' ? (days / 2).ceil() : days;
        });
      } catch (e) {
        setState(() {
          calculatedDuration = 0;
        });
      }
    }
  }

  Future<void> _selectDate(TextEditingController controller, {bool isStartDate = true}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
      _calculateDuration();
      
      if (isStartDate && _endDateController.text.isEmpty) {
        _endDateController.text = controller.text;
        _calculateDuration();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Leave Type Selection
                      _buildLeaveTypeSection(),
                      SizedBox(height: 16),
                      
                      // Duration Type
                      _buildDurationTypeSection(),
                      SizedBox(height: 16),
                      
                      // Date Selection
                      _buildDateSection(),
                      SizedBox(height: 16),
                      
                      // Duration Summary
                      if (calculatedDuration > 0) _buildDurationSummary(),
                      
                      // Reason
                      _buildReasonSection(),
                      SizedBox(height: 16),
                      
                      // Emergency Contact
                      _buildContactSection(),
                      SizedBox(height: 24),
                      
                      // Submit Button
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.event_note_rounded, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Apply for Leave',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(left: 44),
              child: Text(
                'Fill in the details below to submit your leave request',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, color: AppTheme.primaryPurple, size: 20),
              SizedBox(width: 8),
              Text(
                'Leave Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: leaveTypes.map((type) {
              final isSelected = selectedLeaveType == type['value'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedLeaveType = type['value'];
                  });
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 80) / 2,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? type['color'].withOpacity(0.1) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? type['color']! : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: type['color'],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(type['icon'], color: Colors.white, size: 18),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          type['label'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? type['color'] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationTypeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: AppTheme.primaryPurple, size: 20),
              SizedBox(width: 8),
              Text(
                'Duration Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDurationOption(
                  label: 'Full Day',
                  icon: Icons.all_inclusive_rounded,
                  isSelected: selectedSubType == 'full',
                  onTap: () {
                    setState(() {
                      selectedSubType = 'full';
                      _calculateDuration();
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDurationOption(
                  label: 'Half Day',
                  icon: Icons.hourglass_top_rounded,
                  isSelected: selectedSubType == 'half',
                  onTap: () {
                    setState(() {
                      selectedSubType = 'half';
                      _calculateDuration();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPurple : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryPurple : Colors.grey[600],
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryPurple : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: AppTheme.primaryPurple, size: 20),
              SizedBox(width: 8),
              Text(
                'Leave Dates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Column(
            children: [
              _buildDateField(
                controller: _startDateController,
                label: 'Start Date',
                onTap: () => _selectDate(_startDateController, isStartDate: true),
              ),
              SizedBox(height: 12),
              _buildDateField(
                controller: _endDateController,
                label: 'End Date',
                onTap: () => _selectDate(_endDateController, isStartDate: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: (value) => value?.isEmpty == true ? 'Required' : null,
      style: TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Container(
          width: 40,
          child: Icon(Icons.calendar_month_rounded, color: AppTheme.primaryPurple, size: 20),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDurationSummary() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.palePurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Leave Duration',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$calculatedDuration ${calculatedDuration == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, color: AppTheme.primaryPurple, size: 20),
              SizedBox(width: 8),
              Text(
                'Reason for Leave',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _reasonController,
            maxLines: 4,
            validator: (value) => value?.isEmpty == true ? 'Please provide a reason' : null,
            style: TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Enter reason *',
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              hintText: 'Please provide details about your leave...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
              ),
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_rounded, color: AppTheme.primaryPurple, size: 20),
              SizedBox(width: 8),
              Text(
                'Emergency Contact (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            style: TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Contact number',
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              hintText: 'Enter emergency contact number...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Container(
                width: 40,
                child: Icon(Icons.phone_iphone_rounded, color: AppTheme.primaryPurple, size: 20),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSubmitting ? null : _submitLeaveRequest,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isSubmitting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Submit Leave Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (calculatedDuration <= 0) {
      _showSnackBar('Please select valid dates', false);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('employeeRequests').add({
        'userId': widget.userId,
        'employeeName': widget.userName,
        'requestType': 'leave',
        'leaveType': selectedLeaveType,
        'subType': selectedSubType,
        'startDate': _startDateController.text,
        'endDate': _endDateController.text,
        'duration': calculatedDuration,
        'reason': _reasonController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'status': 'pending',
        'appliedDate': DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      _showSnackBar('Leave request submitted successfully!', true);
    } catch (e) {
      _showSnackBar('Error submitting request', false);
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _clearForm() {
    _startDateController.clear();
    _endDateController.clear();
    _reasonController.clear();
    _contactController.clear();
    setState(() {
      calculatedDuration = 0;
      selectedLeaveType = 'sick';
      selectedSubType = 'full';
    });
  }
}

// Profile Update Request Tab
class ProfileUpdateRequestTab extends StatefulWidget {
  final String userId;
  final String userName;
  final Map<String, dynamic>? employeeData;

  const ProfileUpdateRequestTab({
    super.key,
    required this.userId,
    required this.userName,
    required this.employeeData,
  });

  @override
  State<ProfileUpdateRequestTab> createState() => _ProfileUpdateRequestTabState();
}

class _ProfileUpdateRequestTabState extends State<ProfileUpdateRequestTab> {
  final _formKey = GlobalKey<FormState>();
  String selectedUpdateType = 'personal';
  Map<String, TextEditingController> controllers = {};
  bool isSubmitting = false;

  final List<Map<String, dynamic>> updateTypes = [
    {
      'value': 'personal',
      'label': 'Personal Information',
      'icon': Icons.person_rounded,
      'color': Color(0xFF8B5CF6),
      'fields': ['Phone Number', 'Email', 'Address', 'Emergency Contact', 'Emergency Contact Phone']
    },
    {
      'value': 'work',
      'label': 'Work Information',
      'icon': Icons.work_rounded,
      'color': Color(0xFF3B82F6),
      'fields': ['Department', 'Designation', 'Reporting Manager', 'Work Location', 'Shift Timing']
    },
    {
      'value': 'bank',
      'label': 'Bank Details',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF10B981),
      'fields': ['Bank Name', 'Account Number', 'IFSC Code', 'Account Holder Name', 'Branch']
    },
    {
      'value': 'documents',
      'label': 'Document Update',
      'icon': Icons.description_rounded,
      'color': Color(0xFFF59E0B),
      'fields': ['PAN Number', 'Aadhar Number', 'Passport Number', 'Driving License', 'Other Document']
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    controllers.clear();
    for (var type in updateTypes) {
      for (var field in type['fields']) {
        controllers[field] = TextEditingController();
      }
    }
    controllers['reason'] = TextEditingController();
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
    controller.dispose();
  }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var currentType = updateTypes.firstWhere((type) => type['value'] == selectedUpdateType);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              title: 'Update Profile',
              subtitle: 'Request changes to your personal, work, or bank information',
            ),
            SizedBox(height: 24),
            _buildCategorySelector(),
            SizedBox(height: 20),
            _buildUpdateFields(currentType),
            SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple.withOpacity(0.1), AppTheme.lightPurple.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: 40),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.category_rounded, color: AppTheme.primaryPurple, size: 18),
                ),
                SizedBox(width: 8),
                Text(
                  'Select Update Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: updateTypes.map((type) {
                final isSelected = selectedUpdateType == type['value'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedUpdateType = type['value'];
                      _clearCurrentFields();
                    });
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width / 2 - 30,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [type['color'].withOpacity(0.15), type['color'].withOpacity(0.05)],
                            )
                          : null,
                      color: isSelected ? null : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? type['color'] : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? type['color'] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            type['icon'],
                            color: isSelected ? Colors.white : Colors.grey[600],
                            size: 24,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          type['label'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? type['color'] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUpdateFields(Map<String, dynamic> currentType) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: currentType['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(currentType['icon'], color: currentType['color'], size: 18),
              ),
              SizedBox(width: 8),
              Text(
                currentType['label'],
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...currentType['fields'].map<Widget>((field) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildModernTextField(
                controller: controllers[field]!,
                label: field,
                icon: _getFieldIcon(field),
                keyboardType: _getKeyboardType(field),
              ),
            );
          }).toList(),
          SizedBox(height: 8),
          _buildModernTextField(
            controller: controllers['reason']!,
            label: 'Reason for Update *',
            icon: Icons.edit_note_rounded,
            maxLines: 3,
            validator: (value) => value?.isEmpty == true ? 'Reason is required' : null,
          ),
        ],
      ),
    );
  }

  IconData _getFieldIcon(String field) {
    if (field.toLowerCase().contains('phone')) return Icons.phone_rounded;
    if (field.toLowerCase().contains('email')) return Icons.email_rounded;
    if (field.toLowerCase().contains('address')) return Icons.location_on_rounded;
    if (field.toLowerCase().contains('department')) return Icons.business_rounded;
    if (field.toLowerCase().contains('bank')) return Icons.account_balance_rounded;
    if (field.toLowerCase().contains('account')) return Icons.account_circle_rounded;
    if (field.toLowerCase().contains('number')) return Icons.numbers_rounded;
    return Icons.text_fields_rounded;
  }

  TextInputType _getKeyboardType(String field) {
    if (field.toLowerCase().contains('phone') || field.toLowerCase().contains('number')) {
      return TextInputType.phone;
    }
    if (field.toLowerCase().contains('email')) {
      return TextInputType.emailAddress;
    }
    return TextInputType.text;
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Container(
          margin: EdgeInsets.only(right: 12, left: 4),
          width: 40,
          child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 0),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSubmitting ? null : _submitProfileUpdateRequest,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isSubmitting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.update_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Submit Update Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _clearCurrentFields() {
    var currentType = updateTypes.firstWhere((type) => type['value'] == selectedUpdateType);
    for (var field in currentType['fields']) {
      controllers[field]?.clear();
    }
  }

  Future<void> _submitProfileUpdateRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var currentType = updateTypes.firstWhere((type) => type['value'] == selectedUpdateType);
    Map<String, String> updateData = {};
    
    bool hasData = false;
    for (var field in currentType['fields']) {
      String value = controllers[field]?.text.trim() ?? '';
      if (value.isNotEmpty) {
        updateData[field] = value;
        hasData = true;
      }
    }

    if (!hasData) {
      _showSnackBar('Please fill at least one field to update', false);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('employeeRequests').add({
        'userId': widget.userId,
        'employeeName': widget.userName,
        'requestType': 'profile_update',
        'updateType': selectedUpdateType,
        'updateTypeLabel': currentType['label'],
        'updateData': updateData,
        'reason': controllers['reason']?.text.trim(),
        'status': 'pending',
        'appliedDate': DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _clearAllFields();
      _showSnackBar('Profile update request submitted successfully!', true);
    } catch (e) {
      _showSnackBar('Error submitting request', false);
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white),
            SizedBox(width: 12),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _clearAllFields() {
    for (var controller in controllers.values) {
    controller.clear();
  }
  }
}

// Mis-Punch Request Tab
class MisPunchRequestTab extends StatefulWidget {
  final String userId;
  final String userName;

  const MisPunchRequestTab({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<MisPunchRequestTab> createState() => _MisPunchRequestTabState();
}

class _MisPunchRequestTabState extends State<MisPunchRequestTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _inTimeController = TextEditingController();
  final TextEditingController _outTimeController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String selectedPunchType = 'both';
  bool isSubmitting = false;

  final List<Map<String, dynamic>> punchTypes = [
    {'value': 'in', 'label': 'Missed In-Punch', 'icon': Icons.login_rounded, 'color': Color(0xFF3B82F6)},
    {'value': 'out', 'label': 'Missed Out-Punch', 'icon': Icons.logout_rounded, 'color': Color(0xFFEF4444)},
    {'value': 'both', 'label': 'Missed Both', 'icon': Icons.sync_alt_rounded, 'color': Color(0xFFF59E0B)},
    {'value': 'wrong_time', 'label': 'Wrong Time', 'icon': Icons.schedule_rounded, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _inTimeController.dispose();
    _outTimeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 1)),
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = picked.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = punchTypes.firstWhere((type) => type['value'] == selectedPunchType);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              title: 'Mis-Punch Correction',
              subtitle: 'Report missed or incorrect punch times for attendance correction',
            ),
            SizedBox(height: 16),
            _buildInfoBanner(),
            SizedBox(height: 20),
            _buildDateSection(),
            SizedBox(height: 20),
            _buildPunchTypeSelector(),
            SizedBox(height: 20),
            _buildTimeSection(),
            SizedBox(height: 20),
            _buildReasonSection(),
            SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple.withOpacity(0.1), AppTheme.lightPurple.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: 40),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_rounded, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'Mis-punch requests can only be raised for the last 30 days',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_today_rounded, color: AppTheme.primaryPurple, size: 18),
              ),
              SizedBox(width: 8),
              Text(
                'Select Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildModernTextField(
            controller: _dateController,
            label: 'Date *',
            icon: Icons.event_rounded,
            readOnly: true,
            onTap: _selectDate,
            validator: (value) => value?.isEmpty == true ? 'Date is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPunchTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.touch_app_rounded, color: AppTheme.primaryPurple, size: 18),
              ),
              SizedBox(width: 8),
              Text(
                'Punch Issue Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: punchTypes.map((type) {
              final isSelected = selectedPunchType == type['value'];
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedPunchType = type['value'];
                  });
                },
                child: Container(
                  width: MediaQuery.of(context).size.width / 2 - 26,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [type['color'].withOpacity(0.15), type['color'].withOpacity(0.05)],
                          )
                        : null,
                    color: isSelected ? null : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? type['color'] : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? type['color'] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          type['icon'],
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        type['label'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? type['color'] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSection() {
    bool showInTime = selectedPunchType == 'in' || selectedPunchType == 'both' || selectedPunchType == 'wrong_time';
    bool showOutTime = selectedPunchType == 'out' || selectedPunchType == 'both' || selectedPunchType == 'wrong_time';

    if (!showInTime && !showOutTime) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.access_time_rounded, color: AppTheme.primaryPurple, size: 18),
              ),
              SizedBox(width: 8),
              Text(
                'Correct Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (showInTime && showOutTime)
            Row(
              children: [
                Expanded(
                  child: _buildModernTextField(
                    controller: _inTimeController,
                    label: 'In Time *',
                    icon: Icons.login_rounded,
                    readOnly: true,
                    onTap: () => _selectTime(_inTimeController),
                    validator: (value) => value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildModernTextField(
                    controller: _outTimeController,
                    label: 'Out Time *',
                    icon: Icons.logout_rounded,
                    readOnly: true,
                    onTap: () => _selectTime(_outTimeController),
                    validator: (value) => value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
              ],
            )
          else if (showInTime)
            _buildModernTextField(
              controller: _inTimeController,
              label: 'Correct In Time *',
              icon: Icons.login_rounded,
              readOnly: true,
              onTap: () => _selectTime(_inTimeController),
              validator: (value) => value?.isEmpty == true ? 'In time is required' : null,
            )
          else if (showOutTime)
            _buildModernTextField(
              controller: _outTimeController,
              label: 'Correct Out Time *',
              icon: Icons.logout_rounded,
              readOnly: true,
              onTap: () => _selectTime(_outTimeController),
              validator: (value) => value?.isEmpty == true ? 'Out time is required' : null,
            ),
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_rounded, color: AppTheme.primaryPurple, size: 18),
              ),
              SizedBox(width: 8),
              Text(
                'Reason',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildModernTextField(
            controller: _reasonController,
            label: 'Reason for Mis-Punch *',
            icon: Icons.edit_note_rounded,
            maxLines: 4,
            validator: (value) => value?.isEmpty == true ? 'Reason is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Container(
          margin: EdgeInsets.only(right: 12, left: 4),
          width: 40,
          child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 0),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSubmitting ? null : _submitMisPunchRequest,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isSubmitting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Submit Mis-Punch Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitMisPunchRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      var selectedType = punchTypes.firstWhere((type) => type['value'] == selectedPunchType);
      
      await FirebaseFirestore.instance.collection('employeeRequests').add({
        'userId': widget.userId,
        'employeeName': widget.userName,
        'requestType': 'mis_punch',
        'date': _dateController.text,
        'punchType': selectedPunchType,
        'punchTypeLabel': selectedType['label'],
        'correctInTime': _inTimeController.text.trim(),
        'correctOutTime': _outTimeController.text.trim(),
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'appliedDate': DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      _showSnackBar('Mis-punch request submitted successfully!', true);
    } catch (e) {
      _showSnackBar('Error submitting request', false);
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white),
            SizedBox(width: 12),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _clearForm() {
    _dateController.clear();
    _inTimeController.clear();
    _outTimeController.clear();
    _reasonController.clear();
    setState(() {
      selectedPunchType = 'both';
    });
  }
}

// My Requests Tab
class MyRequestsTab extends StatefulWidget {
  final String userId;

  const MyRequestsTab({super.key, required this.userId});

  @override
  State<MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<MyRequestsTab> {
  String selectedStatus = 'all';
  String selectedType = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildFilters(),
        Flexible(child: _buildRequestsList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple.withOpacity(0.1), AppTheme.lightPurple.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.list_alt_rounded, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'My Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: 40),
            child: Text(
              'Track and manage all your submitted requests in one place',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        children: [
          Expanded(
            child: _buildStatusFilter(),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildTypeFilter(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedStatus,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryPurple),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: _buildFilterItem(Icons.filter_list_rounded, 'All Status', Colors.grey),
            ),
            DropdownMenuItem(
              value: 'pending',
              child: _buildFilterItem(Icons.pending_rounded, 'Pending', Colors.orange),
            ),
            DropdownMenuItem(
              value: 'approved',
              child: _buildFilterItem(Icons.check_circle_rounded, 'Approved', Colors.green),
            ),
            DropdownMenuItem(
              value: 'rejected',
              child: _buildFilterItem(Icons.cancel_rounded, 'Rejected', Colors.red),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedStatus = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedType,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryPurple),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: _buildFilterItem(Icons.category_rounded, 'All Types', Colors.grey),
            ),
            DropdownMenuItem(
              value: 'leave',
              child: _buildFilterItem(Icons.event_note_rounded, 'Leave', Colors.blue),
            ),
            DropdownMenuItem(
              value: 'profile_update',
              child: _buildFilterItem(Icons.person_rounded, 'Profile', Colors.purple),
            ),
            DropdownMenuItem(
              value: 'mis_punch',
              child: _buildFilterItem(Icons.fingerprint_rounded, 'Mis-Punch', Colors.orange),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedType = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFilterItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var requests = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var request = requests[index];
            var data = request.data() as Map<String, dynamic>;
            
            return _buildRequestCard(data);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.palePurple,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.request_page_outlined,
              size: 64,
              color: AppTheme.primaryPurple,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No requests found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Submit requests using the buttons above',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data) {
    final requestType = data['requestType'] ?? '';
    final status = data['status'] ?? 'unknown';
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.all(16),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getRequestTypeColor(requestType),
                  _getRequestTypeColor(requestType).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getRequestTypeIcon(requestType),
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            _getRequestTitle(data),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                _getRequestSubtitle(data),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 12, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    'Applied: ${data['appliedDate']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getStatusColor(status),
                  _getStatusColor(status).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(status).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestDetails(data),
                  SizedBox(height: 16),
                  _buildStatusBanner(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestDetails(Map<String, dynamic> data) {
    switch (data['requestType']) {
      case 'leave':
        return _buildLeaveDetails(data);
      case 'profile_update':
        return _buildProfileUpdateDetails(data);
      case 'mis_punch':
        return _buildMisPunchDetails(data);
      default:
        return Text('No details available');
    }
  }

  Widget _buildLeaveDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSection('Leave Information', [
          _buildDetailRow(Icons.event_rounded, 'Start Date', data['startDate']),
          _buildDetailRow(Icons.event_rounded, 'End Date', data['endDate']),
          _buildDetailRow(Icons.access_time_rounded, 'Duration', '${data['duration']} day(s)'),
          _buildDetailRow(Icons.category_rounded, 'Type', data['subType']?.toUpperCase()),
        ]),
        if (data['reason'] != null && data['reason'].toString().isNotEmpty) ...[
          SizedBox(height: 12),
          _buildDetailSection('Reason', [
            _buildTextDetail(data['reason']),
          ]),
        ],
        if (data['contactNumber'] != null && data['contactNumber'].toString().isNotEmpty) ...[
          SizedBox(height: 12),
          _buildDetailSection('Emergency Contact', [
            _buildDetailRow(Icons.phone_rounded, 'Contact', data['contactNumber']),
          ]),
        ],
      ],
    );
  }

  Widget _buildProfileUpdateDetails(Map<String, dynamic> data) {
    Map<String, dynamic> updateData = data['updateData'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSection('Updates Requested', 
          updateData.entries.map((entry) => 
            _buildDetailRow(Icons.edit_rounded, entry.key, entry.value)
          ).toList(),
        ),
        if (data['reason'] != null && data['reason'].toString().isNotEmpty) ...[
          SizedBox(height: 12),
          _buildDetailSection('Reason', [
            _buildTextDetail(data['reason']),
          ]),
        ],
      ],
    );
  }

  Widget _buildMisPunchDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSection('Mis-Punch Information', [
          _buildDetailRow(Icons.calendar_today_rounded, 'Date', data['date']),
          _buildDetailRow(Icons.touch_app_rounded, 'Issue Type', data['punchTypeLabel']),
          if (data['correctInTime'] != null && data['correctInTime'].toString().isNotEmpty)
            _buildDetailRow(Icons.login_rounded, 'In Time', data['correctInTime']),
          if (data['correctOutTime'] != null && data['correctOutTime'].toString().isNotEmpty)
            _buildDetailRow(Icons.logout_rounded, 'Out Time', data['correctOutTime']),
        ]),
        if (data['reason'] != null && data['reason'].toString().isNotEmpty) ...[
          SizedBox(height: 12),
          _buildDetailSection('Reason', [
            _buildTextDetail(data['reason']),
          ]),
        ],
      ],
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryPurple,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextDetail(String text) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.5),
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    IconData icon;
    String message;
    Color color;
    
    switch (status) {
      case 'pending':
        icon = Icons.pending_actions_rounded;
        message = 'Your request is being reviewed';
        color = Colors.orange;
        break;
      case 'approved':
        icon = Icons.check_circle_rounded;
        message = 'Your request has been approved';
        color = Colors.green;
        break;
      case 'rejected':
        icon = Icons.cancel_rounded;
        message = 'Your request has been rejected';
        color = Colors.red;
        break;
      default:
        icon = Icons.help_rounded;
        message = 'Status unknown';
        color = Colors.grey;
    }
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getRequestsStream() {
    Query query = FirebaseFirestore.instance
        .collection('employeeRequests')
        .where('userId', isEqualTo: widget.userId);

    if (selectedStatus != 'all') {
      query = query.where('status', isEqualTo: selectedStatus);
    }

    if (selectedType != 'all') {
      query = query.where('requestType', isEqualTo: selectedType);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Color _getRequestTypeColor(String? type) {
    switch (type) {
      case 'leave':
        return Color(0xFF3B82F6);
      case 'profile_update':
        return Color(0xFF8B5CF6);
      case 'mis_punch':
        return Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData _getRequestTypeIcon(String? type) {
    switch (type) {
      case 'leave':
        return Icons.event_note_rounded;
      case 'profile_update':
        return Icons.person_rounded;
      case 'mis_punch':
        return Icons.fingerprint_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _getRequestTitle(Map<String, dynamic> data) {
    switch (data['requestType']) {
      case 'leave':
        return '${data['leaveType']?.toString().toUpperCase()} LEAVE';
      case 'profile_update':
        return data['updateTypeLabel'] ?? 'Profile Update';
      case 'mis_punch':
        return 'Mis-Punch Correction';
      default:
        return 'Unknown Request';
    }
  }

  String _getRequestSubtitle(Map<String, dynamic> data) {
    switch (data['requestType']) {
      case 'leave':
        return '${data['startDate']} to ${data['endDate']} • ${data['duration']} day(s)';
      case 'profile_update':
        return 'Update Type: ${data['updateType']?.toUpperCase()}';
      case 'mis_punch':
        return 'Date: ${data['date']} • ${data['punchTypeLabel']}';
      default:
        return 'Request details';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Color(0xFFF59E0B);
      case 'approved':
        return Color(0xFF10B981);
      case 'rejected':
        return Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }
}