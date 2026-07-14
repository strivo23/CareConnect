import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';

class SOSReviewScreen extends StatefulWidget {
  const SOSReviewScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<SOSReviewScreen> createState() => _SOSReviewScreenState();
}

class _SOSReviewScreenState extends State<SOSReviewScreen> {
  bool _isSending = false;

  Future<void> _submitSOS() async {
    setState(() => _isSending = true);
    try {
      final category = widget.data['category'] as Map<String, dynamic>;
      final response = await ApiClient.instance.post(
        '/api/sos/send/',
        data: {
          'category': category['id'],
          'message': widget.data['message'],
          'latitude': widget.data['latitude'],
          'longitude': widget.data['longitude'],
          'address': widget.data['address'],
          'priority': widget.data['priority'],
        },
      );

      if (response.statusCode == 201) {
        final resData = response.data as Map<String, dynamic>;
        if (mounted) {
          context.pushReplacement(
            '/sos-success',
            extra: {
              'id': resData['id'],
              'status': resData['status'] ?? 'Pending',
              'created_at': resData['created_at'] ?? '',
            },
          );
        }
      } else {
        throw Exception('Failed to send SOS: ${response.statusMessage}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dispatching SOS: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.data['category'] as Map<String, dynamic>;
    final priority = widget.data['priority']?.toString() ?? 'HIGH';
    final message = widget.data['message']?.toString() ?? '';
    final latitude = widget.data['latitude'] as double;
    final longitude = widget.data['longitude'] as double;
    final address = widget.data['address']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Review SOS Dispatch',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE4E6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppTheme.danger, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Please confirm the details below. Dispatch notifications will be sent to security and primary guardians instantly.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF9F1239),
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary Card
            Text(
              'Emergency Summary',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildReviewRow(
                    label: 'Category',
                    value: '${category['icon'] ?? "🚨"} ${category['name'] ?? "General"}',
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  _buildReviewRow(
                    label: 'Priority',
                    value: priority,
                    valueColor: priority == 'CRITICAL'
                        ? Colors.red.shade900
                        : priority == 'HIGH'
                            ? AppTheme.danger
                            : priority == 'MEDIUM'
                                ? Colors.orange
                                : Colors.blue,
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  _buildReviewRow(
                    label: 'Emergency Message',
                    value: message.isNotEmpty ? message : 'Immediate assistance requested.',
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  _buildReviewRow(
                    label: 'Coordinates',
                    value: 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}',
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  _buildReviewRow(
                    label: 'Resolved Address',
                    value: address,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Submit Button
            ElevatedButton(
              onPressed: _isSending ? null : _submitSOS,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.danger.withValues(alpha: 0.6),
                minimumSize: const Size(double.infinity, 58),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    )
                  : Text(
                      'CONFIRM & SEND SOS',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF1E293B),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
