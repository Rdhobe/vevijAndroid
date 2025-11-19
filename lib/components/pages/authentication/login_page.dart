// import 'package:firebase_core/firebase_core.dart';
import 'package:vevij/components/imports.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;
  List<Map<String, String>> _savedProfiles = [];
  String? _selectedProfile;

  @override
  void initState() {
    super.initState();
    _loadSavedProfiles();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProfilesJson = prefs.getStringList('saved_profiles') ?? [];
    final lastUsedEmail = prefs.getString('last_used_email');

    setState(() {
      _savedProfiles = savedProfilesJson.map((profile) {
        final parts = profile.split('|||');
        return {
          'email': parts[0],
          'displayName': parts.length > 1 ? parts[1] : parts[0].split('@')[0],
        };
      }).toList();

      if (lastUsedEmail != null) {
        _emailController.text = lastUsedEmail;
        _selectedProfile = lastUsedEmail;
      }
    });
  }

  Future<void> _saveCredentials(String email) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Save remember me preference
  await prefs.setBool('remember_me', _rememberMe);
  
  if (!_rememberMe) {
    // If not remembering, clear saved profiles
    await prefs.remove('saved_profiles');
    await prefs.remove('last_used_email');
    return;
  }

  final displayName = email.split('@')[0];
  final profileString = '$email|||$displayName';

  List<String> savedProfiles = prefs.getStringList('saved_profiles') ?? [];
  savedProfiles.removeWhere((profile) => profile.startsWith('$email|||'));
  savedProfiles.insert(0, profileString);

  // Keep only last 5 profiles
  if (savedProfiles.length > 5) {
    savedProfiles = savedProfiles.take(5).toList();
  }

  await prefs.setStringList('saved_profiles', savedProfiles);
  await prefs.setString('last_used_email', email);
}
  Future<void> _removeProfile(String email) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedProfiles = prefs.getStringList('saved_profiles') ?? [];
    savedProfiles.removeWhere((profile) => profile.startsWith('$email|||'));
    await prefs.setStringList('saved_profiles', savedProfiles);

    setState(() {
      _savedProfiles.removeWhere((profile) => profile['email'] == email);
      if (_selectedProfile == email) {
        _selectedProfile = null;
        _emailController.clear();
      }
    });
  }
  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _selectProfile(String email) {
    setState(() {
      _selectedProfile = email;
      _emailController.text = email;
      _passwordController.clear();
    });
  }

  Future<void> _directLogin(String email) async {
    final password = await PasswordDialog.show(context, email);
    if (password != null && password.isNotEmpty) {
      await _performLogin(email, password);
    }
  }

  Future<void> _performLogin(String email, String password) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await ErrorDialog.show(
          context,
          title: 'Location Permission Required',
          message: 'Location permission is required for continuous monitoring. Please enable it in your device settings.',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
    
      // Sign in using email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Save credentials if remember me is checked
      if (_rememberMe) {
        await _saveCredentials(email.trim());
      }

      // Check role and navigate
      final user = FirebaseAuth.instance.currentUser;
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      final role = userData.data()?['designation'];
      // Initialize notifications after successful login
      await NotificationService.initialize();

      if (role == null) {
        await ErrorDialog.show(
          context,
          title: 'Access Denied',
          message: 'Your account role is not recognized. Please contact your administrator.',
        );
        return;
      }
      if (role != null && role.isNotEmpty) {
        Navigator.pushReplacementNamed(context, '/layout');
      }

    } on FirebaseAuthException catch (e) {
      await ErrorDialog.show(
  context,
  title: 'Sign In Failed',
  message: _getFirebaseErrorMessage(e.code),
);
    } catch (e) {
      await ErrorDialog.show(
        context,
        title: 'Unexpected Error',
        message: 'An unexpected error occurred. Please try again later.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/images/logo.png',
                          height: 50,
                          width: 50,
                        ),
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back! Please sign in to your account.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Saved Profiles Section
                        if (_savedProfiles.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Saved Profiles',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Text(
                                'Tap to login • Long press to select',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _savedProfiles.length,
                              itemBuilder: (context, index) {
                                final profile = _savedProfiles[index];
                                final email = profile['email']!;
                                final displayName = profile['displayName']!;
                                final isSelected = _selectedProfile == email;

                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: () => _directLogin(email),
                                    onLongPress: () => _selectProfile(email),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                  : Colors.grey.shade300,
                                              width: isSelected ? 3 : 2,
                                            ),
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                      .withOpacity(0.1)
                                                : Colors.grey.shade100,
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Text(
                                                  displayName[0].toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected
                                                        ? Theme.of(
                                                            context,
                                                          ).primaryColor
                                                        : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: -2,
                                                right: -2,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _removeProfile(email),
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration:
                                                        const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: Colors.red,
                                                        ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey.shade600,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        // Remember Me Checkbox
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: Theme.of(context).primaryColor,
                            ),
                            Text(
                              'Remember me',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Sign In Button
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    await _performLogin(
                                      _emailController.text.trim(),
                                      _passwordController.text.trim(),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
