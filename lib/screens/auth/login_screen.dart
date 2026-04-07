import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../utils/helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      AppHelpers.showSnackbar(
        context,
        'Welcome back, ${auth.user?.name ?? ''}!',
        isSuccess: true,
      );
      final role = auth.user?.role;
      Navigator.pushReplacementNamed(
        context,
        role == UserRole.nurse ? '/nurse-home' : '/patient-home',
      );
    } else {
      AppHelpers.showSnackbar(
        context,
        auth.errorMessage ?? 'Login failed. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),

                  // Logo
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF00BFA5).withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BFA5).withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sign_language,
                        size: 48,
                        color: Color(0xFF00BFA5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to your HealthSign account',
                    style: TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 40),

                  CustomTextField(
                    label: 'Email',
                    controller: _emailCtrl,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Password',
                    controller: _passCtrl,
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 36),

                  CustomButton(
                    label: 'Sign In',
                    onPressed: _login,
                    isLoading: isLoading,
                    icon: Icons.login_rounded,
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Color(0xFF30363D)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'New to HealthSign?',
                          style: TextStyle(
                            color: const Color(0xFF8B949E).withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Color(0xFF30363D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      icon: const Icon(
                        Icons.person_add_outlined,
                        size: 18,
                        color: Color(0xFF00BFA5),
                      ),
                      label: const Text(
                        'Create an Account',
                        style: TextStyle(
                          color: Color(0xFF00BFA5),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF00BFA5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Version
                  Center(
                    child: Text(
                      'HealthSign v1.0.0',
                      style: TextStyle(
                        color: const Color(0xFF8B949E).withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
