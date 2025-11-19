import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Employee Attendance Page
class EmployeeAttendancePage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeAttendancePage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeAttendancePage> createState() => _EmployeeAttendancePageState();
}

class _EmployeeAttendancePageState extends State<EmployeeAttendancePage> {
  DateTime selectedDate = DateTime.now();
  String selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.employeeName} - Attendance'),
      ),
      body: Column(
        children: [
          // Date Filter
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedPeriod,
                    decoration: InputDecoration(
                      labelText: 'Period',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: ['Today', 'This Week', 'This Month', 'Custom']
                        .map((period) => DropdownMenuItem(
                              value: period,
                              child: Text(period),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPeriod = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Attendance List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('userId', isEqualTo: widget.employeeId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var attendanceRecords = snapshot.data!.docs;

                if (attendanceRecords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No attendance records found'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: attendanceRecords.length,
                  itemBuilder: (context, index) {
                    var record = attendanceRecords[index].data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getAttendanceStatusColor(record['type1']),
                          child: Text(
                            record['day']?.substring(0, 1) ?? 'D',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          '${record['date']} (${record['day']})',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('In: ${record['inTime'] ?? 'N/A'} | Out: ${record['outTime'] ?? 'N/A'}'),
                            SizedBox(height: 4),
                            Text('Total Hours: ${record['totHrs'] ?? 0} | OT: ${record['otHrs'] ?? 0} | BT: ${record['btHrs'] ?? 0}'),
                          ],
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getAttendanceStatusColor(record['type1']),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            record['type1'] ?? 'N/A',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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

  Color _getAttendanceStatusColor(String? status) {
    switch (status) {
      case 'DP':
        return Colors.green;
      case 'ABS':
        return Colors.red;
      case 'HD':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
