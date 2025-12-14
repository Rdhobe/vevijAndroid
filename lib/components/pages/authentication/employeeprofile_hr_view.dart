import 'package:vevij/components/imports.dart';

class HRProfilePage extends StatefulWidget {
  final Map<String, dynamic> employeeData;

  const HRProfilePage({super.key, required this.employeeData});

  @override
  State<HRProfilePage> createState() => _HRProfilePageState();
}

class _HRProfilePageState extends State<HRProfilePage> {
  bool _showFullAadhar = false;
  bool _showFullAccount = false;
  String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Employee Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (widget.employeeData['uid'] != uid) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                // Edit functionality
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditEmployeePage(
                      employeeData: widget.employeeData,
                    ),
                  ),
                );
              },
            ),
          ],
          if (widget.employeeData['uid'] != uid) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'deactivate':
                    _showDeactivateDialog();
                    break;
                  case 'delete':
                    _showDeleteDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Deactivate Employee'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Employee'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 20),

            // Basic Information
            _buildSectionCard(
              title: 'Basic Information',
              icon: Icons.person_outline,
              children: [
                _buildInfoTile(
                  'Employee Code',
                  widget.employeeData['empCode'] ?? 'N/A',
                ),
                _buildInfoTile('Title', widget.employeeData['title'] ?? 'N/A'),
                _buildInfoTile(
                  'Full Name',
                  widget.employeeData['empName'] ?? 'N/A',
                ),
                _buildInfoTile('Email', widget.employeeData['email'] ?? 'N/A'),
                _buildInfoTile(
                  'Gender',
                  widget.employeeData['gender'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Birth Date',
                  widget.employeeData['birthDate'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Shift',
                  widget.employeeData['shift'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Work Location',
                  widget.employeeData['workLocation'] ?? 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Work Details
            _buildSectionCard(
              title: 'Work Details',
              icon: Icons.work_outline,
              children: [
                _buildInfoTile('Grade', widget.employeeData['grade'] ?? 'N/A'),
                _buildInfoTile(
                  'Branch',
                  widget.employeeData['branch'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Department',
                  widget.employeeData['department'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Designation',
                  widget.employeeData['designation'] ?? 'N/A',
                ),
                _buildStatusTile(
                  'Status',
                  widget.employeeData['status'] ?? 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Important Dates
            _buildSectionCard(
              title: 'Important Dates',
              icon: Icons.calendar_today_outlined,
              children: [
                _buildInfoTile(
                  'Join Date',
                  widget.employeeData['joinDate'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Service Months',
                  widget.employeeData['serviceMonth'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Probation Date',
                  widget.employeeData['probationDate'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Last Increment Date',
                  widget.employeeData['lastIncrementDate'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Last Working Date',
                  widget.employeeData['lastWorkingDate'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Resign Offer Date',
                  widget.employeeData['resignOfferDate'] ?? 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payment & Bank Details
            _buildSectionCard(
              title: 'Payment & Bank Details',
              icon: Icons.account_balance_outlined,
              children: [
                _buildInfoTile(
                  'Payment Mode',
                  widget.employeeData['paymentMode'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Bank Name',
                  widget.employeeData['bankDetails']?['bankName'] ?? 'N/A',
                ),
                _buildSecureTile(
                  'Account Number',
                  widget.employeeData['bankDetails']?['accountNumber'] ?? 'N/A',
                  _showFullAccount,
                  () => setState(() => _showFullAccount = !_showFullAccount),
                ),
                _buildInfoTile(
                  'IFSC Code',
                  widget.employeeData['bankDetails']?['ifscCode'] ?? 'N/A',
                ),
                _buildInfoTile(
                  'Bank Branch',
                  widget.employeeData['bankDetails']?['branch'] ?? 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Document Details
            _buildSectionCard(
              title: 'Document Details',
              icon: Icons.credit_card_outlined,
              children: [
                _buildInfoTile(
                  'PAN Number',
                  widget.employeeData['panNumber'] ?? 'N/A',
                ),
                _buildSecureTile(
                  'Aadhar Number',
                  widget.employeeData['aadharNumber'] ?? 'N/A',
                  _showFullAadhar,
                  () => setState(() => _showFullAadhar = !_showFullAadhar),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 20),
            //logout button
            if (widget.employeeData['uid'] == uid) ...[
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[300]!, Colors.red[100]!],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle logout
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue[100],
            child: Text(
              _getInitials(widget.employeeData['empName'] ?? 'N/A'),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Employee Name
          Text(
            '${widget.employeeData['title'] ?? ''} ${widget.employeeData['empName'] ?? 'N/A'}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Employee Code
          Text(
            'Employee Code: ${widget.employeeData['empCode'] ?? 'N/A'}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Designation & Department
          Text(
            '${widget.employeeData['designation'] ?? 'N/A'} • ${widget.employeeData['department'] ?? 'N/A'}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Section Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              label == 'Email'
                  ? IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email copied to clipboard')),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile(String label, String value) {
    Color statusColor = _getStatusColor(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureTile(
    String label,
    String value,
    bool isVisible,
    VoidCallback onToggle,
  ) {
    String displayValue = value;
    if (!isVisible && value.isNotEmpty && value != 'N/A') {
      if (label.contains('Account')) {
        displayValue = '****${value.substring(value.length - 1)}';
      } else if (label.contains('Aadhar')) {
        displayValue = '****${value.substring(8)}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (value != 'N/A' && value.isNotEmpty)
                  GestureDetector(
                    onTap: onToggle,
                    child: Icon(
                      isVisible ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty || name == 'N/A') return 'NA';
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'transferred':
        return Colors.blue;
      case 'resigned':
      case 'terminated':
      case 'expired':
        return Colors.red;
      case 'retired':
      case 'vrs':
        return Colors.orange;
      case 'offered':
        return Colors.purple;
      case 'not joined':
      case 'absconded':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }



  void _showDeactivateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Employee'),
        content: Text(
          'Are you sure you want to deactivate ${widget.employeeData['empName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement deactivation logic
              // update database
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.employeeData['uid'])
                  .update({'status': 'Inactive'});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Employee deactivated')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() async {
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.deleteEmployee)) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text(
          'Are you sure you want to permanently delete ${widget.employeeData['empName']}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // delete employee from database and auth
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.employeeData['uid'])
                  .delete();
              
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Employee deleted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to delete this employee.')));
    }
  }
  }

