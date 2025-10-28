import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/auth/widgets/auth_form_header.dart';
import 'package:smartspoon/features/auth/widgets/auth_layout.dart';
import 'package:smartspoon/features/auth/widgets/auth_primary_button.dart';
import 'package:smartspoon/features/auth/widgets/auth_text_field.dart';
import 'package:smartspoon/pages/login_screen.dart';
import 'package:smartspoon/pages/home_page.dart';
import 'package:smartspoon/validators.dart';
import 'package:smartspoon/services/auth_service.dart';
import 'package:smartspoon/services/firebase_auth_service.dart';
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

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();

      final fb = FirebaseAuthService();
      final result = await fb.signUpWithEmail(
        email: email,
        password: password,
        name: name.isNotEmpty ? name : email.split('@').first,
      );

      if (result['success'] == true) {
        if (result['emailVerified'] == false) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent. Please verify your email, then log in.',
              ),
            ),
          );
          return;
        }

        final idToken = result['token'] as String;
        await AuthService.verifyFirebaseToken(idToken: idToken);
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
      } else {
        throw AuthException(result['message'] as String? ?? 'Signup failed');
      }
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return AuthLayout(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
              const AuthFormHeader(
                title: 'Create Account',
                subtitle: 'Start your journey with us',
              ),
              AuthTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                icon: Icons.lock_outline,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                validator: (value) =>
                    validateConfirmPassword(value, _passwordController.text),
              ),

              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: 'Sign Up',
                loading: _isLoading,
                onPressed: _isLoading ? null : _handleSignUp,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text('Log In'),
                  ),
                ],
              ),
              SizedBox(height: width > 360 ? 32 : 16),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    return validateEmail(value);
  }
}
