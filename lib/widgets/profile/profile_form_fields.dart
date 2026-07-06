// ============================================================================
// lib/widgets/profile/profile_form_fields.dart
// ============================================================================
import 'package:flutter/material.dart';

class ProfileFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  const ProfileFormFields({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
  });

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.orange.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInputField(
          label: 'Full Name',
          icon: Icons.person,
          controller: nameController,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter your name' : null,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Email',
          icon: Icons.email,
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Phone Number',
          icon: Icons.phone,
          controller: phoneController,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter your phone number';
            }
            if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
              return 'Enter a valid phone number';
            }
            return null;
          },
        ),
      ],
    );
  }
}
