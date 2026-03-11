import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final turquoise = AppTheme.emerald;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final fillColor = isDark ? AppTheme.darkSurfaceCard : const Color(0xFFF0FDF9);
    final idleIconColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused ? turquoise.withValues(alpha: 0.7) : borderColor,
          width: _isFocused ? 1.5 : 1.0,
        ),
        color: fillColor,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: turquoise.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        obscureText: widget.obscureText,
        onFieldSubmitted: widget.onFieldSubmitted,
        style: GoogleFonts.manrope(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: _isFocused ? turquoise : idleIconColor,
            fontSize: 14,
            fontFamily: 'Manrope',
          ),
          floatingLabelStyle: TextStyle(
            color: _isFocused ? turquoise : idleIconColor,
            fontSize: 12,
            fontFamily: 'Manrope',
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: _isFocused ? turquoise : idleIconColor,
                  size: 20,
                )
              : null,
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          errorStyle: TextStyle(
            color: isDark ? AppTheme.darkRose : AppTheme.rose,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
