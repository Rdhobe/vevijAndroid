import 'package:intl/intl.dart';
import 'package:vevij/components/imports.dart';


// Modern Purple Theme

class AdminRequestManagementPage extends StatefulWidget {
  const AdminRequestManagementPage({super.key});

  @override
  State<AdminRequestManagementPage> createState() => _AdminRequestManagementPageState();
}

class _AdminRequestManagementPageState extends State<AdminRequestManagementPage> {
  String _selectedFilter = 'all';
  String _selectedRequestType = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _filters = [
    {'value': 'all', 'label': 'All Requests', 'icon': Icons.filter_list_rounded},
    {'value': 'pending', 'label': 'Pending', 'icon': Icons.pending_actions_rounded},
    {'value': 'approved', 'label': 'Approved', 'icon': Icons.check_circle_rounded},
    {'value': 'rejected', 'label': 'Rejected', 'icon': Icons.cancel_rounded},
  ];

  final List<Map<String, dynamic>> _requestTypes = [
    {'value': 'all', 'label': 'All Types', 'icon': Icons.category_rounded},
    {'value': 'leave', 'label': 'Leave', 'icon': Icons.event_note_rounded},
    {'value': 'profile_update', 'label': 'Profile', 'icon': Icons.person_rounded},
    {'value': 'mis_punch', 'label': 'Mis-Punch', 'icon': Icons.fingerprint_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          _buildFiltersSection(),
          SizedBox(height: 8),
          // Statistics
          _buildStatistics(),
          SizedBox(height: 8),
          // Requests List
          Expanded(
            child: _buildRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
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
      child: Column(
        children: [
          // Search Bar
          _buildSearchBar(),
          SizedBox(height: 16),
          // Filter Chips
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by employee name...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryPurple),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter['value'];
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter['value'];
                      });
                    },
                    label: Text(
                      filter['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                    avatar: Icon(
                      filter['icon'],
                      size: 16,
                      color: isSelected ? Colors.white : AppTheme.primaryPurple,
                    ),
                    backgroundColor: Colors.grey[100],
                    selectedColor: AppTheme.primaryPurple,
                    checkmarkColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              _selectedRequestType = value;
            });
          },
          itemBuilder: (context) => _requestTypes.map((type) {
            return PopupMenuItem<String>(
              value: type['value'],
              child: Row(
                children: [
                  Icon(type['icon'], size: 18, color: AppTheme.primaryPurple),
                  SizedBox(width: 8),
                  Text(type['label']),
                ],
              ),
            );
          }).toList(),
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.palePurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tune_rounded, color: AppTheme.primaryPurple, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('employeeRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox();
        }

        final pendingCount = snapshot.data!.docs.length;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pendingCount Pending Requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Require your attention',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
        
        // Sort requests: pending first, then by date
        requests.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          if (aData['status'] == 'pending' && bData['status'] != 'pending') return -1;
          if (aData['status'] != 'pending' && bData['status'] == 'pending') return 1;
          
          final aDate = (aData['createdAt'] as Timestamp).toDate();
          final bDate = (bData['createdAt'] as Timestamp).toDate();
          return bDate.compareTo(aDate);
        });

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var request = requests[index];
            var data = request.data() as Map<String, dynamic>;
            
            return _buildRequestCard(request.id, data);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> data) {
    final isPending = data['status'] == 'pending';
    
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
                  _getRequestTypeColor(data['requestType']),
                  _getRequestTypeColor(data['requestType']).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getRequestTypeIcon(data['requestType']),
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            data['employeeName'] ?? 'Unknown Employee',
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
                  _getStatusColor(data['status']),
                  _getStatusColor(data['status']).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(data['status']).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              (data['status'] ?? 'unknown').toUpperCase(),
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
                  if (isPending) _buildActionButtons(requestId, data),
                  if (!isPending) _buildStatusInfo(data),
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
          _buildDetailRow(Icons.category_rounded, 'Leave Type', _formatLeaveType(data['leaveType'])),
          _buildDetailRow(Icons.event_rounded, 'Start Date', data['startDate']),
          _buildDetailRow(Icons.event_rounded, 'End Date', data['endDate']),
          _buildDetailRow(Icons.access_time_rounded, 'Duration', '${data['duration']} day(s)'),
          _buildDetailRow(Icons.schedule_rounded, 'Sub Type', data['subType']?.toUpperCase()),
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

  Widget _buildActionButtons(String requestId, Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showApprovalDialog(requestId, data, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, size: 18),
                SizedBox(width: 8),
                Text('Approve'),
              ],
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showRejectionDialog(requestId, data),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.close_rounded, size: 18),
                SizedBox(width: 8),
                Text('Reject'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(Map<String, dynamic> data) {
    final status = data['status'];
    final processedBy = data['processedBy'];
    final processedAt = data['processedAt'];
    final adminNotes = data['adminNotes'];

    IconData icon;
    String message;
    Color color;
    
    switch (status) {
      case 'approved':
        icon = Icons.check_circle_rounded;
        message = 'Approved by $processedBy';
        color = Colors.green;
        break;
      case 'rejected':
        icon = Icons.cancel_rounded;
        message = 'Rejected by $processedBy';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (processedAt != null) ...[
            SizedBox(height: 8),
            Text(
              'Processed on: ${DateFormat('dd/MM/yyyy HH:mm').format((processedAt as Timestamp).toDate())}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          if (adminNotes != null && adminNotes.toString().isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Notes: $adminNotes',
              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  void _showApprovalDialog(String requestId, Map<String, dynamic> data, bool isApprove) {
    TextEditingController notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded, 
                color: isApprove ? Colors.green : Colors.red),
            SizedBox(width: 8),
            Text(isApprove ? 'Approve Request' : 'Reject Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to ${isApprove ? 'approve' : 'reject'} this request?'),
            SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateRequestStatus(
                requestId, 
                data, 
                isApprove ? 'approved' : 'rejected',
                notesController.text.trim(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : Colors.red,
            ),
            child: Text(isApprove ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(String requestId, Map<String, dynamic> data) {
    _showApprovalDialog(requestId, data, false);
  }

  Future<void> _updateRequestStatus(
    String requestId, 
    Map<String, dynamic> data, 
    String status, 
    String notes
  ) async {
    try {
      // get user name from data
      // get uid
      String userName = 'Admin';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get()
          .then((userSnapshot) {
        if (userSnapshot.exists) {
           String userName = userSnapshot.data()?['empName'] ?? 'Unknown';
        }
      });

      await FirebaseFirestore.instance
          .collection('employeeRequests')
          .doc(requestId)
          .update({
        'status': status,
        'processedBy': userName, // Replace with actual admin name
        'processedAt': FieldValue.serverTimestamp(),
        'adminNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${status} successfully'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating request'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              Icons.assignment_turned_in_rounded,
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
            'All requests are processed or no matching results',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getRequestsStream() {
    Query query = FirebaseFirestore.instance.collection('employeeRequests');

    // Apply status filter
    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    // Apply request type filter
    if (_selectedRequestType != 'all') {
      query = query.where('requestType', isEqualTo: _selectedRequestType);
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      query = query.where('employeeName', isGreaterThanOrEqualTo: _searchQuery)
                   .where('employeeName', isLessThan: _searchQuery + 'z');
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  String _getRequestSubtitle(Map<String, dynamic> data) {
    switch (data['requestType']) {
      case 'leave':
        return '${_formatLeaveType(data['leaveType'])} • ${data['startDate']} to ${data['endDate']}';
      case 'profile_update':
        return '${data['updateTypeLabel']} • Update Request';
      case 'mis_punch':
        return '${data['punchTypeLabel']} • ${data['date']}';
      default:
        return 'Request details';
    }
  }

  String _formatLeaveType(String? type) {
    switch (type) {
      case 'sick': return 'Sick Leave';
      case 'casual': return 'Casual Leave';
      case 'emergency': return 'Emergency Leave';
      case 'maternity': return 'Maternity Leave';
      case 'paternity': return 'Paternity Leave';
      case 'annual': return 'Annual Leave';
      default: return 'Leave';
    }
  }

  Color _getRequestTypeColor(String? type) {
    switch (type) {
      case 'leave': return Color(0xFF3B82F6);
      case 'profile_update': return Color(0xFF8B5CF6);
      case 'mis_punch': return Color(0xFFF59E0B);
      default: return Colors.grey;
    }
  }

  IconData _getRequestTypeIcon(String? type) {
    switch (type) {
      case 'leave': return Icons.event_note_rounded;
      case 'profile_update': return Icons.person_rounded;
      case 'mis_punch': return Icons.fingerprint_rounded;
      default: return Icons.help_rounded;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Color(0xFFF59E0B);
      case 'approved': return Color(0xFF10B981);
      case 'rejected': return Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }
}