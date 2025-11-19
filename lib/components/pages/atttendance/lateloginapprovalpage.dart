import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LateLoginApprovalPage extends StatefulWidget {
  const LateLoginApprovalPage({super.key});

  @override
  State<LateLoginApprovalPage> createState() => _LateLoginApprovalPageState();
}

class _LateLoginApprovalPageState extends State<LateLoginApprovalPage>
    with SingleTickerProviderStateMixin {
  String selectedFilter = 'pending';
  String currentUserName = '';
  String currentUserRole = '';
  bool isLoading = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        setState(() {
          currentUserName = userDoc['empName'] ?? 'Admin';
          currentUserRole = userDoc['role'] ?? 'admin';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot> _getApprovalsStream() {
    // Simple query without composite index requirement
    if (selectedFilter != 'all') {
      return FirebaseFirestore.instance
          .collection('loginApprovals')
          .where('status', isEqualTo: selectedFilter)
          .limit(100)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('loginApprovals')
          .orderBy('requestTime', descending: true)
          .limit(100)
          .snapshots();
    }
  }

  Future<void> _approveRequest(String approvalId, Map<String, dynamic> data) async {
    try {
      // Update approval status
      await FirebaseFirestore.instance
          .collection('loginApprovals')
          .doc(approvalId)
          .update({
        'status': 'approved',
        'approvedBy': currentUserName,
        'approvedById': FirebaseAuth.instance.currentUser?.uid,
        'approvalTime': FieldValue.serverTimestamp(),
        'approvalTimeStr': DateFormat('h:mm a').format(DateTime.now()),
      });

      // Send notification to user
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': data['userId'],
        'type': 'login_approved',
        'title': 'Login Approved',
        'message': 'Your late login request has been approved by $currentUserName',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      _showSnackBar(
        'Login request approved for ${data['userName']}',
        Colors.green,
        Icons.check_circle,
      );
    } catch (e) {
      _showSnackBar(
        'Error approving request: $e',
        Colors.red,
        Icons.error,
      );
    }
  }

  Future<void> _rejectRequest(String approvalId, Map<String, dynamic> data) async {
    TextEditingController reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Reject Login Request')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee: ${data['userName']}'),
              Text('Request Time: ${data['requestTimeStr']}'),
              Text('Late By: ${(data['lateBy'] * 60).toInt()} minutes'),
              SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'Enter reason for rejection...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.edit),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please provide a reason'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text('Reject'),
            ),
          ],
        );
      },
    );

    if (result == true && reasonController.text.trim().isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('loginApprovals')
            .doc(approvalId)
            .update({
          'status': 'rejected',
          'rejectedBy': currentUserName,
          'rejectedById': FirebaseAuth.instance.currentUser?.uid,
          'rejectionTime': FieldValue.serverTimestamp(),
          'rejectionTimeStr': DateFormat('h:mm a').format(DateTime.now()),
          'rejectionReason': reasonController.text.trim(),
        });

        // Send notification to user
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': data['userId'],
          'type': 'login_rejected',
          'title': 'Login Rejected',
          'message': 'Your late login request was rejected: ${reasonController.text.trim()}',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        _showSnackBar(
          'Login request rejected for ${data['userName']}',
          Colors.red,
          Icons.cancel,
        );
      } catch (e) {
        _showSnackBar(
          'Error rejecting request: $e',
          Colors.red,
          Icons.error,
        );
      }
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Late Login Approvals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  indicatorWeight: 3,
                  onTap: (index) {
                    setState(() {
                      selectedFilter = ['pending', 'approved', 'rejected'][index];
                    });
                  },
                  tabs: [
                    Tab(
                      icon: Icon(Icons.hourglass_empty),
                      text: 'Pending',
                    ),
                    Tab(
                      icon: Icon(Icons.check_circle),
                      text: 'Approved',
                    ),
                    Tab(
                      icon: Icon(Icons.cancel),
                      text: 'Rejected',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _getApprovalsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error loading approvals',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final approvals = snapshot.data?.docs ?? [];

                if (approvals.isEmpty) {
                  return _buildEmptyState();
                }

                // Sort client-side by requestTime
                List<QueryDocumentSnapshot> sortedApprovals = approvals.toList();
                sortedApprovals.sort((a, b) {
                  try {
                    Timestamp? timeA = a.get('requestTime') as Timestamp?;
                    Timestamp? timeB = b.get('requestTime') as Timestamp?;
                    
                    if (timeA == null && timeB == null) return 0;
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    
                    return timeB.compareTo(timeA); // Descending order
                  } catch (e) {
                    return 0;
                  }
                });

                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive layout
                    if (constraints.maxWidth > 900) {
                      // Desktop: Grid with 2 columns
                      return _buildGridView(sortedApprovals, 2);
                    } else if (constraints.maxWidth > 600) {
                      // Tablet: Grid with 2 columns
                      return _buildGridView(sortedApprovals, 2);
                    } else {
                      // Mobile: List view
                      return _buildListView(sortedApprovals);
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No ${selectedFilter == 'all' ? '' : selectedFilter} requests found';
    IconData icon = Icons.inbox;
    Color color = Colors.grey;

    if (selectedFilter == 'pending') {
      icon = Icons.done_all;
      color = Colors.green;
      message = 'All caught up! No pending approvals';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: color.withOpacity(0.5)),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot> approvals) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: approvals.length,
      itemBuilder: (context, index) {
        return _buildApprovalCard(approvals[index], false);
      },
    );
  }

  Widget _buildGridView(List<QueryDocumentSnapshot> approvals, int columns) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: approvals.length,
      itemBuilder: (context, index) {
        return _buildApprovalCard(approvals[index], true);
      },
    );
  }

  Widget _buildApprovalCard(QueryDocumentSnapshot doc, bool isGrid) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String status = data['status'] ?? 'pending';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['userName'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'EMP ID: ${data['empId'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 12),
            
            // Details
            _buildDetailRow(
              Icons.calendar_today,
              'Date',
              data['date'] ?? 'N/A',
              Colors.blue,
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              Icons.access_time,
              'Request Time',
              data['requestTimeStr'] ?? 'N/A',
              Colors.purple,
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              Icons.timer,
              'Late By',
              '${((data['lateBy'] ?? 0) * 60).toInt()} minutes',
              Colors.red,
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on,
              'Location',
              data['coordinates'] ?? 'Unknown',
              Colors.green,
            ),
            
            if (data['reason'] != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Reason',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      data['reason'],
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action taken info
            if (status != 'pending') ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        SizedBox(width: 4),
                        Text(
                          status == 'approved' ? 'Approved By' : 'Rejected By',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      status == 'approved'
                          ? data['approvedBy'] ?? 'Unknown'
                          : data['rejectedBy'] ?? 'Unknown',
                      style: TextStyle(fontSize: 13),
                    ),
                    Text(
                      'at ${status == 'approved' ? data['approvalTimeStr'] : data['rejectionTimeStr']}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (status == 'rejected' && data['rejectionReason'] != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Reason: ${data['rejectionReason']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            // Action buttons for pending requests
            if (status == 'pending') ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(Icons.cancel, size: 18),
                      label: Text('Reject'),
                      onPressed: () => _rejectRequest(doc.id, data),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(Icons.check_circle, size: 18),
                      label: Text('Approve'),
                      onPressed: () => _approveRequest(doc.id, data),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}