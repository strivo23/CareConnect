import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/society_repository.dart';
import '../../../models/society_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _flatController = TextEditingController();

  final _societyRepository = SocietyRepository();

  String _role = 'RESIDENT';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;

  // Society dropdown data
  List<SocietyModel> _societies = [];
  List<BlockTowerModel> _blocks = [];
  List<FlatModel> _flats = [];

  int? _selectedSocietyId;
  int? _selectedBlockId;
  int? _selectedFlatId;
  bool _isLoadingSocieties = false;
  bool _isLoadingBlocks = false;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
    _flatController.addListener(_onFlatChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _flatController.dispose();
    super.dispose();
  }

  Future<void> _loadSocieties() async {
    setState(() => _isLoadingSocieties = true);
    try {
      final list = await _societyRepository.fetchSocieties();
      setState(() => _societies = list);
    } catch (e) {
      debugPrint('Error loading societies: $e');
    } finally {
      setState(() => _isLoadingSocieties = false);
    }
  }

  Future<void> _loadBlocks(int societyId) async {
    setState(() {
      _isLoadingBlocks = true;
      _blocks = [];
      _flats = [];
      _selectedBlockId = null;
      _selectedFlatId = null;
    });
    try {
      final list = await _societyRepository.fetchBlocks(societyId);
      setState(() => _blocks = list);
    } catch (e) {
      debugPrint('Error loading blocks: $e');
    } finally {
      setState(() => _isLoadingBlocks = false);
    }
  }

  Future<void> _loadFlats(int societyId, int blockId) async {
    try {
      final list = await _societyRepository.fetchFlats(societyId: societyId, blockId: blockId);
      setState(() {
        _flats = list;
      });
      _onFlatChanged(); // Recalculate flat ID match
    } catch (e) {
      debugPrint('Error loading flats: $e');
    }
  }

  void _onFlatChanged() {
    final text = _flatController.text.trim();
    if (text.isEmpty || _flats.isEmpty) {
      _selectedFlatId = null;
      return;
    }
    final match = _flats.firstWhere(
      (f) => f.flatNumber.toLowerCase() == text.toLowerCase(),
      orElse: () => FlatModel(id: -1, blockId: -1, flatNumber: '', floor: 0, type: '', occupied: false, blockName: '', societyName: '', societyId: -1),
    );
    if (match.id != -1) {
      _selectedFlatId = match.id;
    } else {
      _selectedFlatId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2F9), // Match login background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    // Back circular button
                    InkWell(
                      onTap: () => context.go('/login'),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: SizedBox(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Main Title Block
              Center(
                child: Text(
                  'Create Account',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Join CareConnect and stay connected',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Role selection row cards
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _roleCard('Resident', 'RESIDENT', Icons.person_rounded, Colors.blue),
                    const SizedBox(width: 12),
                    _roleCard('Guardian', 'GUARDIAN', Icons.supervised_user_circle_rounded, Colors.deepPurple),
                    const SizedBox(width: 12),
                    _roleCard('Volunteer', 'VOLENTEER', Icons.group_rounded, Colors.green),
                    const SizedBox(width: 12),
                    _roleCard('Security', 'SECURITY', Icons.shield_rounded, Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Form Content in White Rising Card
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
                      // Full Name
                      _formField(
                        controller: _nameController,
                        hint: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => Validators.requiredField(v, label: 'Full name'),
                      ),
                      const SizedBox(height: 16),
                      // Email Address
                      _formField(
                        controller: _emailController,
                        hint: 'Email Address',
                        icon: Icons.mail_outline_rounded,
                        validator: Validators.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      // Phone Number
                      _formField(
                        controller: _phoneController,
                        hint: 'Phone Number',
                        icon: Icons.phone_outlined,
                        validator: (v) => Validators.requiredField(v, label: 'Phone number'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      // Password
                      _formField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        validator: Validators.password,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password
                      _formField(
                        controller: _confirmPasswordController,
                        hint: 'Confirm Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirmPassword,
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return Validators.requiredField(v, label: 'Confirm password');
                        },
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Select Society Dropdown
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
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedSocietyId,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                          hint: _isLoadingSocieties
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Select Society', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.apartment_rounded, color: Color(0xFF94A3B8)),
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
                          ),
                          items: _societies.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(s.name),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id != null) {
                              setState(() => _selectedSocietyId = id);
                              _loadBlocks(id);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Block/Tower Dropdown
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
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedBlockId,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                          hint: _isLoadingBlocks
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Block / Tower (Optional)', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.domain_rounded, color: Color(0xFF94A3B8)),
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
                          ),
                          items: _blocks.map((b) {
                            return DropdownMenuItem<int>(
                              value: b.id,
                              child: Text(b.name),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id != null && _selectedSocietyId != null) {
                              setState(() => _selectedBlockId = id);
                              _loadFlats(_selectedSocietyId!, id);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Flat Number
                      _formField(
                        controller: _flatController,
                        hint: 'Flat Number (Optional)',
                        icon: Icons.home_outlined,
                        validator: null,
                      ),
                      const SizedBox(height: 12),
                      // Agree Terms Checkbox
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _agreeTerms,
                              onChanged: (v) => setState(() => _agreeTerms = v ?? true),
                              activeColor: AppTheme.primary,
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF475569),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF2563EB),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Create Account Premium Red Gradient Button
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
                          onPressed: authProvider.isLoading || !_agreeTerms
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  final auth = context.read<AuthProvider>();
                                  final router = GoRouter.of(context);
                                  final messenger = ScaffoldMessenger.of(context);
                                  final success = await auth.register(
                                    name: _nameController.text.trim(),
                                    email: _emailController.text.trim(),
                                    phoneNumber: _phoneController.text.trim(),
                                    password: _passwordController.text,
                                    role: _role,
                                    societyId: _selectedSocietyId,
                                    blockId: _selectedBlockId,
                                    flatId: _selectedFlatId,
                                  );
                                  if (!mounted) return;
                                  if (success) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Registration successful. Please login.')),
                                    );
                                    router.go('/login');
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
                                    const Icon(Icons.person_add_rounded, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Create Account',
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
                      // Already have account Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Login',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF2563EB), // Blue link matching original mockup login link
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

  Widget _roleCard(String label, String roleValue, IconData icon, Color colorAccent) {
    final isSelected = _role == roleValue;
    return GestureDetector(
      onTap: () => setState(() => _role = roleValue),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 82,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                      : const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: colorAccent, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
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
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
          suffixIcon: suffixIcon,
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
    );
  }
}
