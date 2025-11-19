import 'package:vevij/components/imports.dart';

class EmpProfilePage extends StatefulWidget {
  const EmpProfilePage({super.key});

  @override
  State<EmpProfilePage> createState() => _EmpProfilePageState();
}

class _EmpProfilePageState extends State<EmpProfilePage> {
  Future<Map<String, dynamic>> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("No user logged in");
    }

    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = docSnapshot.data() ?? {};
    final bankDetails = userData['bankDetails'] as Map<String, dynamic>? ?? {};

    return {
      'empName': userData['empName'] ?? 'Unknown',
      'empCode': userData['empCode'] ?? 'N/A',
      'email': userData['email'] ?? 'No email',
      'title': userData['title'] ?? '',
      'gender': userData['gender'] ?? 'Not specified',
      'birthDate': userData['birthDate'] ?? 'Not specified',
      'designation': userData['designation'] ?? 'Unknown',
      'department': userData['department'] ?? 'Unknown',
      'branch': userData['branch'] ?? 'Unknown',
      'grade': userData['grade'] ?? 'Unknown',
      'status': userData['status'] ?? 'Unknown',
      'joinDate': userData['joinDate'] ?? 'Unknown',
      'probationDate': userData['probationDate'] ?? 'Unknown',
      'lastWorkingDate': userData['lastWorkingDate'] ?? 'Unknown',
      'lastIncrementDate': userData['lastIncrementDate'] ?? 'Unknown',
      'resignOfferDate': userData['resignOfferDate'] ?? 'Unknown',
      'serviceMonth': userData['serviceMonth'] ?? '0',
      'paymentMode': userData['paymentMode'] ?? 'Unknown',
      'aadharNumber': userData['aadharNumber'] ?? 'Not provided',
      'panNumber': userData['panNumber'] ?? 'Not provided',
      'bankAccountNumber': bankDetails['accountNumber'] ?? 'Not provided',
      'bankName': bankDetails['bankName'] ?? 'Not provided',
      'bankBranch': bankDetails['branch'] ?? 'Not provided',
      'ifscCode': bankDetails['ifscCode'] ?? 'Not provided',
      'createdAt': userData['createdAt'] != null
          ? (userData['createdAt'] as Timestamp).toDate().toString().split(
              ' ',
            )[0]
          : 'Unknown',
      'lastTokenUpdate': userData['lastTokenUpdate'] != null
          ? (userData['lastTokenUpdate'] as Timestamp)
                .toDate()
                .toString()
                .split(' ')[0]
          : 'Unknown',
      'uid': userData['uid'] ?? user.uid,
    };
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Employee Profile"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Picture and Basic Info
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  "${data['title']} ${data['empName']}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Employee Code: ${data['empCode']}",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(data['designation']),
                  backgroundColor: Colors.deepPurple.shade100,
                  labelStyle: const TextStyle(color: Colors.deepPurple),
                ),
                const SizedBox(height: 4),
                Chip(
                  label: Text(data['status']),
                  backgroundColor: data['status'] == 'Active'
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  labelStyle: TextStyle(
                    color: data['status'] == 'Active'
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),

                // Personal Information Section
                _buildSectionHeader("Personal Information"),
                _buildInfoCard(
                  "Email",
                  data['email'],
                  Icons.email,
                  Colors.deepPurple,
                ),
                _buildInfoCard(
                  "Gender",
                  data['gender'],
                  Icons.person,
                  Colors.blue,
                ),
                _buildInfoCard(
                  "Birth Date",
                  data['birthDate'],
                  Icons.cake,
                  Colors.pink,
                ),
                _buildInfoCard(
                  "Aadhar Number",
                  data['aadharNumber'],
                  Icons.credit_card,
                  Colors.orange,
                ),
                _buildInfoCard(
                  "PAN Number",
                  data['panNumber'],
                  Icons.account_box,
                  Colors.indigo,
                ),

                // Employment Information Section
                _buildSectionHeader("Employment Information"),
                _buildInfoCard(
                  "Department",
                  data['department'],
                  Icons.business,
                  Colors.green,
                ),
                _buildInfoCard(
                  "Branch",
                  data['branch'],
                  Icons.location_city,
                  Colors.red,
                ),
                _buildInfoCard(
                  "Grade",
                  data['grade'],
                  Icons.stars,
                  Colors.amber,
                ),
                _buildInfoCard(
                  "Join Date",
                  data['joinDate'],
                  Icons.calendar_today,
                  Colors.purple,
                ),
                _buildInfoCard(
                  "Service Months",
                  data['serviceMonth'],
                  Icons.access_time,
                  Colors.teal,
                ),
                _buildInfoCard(
                  "Payment Mode",
                  data['paymentMode'],
                  Icons.payment,
                  Colors.brown,
                ),

                // Important Dates Section
                _buildSectionHeader("Important Dates"),
                _buildInfoCard(
                  "Probation Date",
                  data['probationDate'],
                  Icons.event,
                  Colors.cyan,
                ),
                _buildInfoCard(
                  "Last Increment Date",
                  data['lastIncrementDate'],
                  Icons.trending_up,
                  Colors.green,
                ),
                _buildInfoCard(
                  "Last Working Date",
                  data['lastWorkingDate'],
                  Icons.work_off,
                  Colors.grey,
                ),
                _buildInfoCard(
                  "Resign Offer Date",
                  data['resignOfferDate'],
                  Icons.exit_to_app,
                  Colors.red,
                ),

                // Bank Details Section
                _buildSectionHeader("Bank Details"),
                _buildInfoCard(
                  "Bank Name",
                  data['bankName'],
                  Icons.account_balance,
                  Colors.deepPurple,
                ),
                _buildInfoCard(
                  "Account Number",
                  data['bankAccountNumber'],
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
                _buildInfoCard(
                  "Bank Branch",
                  data['bankBranch'],
                  Icons.location_on,
                  Colors.red,
                ),
                _buildInfoCard(
                  "IFSC Code",
                  data['ifscCode'],
                  Icons.code,
                  Colors.blue,
                ),

                // System Information Section
                _buildSectionHeader("System Information"),
                _buildInfoCard(
                  "Account Created",
                  data['createdAt'],
                  Icons.date_range,
                  Colors.purple,
                ),
                _buildInfoCard(
                  "Last Token Update",
                  data['lastTokenUpdate'],
                  Icons.update,
                  Colors.indigo,
                ),

                const SizedBox(height: 20),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text(
                      "Sign Out",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await ConfirmDialog.show(
                        context,
                        title: "Sign Out",
                        content: "Are you sure you want to sign out?",
                        actionText: "Sign Out",
                        onAction: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
