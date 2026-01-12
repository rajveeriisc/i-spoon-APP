import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/auth/providers/user_provider.dart';
import 'package:smartspoon/features/auth/domain/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for 9 Fields
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  
  // Selection / Slider values
  String _gender = 'Male';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false);
    
    _nameCtrl = TextEditingController(text: user.name);
    _emailCtrl = TextEditingController(text: user.email);
    _phoneCtrl = TextEditingController(text: ''); // Phone missing in User model currently
    _locationCtrl = TextEditingController(text: ''); // Location missing
    _ageCtrl = TextEditingController(text: user.age?.toString() ?? '');
    _heightCtrl = TextEditingController(text: user.height?.toString() ?? '');
    _weightCtrl = TextEditingController(text: user.weight?.toString() ?? '');
    
    _gender = (user.gender != null && user.gender!.isNotEmpty) ? user.gender! : 'Male';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final updates = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        // 'phone': _phoneCtrl.text.trim(), // API dependent
        // 'location': _locationCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text) ?? 0,
        'gender': _gender,
        'height': double.tryParse(_heightCtrl.text) ?? 0.0,
        'weight': double.tryParse(_weightCtrl.text) ?? 0.0,
      };
      
      final res = await AuthService.updateProfile(data: updates);
      
      if (mounted) {
        final u = res['user'] as Map<String, dynamic>?;
        if (u != null) {
          Provider.of<UserProvider>(context, listen: false).setFromMap(u);
        }
        Navigator.pop(context); // Close modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Profile', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Personal Info'),
                    _buildTextField('Full Name', _nameCtrl, Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField('Email', _emailCtrl, Icons.email_outlined, enabled: false), // Usually immutable
                    const SizedBox(height: 16),
                    _buildTextField('Phone', _phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField('Location', _locationCtrl, Icons.location_on_outlined),
                    
                    const SizedBox(height: 24),
                    _buildLabel('Physical Stats'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Age', _ageCtrl, Icons.cake_outlined, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: _inputDecoration('Gender', Icons.wc),
                            items: ['Male', 'Female', 'Other']
                                .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.outfit())))
                                .toList(),
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Height (cm)', _heightCtrl, Icons.height, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        // Weight field removed
                        Expanded(child: Container()), 
                      ],
                    ),
                    
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A896),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text('Save Changes', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF00A896),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, 
      {bool enabled = true, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(),
      decoration: _inputDecoration(label, icon),
      validator: (val) {
        if (label == 'Full Name' && (val == null || val.isEmpty)) return 'Required';
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00A896), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
