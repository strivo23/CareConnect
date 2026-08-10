import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../services/emergency_repository.dart';


class SOSReviewScreen extends StatefulWidget {
  const SOSReviewScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<SOSReviewScreen> createState() => _SOSReviewScreenState();
}

class _SOSReviewScreenState extends State<SOSReviewScreen> {
  bool _isSending = false;

  Future<void> _submitSOS() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final categoryRaw = widget.data['category'];
      int? categoryId;
      if (categoryRaw is Map) {
        final idVal = categoryRaw['id'];
        if (idVal is int) {
          categoryId = idVal;
        } else if (idVal != null) {
          categoryId = int.tryParse(idVal.toString());
        }
      } else if (categoryRaw is int) {
        categoryId = categoryRaw;
      } else if (categoryRaw != null) {
        categoryId = int.tryParse(categoryRaw.toString());
      }

      final latRaw = widget.data['latitude'];
      final lngRaw = widget.data['longitude'];
      double? latVal;
      double? lngVal;
      if (latRaw != null) {
        final parsed = latRaw is double ? latRaw : double.tryParse(latRaw.toString());
        if (parsed != null) latVal = double.parse(parsed.toStringAsFixed(6));
      }
      if (lngRaw != null) {
        final parsed = lngRaw is double ? lngRaw : double.tryParse(lngRaw.toString());
        if (parsed != null) lngVal = double.parse(parsed.toStringAsFixed(6));
      }

      final body = <String, dynamic>{
        'message': widget.data['message'] ?? 'Immediate assistance requested.',
        'latitude': latVal,
        'longitude': lngVal,
        'address': widget.data['address'] ?? 'Location unavailable',
        'priority': widget.data['priority'] ?? 'HIGH',
      };
      if (categoryId != null) {
        body['category'] = categoryId;
      }

      debugPrint('[SOS DISPATCH REQUEST] URL: /api/sos/send/ Data: $body');

      final response = await ApiClient.instance.post(
        '/api/sos/send/',
        data: body,
      );

      if (response.statusCode == 201) {
        final resData = Map<String, dynamic>.from(response.data as Map);
        final incidentId = resData['id'] is int
            ? resData['id'] as int
            : int.tryParse(resData['id'].toString()) ?? 0;

        final voiceFilePath = widget.data['voiceFilePath']?.toString();
        final voiceDuration = widget.data['voice_duration'] is int
            ? widget.data['voice_duration'] as int
            : int.tryParse(widget.data['voice_duration']?.toString() ?? '');
        final emergencyDescription = widget.data['emergency_description']?.toString() ?? widget.data['message']?.toString();

        if (incidentId > 0 && ((voiceFilePath != null && voiceFilePath.isNotEmpty) || (emergencyDescription != null && emergencyDescription.isNotEmpty))) {
          try {
            final repo = EmergencyRepository();
            await repo.uploadSOSMessage(
              incidentId: incidentId,
              emergencyDescription: emergencyDescription,
              voiceFilePath: voiceFilePath,
              voiceDuration: voiceDuration,
            );
          } catch (uploadErr) {
            debugPrint('Failed to attach voice/text message: $uploadErr');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Emergency Alert dispatched successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pushReplacement(
            '/sos-success',
            extra: {
              'id': resData['id'],
              'status': resData['status'] ?? 'Pending',
              'created_at': resData['created_at'] ?? '',
              'notifications_summary': resData['notifications_summary'] ?? {},
            },
          );
        }
      } else {
        throw Exception('Failed to send SOS: ${response.statusMessage}');
      }

    } catch (e) {
      final userErrorMsg = ApiClient.extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userErrorMsg),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
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
    Map<String, dynamic> category = {};
    final categoryRaw = widget.data['category'];
    if (categoryRaw is Map) {
      category = Map<String, dynamic>.from(categoryRaw);
    }

    final priority = widget.data['priority']?.toString() ?? 'HIGH';
    final message = widget.data['message']?.toString() ?? '';
    final voiceFilePath = widget.data['voiceFilePath']?.toString();
    final voiceDuration = widget.data['voice_duration']?.toString() ?? '0';
    final latRaw = widget.data['latitude'];
    final lngRaw = widget.data['longitude'];
    final double latitude = latRaw is double ? latRaw : (double.tryParse(latRaw?.toString() ?? '') ?? 0.0);
    final double longitude = lngRaw is double ? lngRaw : (double.tryParse(lngRaw?.toString() ?? '') ?? 0.0);
    final address = widget.data['address']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;


    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Review SOS Dispatch',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
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
                color: isDark ? const Color(0xFF2D1418) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF4C1D24) : const Color(0xFFFFE4E6)),
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
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF9F1239),
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
                  Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
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
                  Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  _buildReviewRow(
                    label: 'Emergency Message',
                    value: message.isNotEmpty ? message : 'Immediate assistance requested.',
                  ),
                  if (voiceFilePath != null && voiceFilePath.isNotEmpty) ...[
                    Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                    _buildReviewRow(
                      label: 'Voice Recording',
                      value: '🎙️ Attached (${voiceDuration}s voice message)',
                      valueColor: Colors.green,
                    ),
                  ],
                  Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  _buildReviewRow(
                    label: 'Coordinates',
                    value: 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}',
                  ),
                  Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
