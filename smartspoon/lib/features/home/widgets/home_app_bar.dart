import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/main.dart';
import 'package:smartspoon/state/user_provider.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    required this.baseTitle,
    this.personalizeGreeting = false,
    required this.onAddDevice,
  });

  final String baseTitle;
  final bool personalizeGreeting;
  final VoidCallback onAddDevice;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = _iconSize(screenWidth);

    return AppBar(
      toolbarHeight: _toolbarHeight(screenWidth),
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _horizontalPadding(screenWidth),
        ),
        child: Consumer<UserProvider>(
          builder: (_, user, __) => Text(
            personalizeGreeting
                ? _personalizedTitle(baseTitle, user.name)
                : baseTitle,
            style: GoogleFonts.lato(
              fontSize: _titleFontSize(screenWidth),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_none, size: iconSize),
          tooltip: 'Notifications',
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.nightlight_round,
            size: iconSize,
          ),
          tooltip: 'Toggle theme',
          onPressed: themeProvider.toggleTheme,
        ),
        IconButton(
          icon: Icon(Icons.add, size: iconSize),
          tooltip: 'Add Device',
          onPressed: onAddDevice,
        ),
      ],
    );
  }

  double _toolbarHeight(double width) {
    if (width < 360) return 56;
    if (width < 720) return 64;
    return 72;
  }

  double _titleFontSize(double width) {
    if (width < 360) return 20;
    if (width < 480) return 24;
    if (width < 720) return 26;
    return 28;
  }

  double _iconSize(double width) {
    if (width < 360) return 22;
    if (width < 480) return 24;
    if (width < 720) return 26;
    return 28;
  }

  double _horizontalPadding(double width) {
    if (width < 360) return 12;
    if (width < 720) return 16;
    return 24;
  }

  String _personalizedTitle(String baseTitle, String? fullName) {
    final name = fullName?.trim() ?? '';
    if (name.isEmpty) return baseTitle;
    final firstName = name.split(RegExp(r'\s+')).first;
    return '$baseTitle, $firstName';
  }
}
