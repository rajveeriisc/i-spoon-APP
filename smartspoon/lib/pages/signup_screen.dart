import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/pages/login_screen.dart';
import 'package:smartspoon/pages/home_page.dart';
import 'package:smartspoon/validators.dart';
import 'package:smartspoon/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/state/user_provider.dart';

// SignUpScreen widget provides a form for users to create a new account
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();
      await AuthService.signup(
        email: email,
        password: password,
        name: name.isNotEmpty ? name : null,
      );
      // Auto-login after successful signup
      await AuthService.login(email: email, password: password);
      try {
        final me = await AuthService.getMe();
        if (!mounted) return;
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).setFromMap((me['user'] as Map<String, dynamic>));
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup successful. Welcome!')),
      );
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup failed. Please try again.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final padding =
              screenWidth * 0.08; // Responsive padding (8% of screen width)

          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(padding),
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(
                  context,
                ).size.height, // Ensure full height
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: padding * 2), // Top spacing
                      _buildHeader(screenWidth),
                      SizedBox(height: padding * 1.5),
                      _buildTextField(
                        controller: _nameController,
                        hintText: 'Full Name',
                        icon: Icons.person_outline,
                        validator: _validateName,
                        screenWidth: screenWidth,
                      ),
                      SizedBox(height: padding * 0.5),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'Email',
                        icon: Icons.email_outlined,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        screenWidth: screenWidth,
                      ),
                      SizedBox(height: padding * 0.5),
                      _buildTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: validatePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        screenWidth: screenWidth,
                      ),
                      SizedBox(height: padding * 0.5),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) => validateConfirmPassword(
                          value,
                          _passwordController.text,
                        ),
                        autofillHints: const [AutofillHints.password],
                        screenWidth: screenWidth,
                      ),
                      // Error handling moved to backend API
                      SizedBox(height: padding * 0.75),
                      _buildSignUpButton(screenWidth),
                      SizedBox(height: padding),
                      _buildLoginPrompt(context, screenWidth),
                      SizedBox(height: padding),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Builds the header with title and subtitle
  Widget _buildHeader(double screenWidth) {
    return Column(
      children: [
        Text(
          'Create Account',
          style: GoogleFonts.lato(
            fontSize: screenWidth * 0.1,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: screenWidth * 0.025),
        Text(
          'Start your journey with us',
          style: GoogleFonts.lato(
            fontSize: screenWidth * 0.045,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // Builds a reusable text field with validation
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    required double screenWidth,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, size: screenWidth * 0.06),
        contentPadding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.04,
          horizontal: screenWidth * 0.04,
        ),
        errorStyle: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: screenWidth * 0.035,
        ),
      ),
      style: TextStyle(
        fontSize: screenWidth * 0.04,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      validator: validator,
    );
  }

  // Builds the Sign Up button
  Widget _buildSignUpButton(double screenWidth) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSignUp,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.2,
          vertical: screenWidth * 0.04,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      child: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.purple.shade700,
              ),
            )
          : Text(
              'Sign Up',
              style: GoogleFonts.lato(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  // Builds the login prompt with navigation to LoginScreen
  Widget _buildLoginPrompt(BuildContext context, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.04),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: Text(
            'Log In',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.04,
            ),
          ),
        ),
      ],
    );
  }

  // Validates the full name field
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  // Validates the email field
  String? _validateEmail(String? value) {
    return validateEmail(value);
  }
}
