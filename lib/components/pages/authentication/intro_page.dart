import 'package:vevij/components/imports.dart';


class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // Wait for splash screen effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Initialize auth service
      AuthService().initialize();

      // Check if session is valid
      final isSessionValid = await AuthService().isSessionValid();

      if (isSessionValid) {
        // Get cached user data
        final userData = await AuthService().getCachedUserData();
        final role = userData['userRole'];

        if (role != null && role.isNotEmpty) {
          // Navigate based on role
          _navigateByRole(role);
          return;
        }
      }

      // Not logged in or invalid session
      _navigateToLogin();
    } catch (e) {
      // Error occurred, go to login
      print('Auto-login error: $e');
      _navigateToLogin();
    }
  }

  void _navigateByRole(String role) {
    if (!mounted) return;
     Navigator.pushReplacementNamed(context, '/layout');
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 150, width: 150),
            const SizedBox(height: 20),
            Image.asset(
              'assets/images/dooropening.png',
              height: 250,
              width: 250,
            ),
            const Text(
              'Welcome to VEVIJ!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
