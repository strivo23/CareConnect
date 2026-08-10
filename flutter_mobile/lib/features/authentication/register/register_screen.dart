import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/society_repository.dart';
import '../../../services/contacts_repository.dart';
import '../../../models/society_model.dart';
import '../../../models/contact_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0; // 0: Personal, 1: Role, 2: Confirmation
  final _formKey0 = GlobalKey<FormState>();
  final _formKey1 = GlobalKey<FormState>();

  // Step 0 Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 1 Role Specific Controllers
  String _role = 'RESIDENT';
  
  // Resident fields
  int? _selectedSocietyId;
  int? _selectedBlockId;
  int? _selectedFlatId;
  final _flatController = TextEditingController();

  // Guardian fields
  int? _selectedRelationshipId;

  // Volunteer fields
  final _skillsController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _serviceAreaController = TextEditingController();

  // Security fields
  final _shiftController = TextEditingController();
  final _employeeIdController = TextEditingController();
  int? _selectedAssignedSocietyId;

  final _societyRepository = SocietyRepository();
  final _contactsRepository = ContactsRepository();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;

  // Dropdown list data
  List<SocietyModel> _societies = [];
  List<BlockTowerModel> _blocks = [];
  List<FlatModel> _flats = [];
  List<RelationshipModel> _relationships = [];

  bool _isLoadingSocieties = false;
  bool _isLoadingBlocks = false;
  bool _isLoadingRelationships = false;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
    _loadRelationships();
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
    _skillsController.dispose();
    _availabilityController.dispose();
    _serviceAreaController.dispose();
    _shiftController.dispose();
    _employeeIdController.dispose();
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

  Future<void> _loadRelationships() async {
    setState(() => _isLoadingRelationships = true);
    try {
      final list = await _contactsRepository.fetchRelationships();
      if (list.isNotEmpty) {
        setState(() => _relationships = list);
      } else {
        _setFallbackRelationships();
      }
    } catch (e) {
      debugPrint('Error loading relationships: $e');
      _setFallbackRelationships();
    } finally {
      setState(() => _isLoadingRelationships = false);
    }
  }

  void _setFallbackRelationships() {
    setState(() {
      _relationships = [
        RelationshipModel(id: 1, name: 'Family'),
        RelationshipModel(id: 2, name: 'Friends'),
        RelationshipModel(id: 3, name: 'Neighbours'),
        RelationshipModel(id: 4, name: 'Other'),
      ];
    });
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
      _onFlatChanged();
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

  Future<void> _submitRegistration() async {
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
      relationship: _selectedRelationshipId,
      skills: _skillsController.text.trim(),
      availability: _availabilityController.text.trim(),
      serviceArea: _serviceAreaController.text.trim(),
      shift: _shiftController.text.trim(),
      employeeId: _employeeIdController.text.trim(),
      assignedSocietyId: _selectedAssignedSocietyId,
    );

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Registration successful. OTP sent to ${_emailController.text.trim()}'),
          backgroundColor: AppTheme.success,
        ),
      );
      router.pushReplacement('/otp-verify', extra: {'email': _emailController.text.trim()});
    } else if (auth.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey0.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_formKey1.currentState!.validate()) {
        setState(() => _currentStep = 2);
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFEDF2F9),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  InkWell(
                    onTap: _currentStep > 0 ? _prevStep : () => context.go('/login'),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black26 : const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Create Account',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _currentStep == 0
                    ? AppLocalizations.of(context).translate('step1PersonalDetails')
                    : _currentStep == 1
                        ? AppLocalizations.of(context).translate('step2RoleConfig')
                        : AppLocalizations.of(context).translate('step3ConfirmDetails'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Steps progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                children: [
                  _progressIndicator(0),
                  _progressLine(),
                  _progressIndicator(1),
                  _progressLine(),
                  _progressIndicator(2),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black38 : const Color(0x0F0F172A),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: SingleChildScrollView(
                  child: _buildStepBody(authProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressIndicator(int step) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isDone ? AppTheme.success : (isActive ? AppTheme.primary : (isDark ? Colors.white12 : const Color(0xFFCBD5E1))),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : Text(
                '${step + 1}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Widget _progressLine() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: 2,
        color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
      ),
    );
  }

  Widget _buildStepBody(AuthProvider authProvider) {
    switch (_currentStep) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2(authProvider);
      default:
        return const SizedBox();
    }
  }

  // Step 0: Personal Details
  Widget _buildStep0() {
          final loc = AppLocalizations.of(context);
          return Form(
            key: _formKey0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _formField(
                  controller: _nameController,
                  hint: loc.translate('fullName'),
                  icon: Icons.person_outline_rounded,
                  validator: (v) => Validators.requiredField(v, label: loc.translate('fullName')),
                ),
                const SizedBox(height: 16),
                _formField(
                  controller: _emailController,
                  hint: loc.translate('email'),
                  icon: Icons.mail_outline_rounded,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _formField(
                  controller: _phoneController,
                  hint: loc.translate('emergencyContact'),
                  icon: Icons.phone_outlined,
                  validator: (v) => Validators.requiredField(v, label: loc.translate('emergencyContact')),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _formField(
                  controller: _passwordController,
                  hint: loc.translate('password'),
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
                _formField(
                  controller: _confirmPasswordController,
                  hint: loc.translate('confirmPassword'),
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return loc.translate('passwordsDoNotMatch');
                    }
                    return Validators.requiredField(v, label: loc.translate('confirmPassword'));
                  },
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _actionButton(label: loc.translate('continueText'), onPressed: _nextStep),
              ],
            ),
          );
  }

  // Step 1: Role Config Details
  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your role',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _roleCard('Resident', 'RESIDENT', Icons.person_rounded, Colors.blue),
                const SizedBox(width: 8),
                _roleCard('Guardian', 'GUARDIAN', Icons.supervised_user_circle_rounded, Colors.deepPurple),
                const SizedBox(width: 8),
                _roleCard('Volunteer', 'VOLUNTEER', Icons.group_rounded, Colors.green),
                const SizedBox(width: 8),
                _roleCard('Security', 'SECURITY', Icons.shield_rounded, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildRoleSpecificFields(),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Back', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionButton(label: 'Continue', onPressed: _nextStep),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSpecificFields() {
    switch (_role) {
      case 'RESIDENT':
        return Column(
          children: [
            // Society Selection
            _dropdownField<int>(
              value: _selectedSocietyId,
              hint: _isLoadingSocieties ? 'Loading Societies...' : (_societies.isEmpty ? 'No Societies Found (Tap to retry)' : 'Select Society'),
              icon: Icons.apartment_rounded,
              items: _societies.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSocietyId = val);
                  _loadBlocks(val);
                } else if (_societies.isEmpty) {
                  _loadSocieties();
                }
              },
              validator: (v) => v == null ? 'Society is required' : null,
            ),
            const SizedBox(height: 16),
            
            // Block Selection
            _dropdownField<int>(
              value: _selectedBlockId,
              hint: _isLoadingBlocks ? 'Loading Blocks...' : 'Select Block',
              icon: Icons.domain_rounded,
              items: _blocks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
              onChanged: (val) {
                if (val != null && _selectedSocietyId != null) {
                  setState(() => _selectedBlockId = val);
                  _loadFlats(_selectedSocietyId!, val);
                }
              },
              validator: (v) => v == null ? 'Block is required' : null,
            ),
            const SizedBox(height: 16),
            
            // Flat number text box
            _formField(
              controller: _flatController,
              hint: 'Flat/Apartment Number',
              icon: Icons.home_outlined,
              validator: (v) => Validators.requiredField(v, label: 'Flat number'),
            ),
          ],
        );
      case 'GUARDIAN':
        return Column(
          children: [
            _dropdownField<int>(
              value: _selectedRelationshipId,
              hint: _isLoadingRelationships ? 'Loading Relationships...' : 'Select Relationship',
              icon: Icons.family_restroom_rounded,
              items: _relationships.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
              onChanged: (val) => setState(() => _selectedRelationshipId = val),
              validator: (v) => v == null ? 'Relationship is required' : null,
            ),
          ],
        );

      case 'VOLUNTEER':
        return Column(
          children: [
            _formField(
              controller: _skillsController,
              hint: 'Skills (e.g. Medical, First Aid)',
              icon: Icons.handyman_outlined,
              validator: (v) => Validators.requiredField(v, label: 'Skills'),
            ),
            const SizedBox(height: 16),
            _formField(
              controller: _availabilityController,
              hint: 'Availability (e.g. Weekends, 24/7)',
              icon: Icons.access_time_rounded,
              validator: (v) => Validators.requiredField(v, label: 'Availability'),
            ),
            const SizedBox(height: 16),
            _formField(
              controller: _serviceAreaController,
              hint: 'Service Area (e.g. Block A, Society Outer)',
              icon: Icons.map_outlined,
              validator: (v) => Validators.requiredField(v, label: 'Service area'),
            ),
          ],
        );
      case 'SECURITY':
        return Column(
          children: [
            _formField(
              controller: _shiftController,
              hint: 'Shift (e.g. Day, Night)',
              icon: Icons.nights_stay_outlined,
              validator: (v) => Validators.requiredField(v, label: 'Shift'),
            ),
            const SizedBox(height: 16),
            _formField(
              controller: _employeeIdController,
              hint: 'Employee ID',
              icon: Icons.badge_outlined,
              validator: (v) => Validators.requiredField(v, label: 'Employee ID'),
            ),
            const SizedBox(height: 16),
            _dropdownField<int>(
              value: _selectedAssignedSocietyId,
              hint: 'Assigned Society',
              icon: Icons.apartment_rounded,
              items: _societies.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
              onChanged: (val) => setState(() => _selectedAssignedSocietyId = val),
              validator: (v) => v == null ? 'Assigned Society is required' : null,
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  // Step 2: Confirmation
  Widget _buildStep2(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review Registration Summary',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E242C) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('Name', _nameController.text),
              _summaryRow('Email', _emailController.text),
              _summaryRow('Phone', _phoneController.text),
              _summaryRow('Role', _role),
              const Divider(),
              if (_role == 'RESIDENT') ...[
                _summaryRow('Society', _societies.firstWhere((s) => s.id == _selectedSocietyId, orElse: () => SocietyModel(id: -1, name: '', address: '', city: '', state: '', pincode: '', contactPerson: '', contactNumber: '', email: '', status: '', totalBlocks: 0, totalFlats: 0)).name),
                _summaryRow('Block', _blocks.firstWhere((b) => b.id == _selectedBlockId, orElse: () => BlockTowerModel(id: -1, name: '', totalFloors: 0, societyId: -1, societyName: '')).name),
                _summaryRow('Flat Number', _flatController.text),
              ] else if (_role == 'GUARDIAN') ...[
                _summaryRow('Relationship', _relationships.firstWhere((r) => r.id == _selectedRelationshipId, orElse: () => RelationshipModel(id: -1, name: '')).name),
              ] else if (_role == 'VOLUNTEER') ...[
                _summaryRow('Skills', _skillsController.text),
                _summaryRow('Availability', _availabilityController.text),
                _summaryRow('Service Area', _serviceAreaController.text),
              ] else if (_role == 'SECURITY') ...[
                _summaryRow('Shift', _shiftController.text),
                _summaryRow('Employee ID', _employeeIdController.text),
                _summaryRow('Society', _societies.firstWhere((s) => s.id == _selectedAssignedSocietyId, orElse: () => SocietyModel(id: -1, name: '', address: '', city: '', state: '', pincode: '', contactPerson: '', contactNumber: '', email: '', status: '', totalBlocks: 0, totalFlats: 0)).name),
              ],

            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _agreeTerms,
                onChanged: (v) => setState(() => _agreeTerms = v ?? true),
                activeColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'I agree to the Terms & Conditions',
                style: GoogleFonts.inter(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Back', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B30), Color(0xFFB80000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: auth.isLoading || !_agreeTerms ? null : _submitRegistration,
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Register',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(String label, String roleValue, IconData icon, Color colorAccent) {
    final isSelected = _role == roleValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _role = roleValue),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 82,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: colorAccent, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Theme.of(context).colorScheme.onSurface : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Positioned(
              top: -4,
              right: -4,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Color(0xFF2563EB),
                child: Icon(Icons.check, color: Colors.white, size: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropdownField<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required String? Function(T?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : const Color(0x050F172A),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: Theme.of(context).colorScheme.surface,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
        hint: Text(hint, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
          filled: true,
          fillColor: isDark ? const Color(0xFF282E38) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
        items: items,
        onChanged: onChanged,
        validator: validator,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : const Color(0x050F172A),
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
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? const Color(0xFF282E38) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.5),
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

  Widget _actionButton({required String label, required VoidCallback? onPressed}) {
    return Container(
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
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
