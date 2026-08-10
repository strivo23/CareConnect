import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/sos_incident_model.dart';

/// SenderIncidentView displays ONLY the sender interface for an SOS incident.
/// Sender View highlights:
///   - SOS Status & Priority
///   - Time Created
///   - Assigned Responders
///   - Incident Lifecycle Progress / Timeline
///   - Live Updates
///   - Cancel SOS action (if permitted)
///
/// SENDER VIEW MUST NEVER DISPLAY RESPONDER ACTIONS (Accept, Decline, Chat, Call, Navigate).
class SenderIncidentView extends StatelessWidget {
  const SenderIncidentView({
    super.key,
    required this.incident,
    this.onCancelSOS,
    this.onRefresh,
  });

  final SOSIncidentModel incident;
  final VoidCallback? onCancelSOS;
  final VoidCallback? onRefresh;

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'OPEN':
        return Colors.orange;
      case 'ACCEPTED':
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN PROGRESS':
      case 'ACTIVE':
      case 'ESCALATED':
        return Colors.purple;
      case 'RESOLVED':
      case 'CLOSED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  bool get _canCancel =>
      ['PENDING', 'OPEN'].contains(incident.status.toUpperCase()) ||
      ['PENDING', 'OPEN'].contains(incident.currentStatus.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(incident.status);
    final timeStr = incident.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(incident.createdAt!)
        : 'Just now';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status Banner Header (Sender specific view)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.radar_rounded, color: statusColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            incident.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '#${incident.id}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Emergency Assistance Active',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your emergency request is being monitored and coordinated by assigned responders.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Incident Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incident Summary',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: incident.categoryName,
                  isDark: isDark,
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.access_time_filled_rounded,
                  label: 'Time Created',
                  value: timeStr,
                  isDark: isDark,
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Registered Location',
                  value: incident.resolvedAddress.isNotEmpty
                      ? incident.resolvedAddress
                      : (incident.address.isNotEmpty ? incident.address : 'Location coords logged'),
                  isDark: isDark,
                ),
                if (incident.message.isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildInfoRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Emergency Note',
                    value: incident.message,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Assigned Responders Panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assigned Responders',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Icon(Icons.shield_outlined, color: AppTheme.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                if (incident.assignedResponderName != null && incident.assignedResponderName!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.15),
                      child: const Icon(Icons.person_rounded, color: AppTheme.primary),
                    ),
                    title: Text(
                      incident.assignedResponderName!,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Role: ${incident.assignedRole ?? "Primary Responder"}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Assigned',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Notifying primary guardians and nearest responders...',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Incident Progress Tracker (Live Updates)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incident Progress',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProgressStep(
                  title: 'SOS Broadcasted',
                  subtitle: 'Emergency notification dispatched to guardians & security',
                  isCompleted: true,
                  isActive: false,
                  isDark: isDark,
                ),
                _buildProgressStep(
                  title: 'Responder Assignment',
                  subtitle: incident.assignedResponderName != null
                      ? 'Accepted by ${incident.assignedResponderName}'
                      : 'Waiting for responder acceptance',
                  isCompleted: incident.assignedResponderName != null,
                  isActive: incident.assignedResponderName == null,
                  isDark: isDark,
                ),
                _buildProgressStep(
                  title: 'Resolution & Safety Verification',
                  subtitle: 'Responder is assisting on-site',
                  isCompleted: ['RESOLVED', 'CLOSED'].contains(incident.status.toUpperCase()),
                  isActive: incident.assignedResponderName != null && !['RESOLVED', 'CLOSED'].contains(incident.status.toUpperCase()),
                  isLast: true,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Cancel SOS Button (Only if permitted)
          if (_canCancel && onCancelSOS != null) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: onCancelSOS,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(
                  'Cancel Emergency SOS',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
    required bool isDark,
  }) {
    final color = isCompleted
        ? Colors.green
        : (isActive ? Colors.orange : (isDark ? Colors.white24 : Colors.grey.shade300));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : (isActive ? Colors.orange.withOpacity(0.2) : Colors.transparent),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : (isActive ? const Center(child: CircleAvatar(radius: 4, backgroundColor: Colors.orange)) : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? Colors.green : (isDark ? Colors.white10 : Colors.grey.shade300),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCompleted || isActive ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
