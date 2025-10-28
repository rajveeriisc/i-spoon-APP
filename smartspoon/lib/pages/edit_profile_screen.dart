import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/services/auth_service.dart';
import 'package:smartspoon/state/user_provider.dart';
import 'package:smartspoon/features/profile/presentation/widgets/form_section.dart';
import 'package:smartspoon/features/profile/presentation/widgets/header_card.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  final _emergencyContactController = TextEditingController(
    text: 'Mom • +91 98765 67890',
  );

  String _selectedDiet = 'Balanced';
  String _selectedActivity = 'Moderate';
  double _dailyGoal = 200;
  bool _notificationsEnabled = true;
  bool _isSaving = false;

  static const List<String> _dietOptions = [
    'Balanced',
    'Vegan',
    'Low Carb',
    'Keto',
    'Mediterranean',
  ];

  static const List<String> _activityOptions = [
    'Light',
    'Moderate',
    'Active',
    'Athlete',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _hydrateFromProvider();
    _loadProfile();
    // Listen to name changes to update the header
    _nameController.addListener(() {
      setState(() {});
    });
  }

  // Prefill fields from local provider to avoid initial flicker
  void _hydrateFromProvider() {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      if ((user.name ?? '').isNotEmpty) {
        _nameController.text = user.name!;
      }
      if ((user.email ?? '').isNotEmpty) {
        _emailController.text = user.email!;
      }
      if ((user.phone ?? '').isNotEmpty) {
        _phoneController.text = user.phone!;
      }
      if ((user.location ?? '').isNotEmpty) {
        _locationController.text = user.location!;
      }
      if ((user.bio ?? '').isNotEmpty) {
        _bioController.text = user.bio!;
      }
      if ((user.dietType ?? '').isNotEmpty) {
        _selectedDiet = user.dietType!;
      }
      if ((user.activityLevel ?? '').isNotEmpty) {
        _selectedActivity = user.activityLevel!;
      }
      if (user.dailyGoal != null) {
        _dailyGoal = user.dailyGoal!.toDouble();
      }
      if (user.notificationsEnabled != null) {
        _notificationsEnabled = user.notificationsEnabled!;
      }
      if ((user.emergencyContact ?? '').isNotEmpty) {
        _emergencyContactController.text = user.emergencyContact!;
      }
    } catch (_) {
      // Ignore if provider not available here
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) return; // Prevent multiple saves

    setState(() {
      _isSaving = true;
    });

    FocusScope.of(context).unfocus();

    final payload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'location': _locationController.text.trim(),
      'bio': _bioController.text.trim(),
      'diet_type': _selectedDiet,
      'activity_level': _selectedActivity,
      'daily_goal': _dailyGoal.round(),
      'notifications_enabled': _notificationsEnabled,
      'emergency_contact': _emergencyContactController.text.trim(),
    };

    try {
      await AuthService.updateProfile(data: payload).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Update timeout - check backend connection');
        },
      );

      if (!mounted) return;

      // Fetch updated user data and update global state
      try {
        final res = await AuthService.getMe().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Fetch timeout');
          },
        );
        if (res['user'] != null && mounted) {
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setFromMap(res['user'] as Map<String, dynamic>);
        }
      } catch (e) {
        // Silently ignore if fetching fails
      }

      if (!mounted) return;

      // Show success message first
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully',
            style: GoogleFonts.lato(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate back if possible
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final res = await AuthService.getMe();
      final user = res['user'] as Map?;
      if (user == null) return;
      setState(() {
        if (user['name'] is String && (user['name'] as String).isNotEmpty) {
          _nameController.text = user['name'];
        }
        if (user['email'] is String && (user['email'] as String).isNotEmpty) {
          _emailController.text = user['email'];
        }
        if (user['phone'] is String) _phoneController.text = user['phone'];
        if (user['location'] is String) {
          _locationController.text = user['location'];
        }
        if (user['bio'] is String) _bioController.text = user['bio'];
        if (user['diet_type'] is String &&
            (user['diet_type'] as String).isNotEmpty) {
          _selectedDiet = user['diet_type'];
        }
        if (user['activity_level'] is String &&
            (user['activity_level'] as String).isNotEmpty) {
          _selectedActivity = user['activity_level'];
        }
        if (user['daily_goal'] is int) {
          _dailyGoal = (user['daily_goal'] as int).toDouble();
        }
        if (user['notifications_enabled'] is bool) {
          _notificationsEnabled = user['notifications_enabled'];
        }
        if (user['emergency_contact'] is String) {
          _emergencyContactController.text = user['emergency_contact'];
        }
      });
    } catch (_) {
      // silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Save changes',
              icon: const Icon(Icons.check_rounded),
              onPressed: _handleSave,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final rawPadding = constraints.maxWidth * 0.08;
          final horizontalPadding = rawPadding.clamp(16.0, 32.0).toDouble();

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  ProfileHeaderCard(displayName: _nameController.text),
                  const SizedBox(height: 28),
                  FormSection(
                    title: 'Personal Information',
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hintText: 'Enter your full name',
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must have at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        readOnly: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex = RegExp(
                            r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hintText: '+91 90000 00000',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          if (value.replaceAll(RegExp(r'[^0-9]'), '').length <
                              10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        hintText: 'City, Country',
                        keyboardType: TextInputType.streetAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildMultilineField(
                        controller: _bioController,
                        label: 'Bio',
                        hintText: 'Share a little about yourself...',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FormSection(
                    title: 'Health Preferences',
                    children: [
                      _buildDropdownField(
                        label: 'Diet Type',
                        value: _selectedDiet,
                        items: _dietOptions,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedDiet = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Activity Level',
                        value: _selectedActivity,
                        items: _activityOptions,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedActivity = value);
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Daily Bite Goal',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _dailyGoal,
                              min: 80,
                              max: 400,
                              divisions: 16,
                              label: '${_dailyGoal.round()} bites',
                              onChanged: (value) {
                                setState(() => _dailyGoal = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_dailyGoal.round()} bites',
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FormSection(
                    title: 'Safety & Notifications',
                    children: [
                      _buildTextField(
                        controller: _emergencyContactController,
                        label: 'Emergency Contact',
                        hintText: 'Name • Phone number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Real-time bite alerts',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Get reminders when you are eating too fast or skipping meals.',
                          style: GoogleFonts.lato(fontSize: 13),
                        ),
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          setState(() => _notificationsEnabled = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    // Generate a unique key for autofill
    final fieldKey = label.toLowerCase().replaceAll(' ', '_');

    return TextFormField(
      key: Key('edit_profile_$fieldKey'),
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      autofillHints: _getAutofillHints(fieldKey),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: GoogleFonts.lato(color: onSurfaceVariant),
        hintStyle: GoogleFonts.lato(
          color: onSurfaceVariant.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: surfaceColor.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      style: GoogleFonts.lato(fontSize: 15, color: theme.colorScheme.onSurface),
    );
  }

  List<String>? _getAutofillHints(String fieldKey) {
    switch (fieldKey) {
      case 'full_name':
        return [AutofillHints.name];
      case 'email':
        return [AutofillHints.email];
      case 'phone_number':
        return [AutofillHints.telephoneNumber];
      case 'location':
        return [AutofillHints.addressCity];
      case 'emergency_contact':
        return [AutofillHints.telephoneNumber];
      default:
        return null;
    }
  }

  Widget _buildMultilineField({
    required TextEditingController controller,
    required String label,
    required String hintText,
  }) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final fieldKey = label.toLowerCase().replaceAll(' ', '_');

    return TextFormField(
      key: Key('edit_profile_$fieldKey'),
      controller: controller,
      keyboardType: TextInputType.multiline,
      maxLines: 3,
      validator: (value) {
        if (value != null && value.length > 160) {
          return 'Bio should be under 160 characters';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: GoogleFonts.lato(color: onSurfaceVariant),
        hintStyle: GoogleFonts.lato(
          color: onSurfaceVariant.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: surfaceColor.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      style: GoogleFonts.lato(fontSize: 15, color: theme.colorScheme.onSurface),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final fieldKey = label.toLowerCase().replaceAll(' ', '_');

    return DropdownButtonFormField<String>(
      key: Key('edit_profile_dropdown_$fieldKey'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.lato(color: onSurfaceVariant),
        filled: true,
        fillColor: surfaceColor.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      ),
      style: GoogleFonts.lato(fontSize: 15, color: theme.colorScheme.onSurface),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: GoogleFonts.lato(fontSize: 15)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

// header metric moved into ProfileHeaderCard or separate widget if needed
