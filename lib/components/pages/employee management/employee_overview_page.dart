import 'package:vevij/components/imports.dart';

// Employee Overview Page
class EmployeeOverviewPage extends StatefulWidget {
  const EmployeeOverviewPage({super.key});

  @override
  State<EmployeeOverviewPage> createState() => _EmployeeOverviewPageState();
}

class _EmployeeOverviewPageState extends State<EmployeeOverviewPage> {
  String searchQuery = '';
  String selectedDesignation = 'All';
  String selectedStatus = 'All';

  @override
  void initState() {
    super.initState();

    selectedDesignation = 'All';
    selectedStatus = 'All';
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Management'),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
        FutureBuilder<bool>(
          future: EmployeePermissionChecker.can(
            FirebaseAuth.instance.currentUser!.uid,
            EmployeePermission.addEmployee,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(); // or a loader
            }

            if (snapshot.hasData && snapshot.data == true) {
              return IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateEmployeePage(),
                    ),
                  );
                },
              );
            }

            return SizedBox();
          },
        )
      ],
      ),
      body: Column(
        children: [
          // Filters and Search
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedDesignation,
                        decoration: InputDecoration(
                          labelText: 'Designations',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items:
                            [
                                  'All',
                                  "Accountant",
                                  "Accountants Manager",
                                  "Admin",
                                  "Business Development Manager",
                                  "Designer",
                                  "Driver",
                                  "Godown",
                                  "Hod",
                                  "Housekeeping",
                                  "Hr",
                                  "Labor",
                                  "Measurements",
                                  "Payment",
                                  "Store Executive",
                                  "Supervisor",
                                ]
                                .map(
                                  (dept) => DropdownMenuItem(
                                    value: dept,
                                    child: Text(dept),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedDesignation = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: ['All', 'Active', 'Resigned', 'Terminated']
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      
          // Employee List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
      
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
      
                var employees = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  var name = (data['empName'] ?? '').toString().toLowerCase();
                  var designation = data['designation'] ?? '';
                  var status = data['status'] ?? '';
      
                  bool matchesSearch =
                      searchQuery.isEmpty || name.contains(searchQuery);
                  bool matchesDesignation =
                      selectedDesignation == 'All' ||
                      designation == selectedDesignation;
                  bool matchesStatus =
                      selectedStatus == 'All' || status == selectedStatus;
      
                  return matchesSearch && matchesDesignation && matchesStatus;
                }).toList();
      
                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No employees found'),
                      ],
                    ),
                  );
                }
      
                return ListView.builder(
                  itemCount: employees.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    var employee = employees[index];
                    var data = employee.data() as Map<String, dynamic>;
      
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo[100],
                          child: Text(
                            (data['empName'] ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[700],
                            ),
                          ),
                        ),
                        title: Text(
                          data['empName'] ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data['designation'] ?? 'N/A'} • ${data['department'] ?? 'N/A'}',
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(data['status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    data['status'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility, size: 18),
                                  SizedBox(width: 8),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'attendance',
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, size: 18),
                                  SizedBox(width: 8),
                                  Text('Attendance'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HRProfilePage(employeeData: data),
                                  ),
                                );
                                break;
                              case 'attendance':
                                _viewAttendance(
                                  context,
                                  employee.id,
                                  data['empName'],
                                );
                                break;
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HRProfilePage(employeeData: data),
                            ),
                          );
                        },
                        onLongPress: () => _showEmployeeDetails(context, data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Resigned':
        return Colors.orange;
      case 'Terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showEmployeeDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['empName'] ?? 'Employee Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Employee Code', data['empCode']),
              _buildDetailRow('Email', data['email']),
              _buildDetailRow('Department', data['department']),
              _buildDetailRow('Designation', data['designation']),
              _buildDetailRow('Branch', data['branch']),
              _buildDetailRow('Status', data['status']),
              _buildDetailRow('Join Date', data['joinDate']),
              _buildDetailRow('Gender', data['gender']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _viewAttendance(
    BuildContext context,
    String employeeId,
    String? employeeName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeAttendancePage(
          employeeId: employeeId,
          employeeName: employeeName ?? 'Unknown',
        ),
      ),
    );
  }
}
