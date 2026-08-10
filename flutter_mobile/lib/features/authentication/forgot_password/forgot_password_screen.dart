import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1: Email, 2: OTP, 3: Reset Password, 4: Success
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _resetToken;

  // Resend Cooldown Timer (30s)
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Expiration Timer (5 mins)
  int _expirationSeconds = 300;
  Timer? _expirationTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startExpirationTimer() {
    _expirationSeconds = 300;
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_expirationSeconds > 0) {
        setState(() => _expirationSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatExpirationTime() {
    final minutes = (_expirationSeconds / 60).floor();
    final seconds = _expirationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Step 1: Request Password Reset OTP
  Future<void> _handleSendOTP() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      final res = await ApiClient.instance.post('/api/auth/forgot-password/', data: {'email': email});
      if (mounted) {
        final loc = AppLocalizations.of(context);
        final message = res.data['message'] ?? loc.translate('sendOtp');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          _step = 2;
          _isLoading = false;
        });

        _startCooldownTimer();
        _startExpirationTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending code: $e'),
            backgroundColor: AppTheme.emergencyRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Step 2: Verify Reset OTP
  Future<void> _handleVerifyOTP() async {
    if (!_otpFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    setState(() => _isLoading = true);

    try {
      final res = await ApiClient.instance.post('/api/auth/verify-reset-otp/', data: {
        'email': email,
        'otp': otp,
      });

      if (mounted) {
        final token = res.data['reset_token'];
        if (token != null) {
          setState(() {
            _resetToken = token as String;
            _step = 3;
            _isLoading = false;
          });
          _expirationTimer?.cancel();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to verify token.'),
              backgroundColor: AppTheme.emergencyRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid or expired verification code: $e'),
            backgroundColor: AppTheme.emergencyRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Step 3: Reset Password
  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    final loc = AppLocalizations.of(context);
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('passwordMismatch')),
          backgroundColor: AppTheme.emergencyRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiClient.instance.post('/api/auth/reset-password/', data: {
        'reset_token': _resetToken,
        'new_password': newPass,
        'confirm_password': confirmPass,
      });

      if (mounted) {
        setState(() {
          _step = 4;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.data['message'] ?? loc.translate('passwordResetSuccessfulSub')),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset failed: $e'),
            backgroundColor: AppTheme.emergencyRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textWhite),
          onPressed: () {
            if (_step > 1 && _step < 4) {
              setState(() => _step--);
            } else {
              context.go('/login');
            }
          },
        ),
        title: Text(
          loc.translate('forgotPassword'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textWhite),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Hero Icon Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Icon(
                    _step == 4 ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                    size: 38,
                    color: _step == 4 ? AppTheme.successGreen : AppTheme.primaryRed,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Header Titles
              Text(
                _step == 1
                    ? loc.translate('forgotPassword')
                    : _step == 2
                        ? loc.translate('otpVerificationTitle')
                        : _step == 3
                            ? loc.translate('resetPassword')
                            : loc.translate('passwordResetSuccessfulTitle'),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textWhite,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                _step == 1
                    ? loc.translate('enterRegisteredEmailSub')
                    : _step == 2
                        ? '${loc.translate('weSentCodeTo')} ${_emailController.text}'
                        : _step == 3
                            ? loc.translate('createStrongPasswordSub')
                            : loc.translate('passwordResetSuccessfulSub'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // STEP 1: Email Form
              if (_step == 1)
                Form(
                  key: _emailFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: AppTheme.textWhite),
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                        decoration: InputDecoration(
                          labelText: loc.translate('email'),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSendOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  loc.translate('sendOtp'),
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

              // STEP 2: OTP Form
              if (_step == 2)
                Form(
                  key: _otpFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _otpController,
                        style: GoogleFonts.inter(color: AppTheme.textWhite, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        validator: (val) {
                          if (val == null || val.trim().length != 6) {
                            return 'Please enter 6-digit verification code';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText: '000000',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _expirationSeconds > 0
                                ? '${loc.translate('codeExpiresIn')} ${_formatExpirationTime()}'
                                : loc.translate('otpExpired'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _expirationSeconds > 0 ? AppTheme.textSecondary : AppTheme.emergencyRed,
                            ),
                          ),
                          TextButton(
                            onPressed: (_cooldownSeconds > 0 || _isLoading) ? null : _handleSendOTP,
                            child: Text(
                              _cooldownSeconds > 0
                                  ? '${loc.translate('resendCodeIn')} ${_cooldownSeconds}s'
                                  : loc.translate('resendCode'),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _cooldownSeconds > 0 ? AppTheme.textSecondary : AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleVerifyOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  loc.translate('verifyOtp'),
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

              // STEP 3: Reset Password Form
              if (_step == 3)
                Form(
                  key: _resetFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        style: const TextStyle(color: AppTheme.textWhite),
                        validator: Validators.validatePassword,
                        decoration: InputDecoration(
                          labelText: loc.translate('newPassword'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: AppTheme.textWhite),
                        validator: (val) {
                          if (val != _newPasswordController.text) {
                            return loc.translate('passwordMismatch');
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: loc.translate('confirmPasswordLabel'),
                          prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppTheme.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleResetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  loc.translate('resetPassword'),
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

              // STEP 4: Success Actions
              if (_step == 4)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      loc.translate('backToLogin'),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Footer Back Link
              if (_step != 4)
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      loc.translate('backToLogin'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
