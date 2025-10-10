import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/pages/signup_screen.dart';
import 'package:smartspoon/pages/forgot_password.dart';
import 'package:smartspoon/pages/home_page.dart';
import 'package:smartspoon/main.dart';
import 'package:smartspoon/validators.dart';
import 'package:smartspoon/services/auth_service.dart';
import 'package:smartspoon/state/user_provider.dart';
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
      await AuthService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // populate user provider
      try {
        final me = await AuthService.getMe();
        if (!mounted) return;
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).setFromMap((me['user'] as Map<String, dynamic>));
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Welcome back!')));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final themeMode = Provider.of<ThemeProvider>(context).themeMode;
    final availableHeight = _calculateAvailableHeight(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _buildResponsiveLayout(
              context,
              size,
              themeMode,
              availableHeight,
              constraints,
            );
          },
        ),
      ),
    );
  }

  double _calculateAvailableHeight(BuildContext context) {
    return MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        MediaQuery.of(context).viewInsets.bottom;
  }

  Widget _buildResponsiveLayout(
    BuildContext context,
    Size size,
    ThemeMode themeMode,
    double availableHeight,
    BoxConstraints constraints,
  ) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight),
        child: Container(
          decoration: _buildGradient(themeMode),
          child: Padding(
            padding: _calculatePadding(size),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buildLoginContent(context, size),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradient(ThemeMode themeMode) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          themeMode == ThemeMode.light
              ? const Color(0xFFBBDEFB)
              : const Color(0xFF1E1E1E),
          themeMode == ThemeMode.light
              ? const Color(0xFFE1BEE7)
              : const Color(0xFF2A2A2A),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  EdgeInsets _calculatePadding(Size size) {
    return EdgeInsets.symmetric(
      horizontal: size.width * 0.08,
      vertical: size.height * 0.02,
    );
  }

  List<Widget> _buildLoginContent(BuildContext context, Size size) {
    return [
      SizedBox(height: size.height * 0.05),
      _buildWelcomeText(size),
      SizedBox(height: size.height * 0.01),
      _buildSubText(size),
      SizedBox(height: size.height * 0.03),
      _buildTextField(
        controller: _emailController,
        hintText: 'Email',
        icon: Icons.email_outlined,
        size: size,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        validator: _validateEmail,
      ),
      SizedBox(height: size.height * 0.02),
      _buildTextField(
        controller: _passwordController,
        hintText: 'Password',
        icon: Icons.lock_outline,
        obscureText: !_isPasswordVisible,
        size: size,
        suffixIcon: _buildPasswordVisibilityToggle(),
        autofillHints: const [AutofillHints.password],
        validator: _validatePassword,
      ),
      // Error handling moved to backend API
      SizedBox(height: size.height * 0.01),
      _buildForgotPassword(context),
      SizedBox(height: size.height * 0.03),
      _buildLoginButton(),
      SizedBox(height: size.height * 0.03),
      _buildOrContinueText(size),
      SizedBox(height: size.height * 0.02),
      _buildSocialButtons(size),
      SizedBox(height: size.height * 0.03),
      _buildSignUpPrompt(context),
      SizedBox(height: size.height * 0.02),
      _buildThemeToggle(context, size),
    ];
  }

  Widget _buildWelcomeText(Size size) {
    return Text(
      'Welcome Back!',
      style: GoogleFonts.lato(
        fontSize: size.width > 360 ? 32.0 : 24.0,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubText(Size size) {
    return Text(
      'Log in to your account',
      style: GoogleFonts.lato(
        fontSize: size.width > 360 ? 16.0 : 12.0,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    );
  }

  String? _validateEmail(String? value) => validateEmail(value);

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Size size,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<String>? autofillHints,
  }) {
    return SizedBox(
      width: size.width * 0.9,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: 0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(
            icon,
            size: size.width > 360 ? 20.0 : 16.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          suffixIcon: suffixIcon,
          hintStyle: GoogleFonts.lato(
            fontSize: size.width > 360 ? 14.0 : 12.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        style: GoogleFonts.lato(
          fontSize: size.width > 360 ? 14.0 : 12.0,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordVisibilityToggle() {
    return IconButton(
      icon: Icon(
        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: MediaQuery.of(context).size.width > 360 ? 20.0 : 16.0,
      ),
      onPressed: () {
        setState(() {
          _isPasswordVisible = !_isPasswordVisible;
        });
      },
    );
  }

  Widget _buildForgotPassword(BuildContext context) {
    return Align(
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
          style: GoogleFonts.lato(
            fontSize: MediaQuery.of(context).size.width > 360 ? 14.0 : 12.0,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.of(context).size.height * 0.02,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              )
            : Text(
                'Login',
                style: GoogleFonts.lato(
                  fontSize: MediaQuery.of(context).size.width > 360
                      ? 16.0
                      : 14.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildOrContinueText(Size size) {
    return Text(
      'Or continue with',
      style: GoogleFonts.lato(
        fontSize: size.width > 360 ? 14.0 : 12.0,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSocialButtons(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(Icons.facebook, size, () {
          // Add Facebook login logic
        }),
        SizedBox(width: size.width * 0.1),
        _buildSocialButton(Icons.g_mobiledata, size, () {
          // Add Google login logic
        }),
      ],
    );
  }

  Widget _buildSocialButton(IconData icon, Size size, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface,
        size: icon == Icons.g_mobiledata
            ? (size.width > 360 ? 36.0 : 28.0)
            : (size.width > 360 ? 28.0 : 24.0),
      ),
      tooltip: icon == Icons.facebook
          ? 'Login with Facebook'
          : 'Login with Google',
    );
  }

  Widget _buildSignUpPrompt(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: GoogleFonts.lato(
            fontSize: MediaQuery.of(context).size.width > 360 ? 14.0 : 12.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            );
          },
          child: Text(
            'Sign Up',
            style: GoogleFonts.lato(
              fontSize: MediaQuery.of(context).size.width > 360 ? 14.0 : 12.0,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggle(BuildContext context, Size size) {
    return IconButton(
      icon: Icon(
        Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
            ? Icons.dark_mode
            : Icons.light_mode,
        size: size.width > 360 ? 24.0 : 20.0,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: () {
        Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
      },
    );
  }
}
