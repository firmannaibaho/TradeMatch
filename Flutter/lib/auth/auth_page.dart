import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/main.dart';
import 'package:trade_match/auth/forgot_password.dart';
import 'package:trade_match/services/constants.dart';
import 'package:trade_match/utils/form_validators.dart'; // Form validation

class AuthPage extends StatefulWidget {
  final int initialTabIndex;

  const AuthPage({super.key, this.initialTabIndex = 0});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final SupabaseService _supabaseService = SupabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: GOOGLE_CLIENT_ID,
  );

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.85),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // App Logo/Title
              const Text(
                'TradeMatch',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              // Auth Container
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Tab Bar
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Sign In'),
                          Tab(text: 'Register'),
                        ],
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                      ),
                      // Tab View
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Sign In Form
                            _buildSignInForm(),
                            // Register Form
                            _buildRegisterForm(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _signInFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: _inputDecoration('Email', Icons.email),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: _inputDecoration('Password', Icons.lock),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordPage(),
                  ),
                );
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Full Name', Icons.person),
              validator: FormValidators.validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: _inputDecoration('Email', Icons.email),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: _inputDecoration('Phone Number', Icons.phone),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: _inputDecoration('Password', Icons.lock),
              obscureText: true,
              validator: FormValidators.validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: _inputDecoration('Confirm Password', Icons.lock),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register'),
              ),
            ),
            const SizedBox(height: 16),
            // Divider with OR
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey[600])),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            // Google Sign-In button on Register tab
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleRegister,
                icon: const Icon(Icons.login),
                label: const Text('Sign up with Google'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSignIn() async {
    print("--- Sign In Button Pressed ---");
    if (_signInFormKey.currentState!.validate()) {
      print("Validation Passed. Starting Supabase auth...");
      setState(() => _isLoading = true);
      try {
        final response = await _supabaseService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
        print("Supabase auth successful");

        if (response.user != null) {
          AUTH_USER_ID = response.user!.id;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainPage()),
          );
        }
      } on AuthException catch (e) {
        // Handle Supabase-specific authentication errors
        String errorMessage = 'Sign in failed';

        if (e.message.contains('Invalid login credentials') ||
            e.message.contains('invalid_grant')) {
          errorMessage =
              'Invalid email or password. Please check your credentials.';
        } else if (e.message.contains('Email not confirmed') ||
            e.message.contains('email_not_confirmed')) {
          errorMessage =
              'Please confirm your email before signing in.\n\n'
              'Check your inbox for the confirmation link or contact support if you need help.';
        } else if (e.message.contains('not authenticated') ||
            e.message.contains('User not found')) {
          errorMessage =
              'No account found with this email.\n\n'
              'Please register first or check your email address.';
        } else {
          errorMessage = 'Sign in failed: ${e.message}';
        }

        print("AuthException in _handleSignIn: $errorMessage");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 6),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } catch (e, stackTrace) {
        print("Exception in _handleSignIn: $e\nStack Trace: $stackTrace");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An unexpected error occurred: ${e.toString()}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      print("Validation FAILED. Check text fields for red error messages.");
    }
  }

  void _handleRegister() async {
    if (_registerFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await _supabaseService.signUpWithEmail(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
        );

        if (response.user != null) {
          // Check if email confirmation is required
          if (response.session == null) {
            // User created but email confirmation required
            print(
              "⚠️ Email confirmation required for: ${_emailController.text}",
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '✅ Account created!\n\n'
                    '📧 Please check your email and click the confirmation link to activate your account.\n\n'
                    'After confirming, you can sign in.',
                  ),
                  duration: Duration(seconds: 8),
                  backgroundColor: Colors.blue,
                ),
              );
              // Switch to Sign In tab
              _tabController.animateTo(0);
              // Clear password fields
              _passwordController.clear();
              _confirmPasswordController.clear();
            }
            return;
          }

          // Email confirmation disabled or session created immediately
          AUTH_USER_ID = response.user!.id;

          // Update phone number
          await _supabaseService.updateProfile(phone: _phoneController.text);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainPage()),
            );
          }
        }
      } on AuthException catch (e) {
        // Handle Supabase-specific registration errors
        String errorMessage = 'Registration failed';

        if (e.message.contains('already registered') ||
            e.message.contains('User already registered')) {
          errorMessage =
              'This email is already registered.\n\n'
              'Please use the Sign In tab instead, or use a different email.';
        } else if (e.message.contains('invalid email')) {
          errorMessage =
              'Invalid email address format. Please check and try again.';
        } else if (e.message.contains('Password should be')) {
          errorMessage = 'Password is too weak. ${e.message}';
        } else {
          errorMessage = 'Registration failed: ${e.message}';
        }

        print("AuthException in _handleRegister: $errorMessage");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 6),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } catch (e) {
        print("Exception in _handleRegister: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An unexpected error occurred: ${e.toString()}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      print("Validation FAILED. Check text fields for red error messages.");
    }
  }

  void _handleGoogleSignIn() async {
    print("--- Google Sign In Started ---");
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("User cancelled Google Sign In");
        setState(() => _isLoading = false);
        return; // User canceled
      }
      print("Google User found: ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      print("3. GOOGLE ID TOKEN: $idToken");
      print("4. GOOGLE ACCESS TOKEN: $accessToken");

      if (idToken != null) {
        print("5. Sending ID Token to Supabase...");

        final response = await _supabaseService.signInWithGoogleIdToken(
          idToken,
          accessToken,
        );

        print("6. Supabase auth successful");

        if (response.user != null) {
          AUTH_USER_ID = response.user!.id;

          // Check if phone is required (new Google users)
          final profile = await _supabaseService.getCurrentUserProfile();
          if (profile == null || profile['phone'] == null) {
            final phone = await _showPhoneCollectionDialog();

            if (phone != null && phone.isNotEmpty) {
              try {
                await _supabaseService.updateProfile(phone: phone);
              } catch (e) {
                print('Failed to update phone: $e');
              }
            }
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainPage()),
            );
          }
        }
      } else {
        print("CRITICAL: Google ID Token is NULL");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google authentication failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on AuthException catch (e) {
      // Handle Supabase Google auth errors
      String errorMessage = 'Google sign in failed';

      if (e.message.contains('Email not confirmed')) {
        errorMessage =
            'Please confirm your email before signing in with Google.';
      } else {
        errorMessage = 'Google sign in failed: ${e.message}';
      }

      print("AuthException in _handleGoogleSignIn: $errorMessage");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      print("Exception in _handleGoogleSignIn: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in with Google: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showPhoneCollectionDialog() async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // User must provide phone or skip
      builder: (context) => AlertDialog(
        title: const Text('One More Step'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide your phone number to complete registration. This is required for trade communication.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: _inputDecoration('Phone Number', Icons.phone),
                keyboardType: TextInputType.phone,
                autofocus: true,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Basic phone validation
                    if (value.length < 10) {
                      return 'Phone number must be at least 10 digits';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null), // Skip for now
            child: const Text('Skip (Add Later)'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, phoneController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _handleGoogleRegister() async {
    print("--- Google Register Started ---");
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("User cancelled Google Sign In");
        setState(() => _isLoading = false);
        return; // User canceled
      }
      print("Google User found: ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        print("Sending ID Token to Supabase (Register)...");
        final response = await _supabaseService.signInWithGoogleIdToken(
          idToken,
          null,
        );
        await _handleAuthResponse(response);
      } else {
        print("CRITICAL: Google ID Token is NULL");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google authentication failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on AuthException catch (e) {
      // Handle Supabase Google auth errors
      String errorMessage = 'Google registration failed';

      if (e.message.contains('already registered')) {
        errorMessage =
            'This Google account is already registered.\n\n'
            'Please use the Sign In tab instead.';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage =
            'Please confirm your email before signing in with Google.';
      } else {
        errorMessage = 'Google registration failed: ${e.message}';
      }

      print("AuthException in _handleGoogleRegister: $errorMessage");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      print("Exception in _handleGoogleRegister: $e");
      if (mounted) {
        String errorMessage = e.toString();
        // Clean up exception message
        if (errorMessage.contains("Exception:")) {
          errorMessage = errorMessage.replaceAll("Exception:", "").trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAuthResponse(AuthResponse response) async {
    if (response.user != null) {
      AUTH_USER_ID = response.user!.id;

      // Check if phone is required
      final profile = await _supabaseService.getCurrentUserProfile();
      if (profile == null || profile['phone'] == null) {
        final phone = await _showPhoneCollectionDialog();

        if (phone != null && phone.isNotEmpty) {
          try {
            await _supabaseService.updateProfile(phone: phone);
          } catch (e) {
            print('Failed to update phone: $e');
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      }
    }
  }
}
