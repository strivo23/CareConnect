import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';

class SOSSuccessScreen extends StatelessWidget {
  const SOSSuccessScreen({super.key, required this.incidentData});

  final Map<String, dynamic> incidentData;

  @override
  Widget build(BuildContext context) {
    final int incidentId = incidentData['id'] as int? ?? 0;
    final String status = incidentData['status']?.toString() ?? 'Pending';
    final String createdAtStr = incidentData['created_at']?.toString() ?? '';
    final DateTime createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111418) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success Icon Animation Placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F2E1E) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'SOS Sent Successfully!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Emergency dispatch notifications have been sent. Help is being coordinated.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Detail card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context: context,
                      label: 'Incident ID',
                      value: '#$incidentId',
                    ),
                    Divider(height: 20, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    _buildDetailRow(
                      context: context,
                      label: 'Status',
                      value: status,
                      valueColor: status == 'Pending' ? Colors.orange : Colors.green,
                    ),
                    Divider(height: 20, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    _buildDetailRow(
                      context: context,
                      label: 'Created Time',
                      value: DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                    ),
                    Divider(height: 20, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    _buildDetailRow(
                      context: context,
                      label: 'Emergency Contacts',
                      value: 'Notified',
                      valueColor: Colors.green,
                    ),
                    Divider(height: 20, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    _buildDetailRow(
                      context: context,
                      label: 'Guardian Status',
                      value: 'Alert Sent',
                      valueColor: Colors.green,
                    ),
                    Divider(height: 20, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    _buildDetailRow(
                      context: context,
                      label: 'Security Staff',
                      value: 'Dispatched',
                      valueColor: Colors.green,
                    ),
                    Divider(height: 20, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    _buildDetailRow(
                      context: context,
                      label: 'Volunteers',
                      value: 'Broadcasting',
                      valueColor: Colors.blue,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final notif = AppNotificationModel(
                          id: incidentId.toString(),
                          title: 'Emergency SOS',
                          message: 'SOS created successfully',
                          category: 'sos',
                          isRead: false,
                          createdAt: createdAt,
                          priority: 'HIGH',
                          location: 'Resolved Lat/Lng',
                          incidentId: incidentId,
                          residentName: 'You',
                          emergencyCategory: 'SOS Emergency',
                          incidentMessage: 'Immediate help requested.',
                          incidentStatus: status,
                        );
                        context.push('/sos-detail', extra: notif);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.danger, width: 1.5),
                        foregroundColor: AppTheme.danger,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'View Incident',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.go('/home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Return Home',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
