import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_state_provider.dart';
import '../../services/society_repository.dart';
import '../../models/society_model.dart';

class SocietyScreen extends StatefulWidget {
  const SocietyScreen({super.key});

  @override
  State<SocietyScreen> createState() => _SocietyScreenState();
}

class _SocietyScreenState extends State<SocietyScreen> {
  final _repository = SocietyRepository();
  List<SocietyModel> _societies = [];
  List<BlockTowerModel> _blocks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    // Read resident before async gaps to avoid BuildContext across async gap
    final resident = context.read<AppStateProvider>().residentProfile;
    try {
      final societies = await _repository.fetchSocieties();
      if (!mounted) return;
      setState(() => _societies = societies);

      // Load blocks for the linked society
      if (resident?.societyId != null) {
        final blocks = await _repository.fetchBlocks(resident!.societyId!);
        if (!mounted) return;
        setState(() => _blocks = blocks);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to load society data. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resident = context.watch<AppStateProvider>().residentProfile;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Society',
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Your community directory',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        titleSpacing: Navigator.canPop(context) ? 0 : 20,
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(color: const Color(0xFF2563EB)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF2563EB),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      _buildErrorCard(),

                    // MY RESIDENCE CARD
                    _buildSectionTitle('MY RESIDENCE'),
                    _buildResidenceCard(resident),
                    const SizedBox(height: 20),

                    // BLOCKS IN SOCIETY
                    if (_blocks.isNotEmpty) ...[
                      _buildSectionTitle('BLOCKS'),
                      ..._blocks.map((block) => _buildBlockCard(block)),
                      const SizedBox(height: 20),
                    ],

                    // SOCIETIES DIRECTORY
                    _buildSectionTitle('SOCIETY DIRECTORY'),
                    if (_societies.isEmpty && !_isLoading)
                      _buildEmptyState()
                    else
                      ..._societies.map((s) => _buildSocietyCard(s)),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey.shade400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: const Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: Text('Retry', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResidenceCard(dynamic resident) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resident?.societyName.isNotEmpty == true ? resident!.societyName : 'No society linked',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your residential community',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: resident?.status == 'Approved'
                      ? const Color(0xFF22C55E)
                      : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  resident?.status ?? 'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildResidenceStat(
                icon: Icons.domain_rounded,
                label: 'Block',
                value: resident?.blockName.isNotEmpty == true ? resident!.blockName : '—',
              ),
              const SizedBox(width: 12),
              _buildResidenceStat(
                icon: Icons.meeting_room_rounded,
                label: 'Flat',
                value: resident?.flatNumber.isNotEmpty == true ? resident!.flatNumber : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResidenceStat({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600)),
                Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(BlockTowerModel block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.domain_rounded, color: const Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.name,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                Text(
                  '${block.totalFloors} floors',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSocietyCard(SocietyModel society) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_city_rounded, color: const Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      society.name,
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                    Text(
                      '${society.city}, ${society.state}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: society.status == 'Active' ? const Color(0xFFECFDF5) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  society.status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: society.status == 'Active' ? const Color(0xFF22C55E) : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSocietyStat(icon: Icons.domain_rounded, label: '${society.totalBlocks} Blocks', color: const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              _buildSocietyStat(icon: Icons.meeting_room_rounded, label: '${society.totalFlats} Flats', color: const Color(0xFF22C55E)),
              if (society.contactNumber.isNotEmpty) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: society.contactNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Contact number copied: ${society.contactNumber}'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        society.contactNumber,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (society.address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${society.address}, ${society.pincode}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocietyStat({required IconData icon, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.apartment_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No societies found',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Your society will appear here once added by the admin.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
