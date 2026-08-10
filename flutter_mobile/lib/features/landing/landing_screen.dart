import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final features = [
      {
        'title': loc.translate('oneTapSos'),
        'desc': loc.translate('oneTapSosSub'),
        'icon': Icons.touch_app_rounded,
        'color': AppTheme.emergencyRed,
      },
      {
        'title': loc.translate('guardianAlerts'),
        'desc': loc.translate('guardianAlertsSub'),
        'icon': Icons.shield_rounded,
        'color': AppTheme.accentAmber,
      },
      {
        'title': loc.translate('liveGps'),
        'desc': loc.translate('liveGpsSub'),
        'icon': Icons.location_on_rounded,
        'color': AppTheme.primaryTeal,
      },
      {
        'title': loc.translate('volunteerResponse'),
        'desc': loc.translate('volunteerResponseSub'),
        'icon': Icons.volunteer_activism_rounded,
        'color': AppTheme.successGreen,
      },
      {
        'title': loc.translate('securityCoordination'),
        'desc': loc.translate('securityCoordinationSub'),
        'icon': Icons.security_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': loc.translate('emergencyChat'),
        'desc': loc.translate('emergencyChatSub'),
        'icon': Icons.chat_bubble_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': loc.translate('communitySafety'),
        'desc': loc.translate('communitySafetySub'),
        'icon': Icons.people_alt_rounded,
        'color': const Color(0xFF06B6D4),
      },
    ];

    final workflowSteps = [
      {'num': '1', 'title': loc.translate('step1'), 'icon': Icons.person_add_rounded},
      {'num': '2', 'title': loc.translate('step2'), 'icon': Icons.business_rounded},
      {'num': '3', 'title': loc.translate('step3'), 'icon': Icons.group_add_rounded},
      {'num': '4', 'title': loc.translate('step4'), 'icon': Icons.warning_amber_rounded},
      {'num': '5', 'title': loc.translate('step5'), 'icon': Icons.health_and_safety_rounded},
    ];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // TOP HEADER BAR (Logo & Quick Language Picker Button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryTeal, width: 1.5),
                          ),
                          child: const Icon(Icons.favorite_rounded, color: AppTheme.emergencyRed, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          loc.translate('appName'),
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => context.push('/language'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2E3D52)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.language_rounded, color: AppTheme.primaryTeal, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              loc.locale.languageCode.toUpperCase(),
                              style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // HERO SECTION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Brand Badge Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: AppTheme.primaryTeal, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            loc.translate('subHeading'),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      loc.translate('tagline'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textWhite,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      loc.translate('description'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Action Buttons (Get Started & Login)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.push('/language'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: AppTheme.darkBackground,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: Text(
                              loc.translate('getStarted'),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/login'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textWhite,
                              side: const BorderSide(color: Color(0xFF334155), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              loc.translate('login'),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // FEATURES SECTION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key Platform Features',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textWhite),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Comprehensive emergency coordination for your community',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // Feature Cards Grid
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: features.length,
                      itemBuilder: (context, index) {
                        final item = features[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF1E293B)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: (item['color'] as Color).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['desc'] as String,
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // HOW IT WORKS SECTION
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                color: const Color(0xFF0F172A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('howItWorks'),
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textWhite),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '5 Simple steps from setup to emergency protection',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Stepper Flow List
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: workflowSteps.map((step) {
                          return Container(
                            margin: const EdgeInsets.only(right: 14),
                            padding: const EdgeInsets.all(16),
                            width: 140,
                            decoration: BoxDecoration(
                              color: AppTheme.darkCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                                  child: Icon(step['icon'] as IconData, color: AppTheme.primaryTeal, size: 20),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'STEP ${step['num']}',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  step['title'] as String,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textWhite),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // FOOTER SECTION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => _showPolicyDialog(
                            context,
                            loc.translate('privacyPolicy'),
                            'CareConnect respects your privacy and is committed to protecting your personal data, GPS location telemetry, and emergency contacts. All emergency transmissions are encrypted.',
                          ),
                          child: Text(loc.translate('privacyPolicy'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ),
                        const Text('•', style: TextStyle(color: AppTheme.textSecondary)),
                        TextButton(
                          onPressed: () => _showPolicyDialog(
                            context,
                            loc.translate('termsConditions'),
                            'By using CareConnect, you agree to enable emergency location features for safety routing and to provide accurate emergency contact info.',
                          ),
                          child: Text(loc.translate('termsConditions'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.translate('version'),
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
