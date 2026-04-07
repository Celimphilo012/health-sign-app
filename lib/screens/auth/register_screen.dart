import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedRole = 'patient';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<app_auth.AuthProvider>();
    final success = await auth.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
      role: _selectedRole,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(
        context,
        _selectedRole == 'nurse' ? '/nurse-home' : '/patient-home',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed'),
          backgroundColor: const Color(0xFFCF6679),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<app_auth.AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFE6EDF3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join HealthSign to get started',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 15),
                ),
                const SizedBox(height: 32),

                // Role selector
                const Text(
                  'I am a...',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RoleChip(
                      label: 'Patient',
                      icon: Icons.personal_injury_outlined,
                      selected: _selectedRole == 'patient',
                      color: const Color(0xFF58A6FF),
                      onTap: () => setState(() => _selectedRole = 'patient'),
                    ),
                    const SizedBox(width: 12),
                    _RoleChip(
                      label: 'Nurse / Doctor',
                      icon: Icons.medical_services_outlined,
                      selected: _selectedRole == 'nurse',
                      color: const Color(0xFF3FB950),
                      onTap: () => setState(() => _selectedRole = 'nurse'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name
                CustomTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Name is required';
                    if (v.length < 2) return 'Name too short';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Email
                CustomTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                CustomTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm password
                CustomTextField(
                  label: 'Confirm Password',
                  controller: _confirmCtrl,
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                CustomButton(
                  label: 'Create Account',
                  onPressed: _register,
                  isLoading: isLoading,
                  icon: Icons.person_add_outlined,
                ),
                const SizedBox(height: 20),

                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: Color(0xFF8B949E)),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: Color(0xFF00BFA5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : const Color(0xFF30363D),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? color : const Color(0xFF8B949E), size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : const Color(0xFF8B949E),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
