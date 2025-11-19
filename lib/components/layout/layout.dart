import 'package:vevij/components/imports.dart';
import 'menu_page.dart';
class EmployeeLayout extends StatefulWidget {
  const EmployeeLayout({super.key});
  @override
  EmployeeLayoutState createState() => EmployeeLayoutState();
}

class EmployeeLayoutState extends State<EmployeeLayout> {
  int _selectedIndex = 0;
  String userName = "";
  String role = "";
  String userId = "";
  Map<String, dynamic>? employeeData;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  void initState() {
    super.initState();
    _setUserData();
  }
  Future<void> _setUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        userId = currentUser.uid;
        DocumentSnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (mounted) {
          setState(() {
            employeeData = snapshot.data() as Map<String, dynamic>?;
            userName = employeeData?['empName'] ?? 'Employee';
            role = employeeData?['designation'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MenuPage(userId: userId , userName: userName,employeeData: employeeData ?? {},),
      EmpProfilePage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items:  [
         BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          
        ],
      ),
    );
  }
}
