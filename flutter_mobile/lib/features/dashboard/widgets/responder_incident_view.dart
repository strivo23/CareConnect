import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/sos_incident_model.dart';
import 'emergency_location_widget.dart';

/// ResponderIncidentView displays the responder interface for an SOS incident.
/// Action buttons (Accept, Decline, Chat, Call, Navigate) are strictly governed
/// by backend permission flags (canAccept, canDecline, canChat, canCall, canNavigate).
class ResponderIncidentView extends StatelessWidget {
  const ResponderIncidentView({
    super.key,
    required this.incident,
    this.calculatedDistance,
    this.onAccept,
    this.onDecline,
    this.onChat,
    this.onCall,
    this.onNavigate,
    this.onShareLocation,
    this.onViewTimeline,
  });

  final SOSIncidentModel incident;
  final String? calculatedDistance;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onChat;
  final VoidCallback? onCall;
  final VoidCallback? onNavigate;
  final VoidCallback? onShareLocation;
  final VoidCallback? onViewTimeline;

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFDC2626);
      case 'HIGH':
        return const Color(0xFFEF4444);
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.blue;
      default:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(incident.priority);
    final timeStr = incident.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(incident.createdAt!)
        : 'Just now';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Responder Alert Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: priorityColor.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: priorityColor.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: priorityColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${incident.priority.toUpperCase()} PRIORITY',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: priorityColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (incident.isAssignedGuardian)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ASSIGNED GUARDIAN',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  incident.residentName,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Triggered ${incident.categoryName}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (calculatedDistance != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.near_me_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        calculatedDistance!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Incident Details Card
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
                  'Incident Details',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                _buildDetailItem(
                  icon: Icons.access_time_rounded,
                  label: 'Time Reported',
                  value: timeStr,
                  isDark: isDark,
                ),
                const Divider(height: 20),
                _buildDetailItem(
                  icon: Icons.location_on_rounded,
                  label: 'Incident Location',
                  value: incident.resolvedAddress.isNotEmpty
                      ? incident.resolvedAddress
                      : (incident.address.isNotEmpty ? incident.address : 'Coordinates captured'),
                  isDark: isDark,
                ),
                if (incident.message.isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildDetailItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Emergency Note from Resident',
                    value: incident.message,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Location Map Preview (if coordinates present)
          if (incident.latitude != null && incident.longitude != null) ...[
            EmergencyLocationWidget(
              latitude: incident.latitude!,
              longitude: incident.longitude!,
              address: incident.resolvedAddress.isNotEmpty ? incident.resolvedAddress : incident.address,
            ),
            const SizedBox(height: 20),
          ],

          // 4. RESPONDER ACTION PANEL
          // Rendered strictly based on backend permission flags:
          // canAccept, canDecline, canChat, canCall, canNavigate
          Text(
            'RESPONDER ACTIONS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Accept & Decline Row (shown if canAccept == true or canDecline == true)
                if (incident.canAccept || incident.canDecline) ...[
                  Row(
                    children: [
                      if (incident.canAccept && onAccept != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                            label: Text(
                              'Accept SOS',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (incident.canAccept && incident.canDecline) const SizedBox(width: 12),
                      if (incident.canDecline && onDecline != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onDecline,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            label: Text(
                              'Decline',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons Row: Chat, Call, Navigate
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (incident.canChat && onChat != null)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.chat_rounded,
                          label: 'Chat',
                          color: AppTheme.primary,
                          onPressed: onChat!,
                          isDark: isDark,
                        ),
                      ),
                    if (incident.canChat && (incident.canCall || incident.canNavigate))
                      const SizedBox(width: 8),
                    if (incident.canCall && onCall != null)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.phone_rounded,
                          label: 'Call',
                          color: Colors.green,
                          onPressed: onCall!,
                          isDark: isDark,
                        ),
                      ),
                    if (incident.canCall && incident.canNavigate)
                      const SizedBox(width: 8),
                    if (incident.canNavigate && onNavigate != null)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.navigation_rounded,
                          label: 'Navigate',
                          color: Colors.purple,
                          onPressed: onNavigate!,
                          isDark: isDark,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Lifecycle Timeline button
          if (onViewTimeline != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                onPressed: onViewTimeline,
                icon: const Icon(Icons.history_rounded, size: 20),
                label: Text(
                  'View Incident Timeline',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem({
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
