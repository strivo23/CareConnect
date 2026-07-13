import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2F9), // Light background matching mockup
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              // App Brand Logo & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB), // Blue background for heartbeat logo matching original mockup icon
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.monitor_heart_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'CareConnect',
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Stay Safe. Stay Connected.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Family Illustration Card
              Center(
                child: Container(
                  height: 220,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Image.asset(
                    'assets/images/family_illustration.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primarySoft, Colors.white],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Icon(Icons.people_alt_rounded, size: 72, color: AppTheme.primary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // White Card Rising
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0F0F172A),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Welcome Back 👋',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Login to continue to your account',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Email Field
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Email or Phone',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Password Field
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: Validators.password,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8)),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Remember Me & Forgot Password
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (value) => setState(() => _rememberMe = value ?? true),
                              activeColor: AppTheme.primary,
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember Me',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF475569),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF2563EB), // Match original blue link color in mockup
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Premium Red Gradient Login Button
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3B30), Color(0xFFB80000)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  final auth = context.read<AuthProvider>();
                                  final router = GoRouter.of(context);
                                  final messenger = ScaffoldMessenger.of(context);
                                  final success = await auth.login(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                  );
                                  if (!mounted) return;
                                  if (success) {
                                    router.go('/home');
                                  } else if (auth.errorMessage != null) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(auth.errorMessage!)),
                                    );
                                  }
                                },
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.login_rounded, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Login',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Or continue with Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Social Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _socialButton(
                              iconWidget: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                height: 20,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 28),
                              ),
                              label: 'Google',
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _socialButton(
                              iconWidget: const Icon(Icons.apple_rounded, color: Colors.black, size: 22),
                              label: 'Apple',
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.go('/register'),
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF2563EB), // Match original mockup link color
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
