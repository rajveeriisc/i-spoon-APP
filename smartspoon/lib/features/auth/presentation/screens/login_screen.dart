import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/features/home/index.dart';
import 'package:smartspoon/main.dart';
import 'package:smartspoon/core/core.dart';
import 'package:smartspoon/core/providers/theme_provider.dart';
import 'package:smartspoon/core/services/email_service.dart';
// Backend services removed

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  // Backend auth removed; using local navigation only

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fb = FirebaseAuthService();
      final result = await fb.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (result['success'] == true) {
        if (result['user'] is Map && result['user']['email'] != null) {
          // refresh user to ensure latest verification status
          try {
            await fb.currentUser?.reload();
          } catch (_) {}
        }
        if (fb.currentUser != null && fb.currentUser!.emailVerified == false) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify your email before logging in.'),
            ),
          );
          return;
        }
        final idToken = result['token'] as String;
        
        // ✅ Exchange Firebase token for backend JWT
        try {
          await AuthService.verifyFirebaseToken(idToken: idToken);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backend sync failed: ${e.toString()}')),
          );
          return;
        }
        
        // Get backend JWT token (not Firebase token)
        final storedJwt = await AuthService.getToken();
        if (storedJwt == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please try again.'),
            ),
          );
          return;
        }
        
        // Get user data from backend
        try {
          final me = await AuthService.getMe();
          if (!mounted) return;
          final userMap = me['user'] as Map<String, dynamic>? ?? me;
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setFromMap(userMap);
           
           // ✨ Send welcome email if user just verified their email
           // This is a fire-and-forget call - don't block login if it fails
           try {
             final email = userMap['email'] as String?;
             final name = userMap['name'] as String?;
             if (email != null) {
               EmailService.sendWelcomeEmail(
                 email: email,
                 name: name ?? email.split('@')[0],
               );
             }
           } catch (emailError) {
             // Silently fail - email is not critical
             debugPrint('Welcome email failed: $emailError');
           }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Welcome back!')));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        throw AuthException(result['message'] as String? ?? 'Login failed');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please try again.')),
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
    return AuthLayout(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildFormContent(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormContent(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.8);

    return [
      const SizedBox(height: 32),
      const AuthFormHeader(
        title: 'Welcome Back!',
        subtitle: 'Log in to your account',
      ),
      AuthTextField(
        controller: _emailController,
        label: 'Email',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        validator: _validateEmail,
      ),
      const SizedBox(height: 16),
      AuthTextField(
        controller: _passwordController,
        label: 'Password',
        icon: Icons.lock_outline,
        obscureText: !_isPasswordVisible,
        autofillHints: const [AutofillHints.password],
        validator: _validatePassword,
        suffix: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordScreen(),
              ),
            );
          },
          child: Text(
            'Forgot Password?',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      AuthPrimaryButton(
        label: 'Login',
        loading: _isLoading,
        onPressed: _isLoading ? null : _login,
      ),
      const SizedBox(height: 16),
      Text(
        'Or continue with',
        style: textTheme.bodyMedium?.copyWith(color: mutedColor),
      ),
      const SizedBox(height: 12),
      SocialButtonsRow(
        onFacebookPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Facebook login coming soon')),
          );
        },
        onGooglePressed: _signInWithGoogle,
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Don't have an account?", style: textTheme.bodyMedium),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SignUpScreen()),
              );
            },
            child: const Text('Sign Up'),
          ),
        ],
      ),
      IconButton(
        icon: Icon(
          Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
              ? Icons.dark_mode
              : Icons.light_mode,
        ),
        onPressed: () {
          Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
        },
      ),
      SizedBox(height: width > 360 ? 32 : 16),
    ];
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final firebaseAuth = FirebaseAuthService();
      final result = await firebaseAuth.signInWithGoogle();

      if (!mounted) return;

      if (result['success'] == true) {
        final idToken = result['token'] as String;
        
        // ✅ Exchange Firebase token for backend JWT
        try {
          await AuthService.verifyFirebaseToken(idToken: idToken);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backend sync failed: ${e.toString()}')),
          );
          return;
        }
        
        // Get backend JWT token
        final storedJwt = await AuthService.getToken();
        if (storedJwt == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please try again.'),
            ),
          );
          return;
        }
         
        // Get user data from backend
        try {
          final me = await AuthService.getMe();
          if (!mounted) return;
          final userMap = me['user'] as Map<String, dynamic>? ?? me;
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setFromMap(userMap);
          
          // Send welcome email
          try {
            final email = userMap['email'] as String?;
            final name = userMap['name'] as String?;
            if (email != null) {
              EmailService.sendWelcomeEmail(
                email: email,
                name: name ?? email.split('@')[0],
              );
            }
          } catch (emailError) {
            debugPrint('Welcome email failed: $emailError');
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
          );
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Welcome!')));

        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Google sign-in failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) => validateEmail(value);

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }
}
