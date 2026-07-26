import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../services/location_service.dart';
import '../../services/audio_recording_service.dart';
import '../../services/emergency_repository.dart';

class SOSMessageScreen extends StatefulWidget {
  const SOSMessageScreen({
    super.key,
    this.latitude,
    this.longitude,
    this.address,
    this.incidentId,
  });

  final double? latitude;
  final double? longitude;
  final String? address;
  final int? incidentId;

  @override
  State<SOSMessageScreen> createState() => _SOSMessageScreenState();
}

class _SOSMessageScreenState extends State<SOSMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final LocationService _locationService = LocationService();
  final AudioRecordingService _audioService = AudioRecordingService();
  final EmergencyRepository _emergencyRepository = EmergencyRepository();

  bool _isSpeechListening = false;
  bool _isSpeechAvailable = false;

  String _selectedPriority = 'HIGH';
  Map<String, dynamic>? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  String _currentAddress = 'Fetching location...';
  double? _currentLat;
  double? _currentLng;
  bool _isFetchingLocation = false;

  // Audio recording state
  bool _isRecording = false;
  bool _isPlayingPreview = false;
  int _recordDuration = 0;
  String? _recordedFilePath;

  // Stream subscriptions
  StreamSubscription<int>? _durationSub;
  StreamSubscription<bool>? _recordingStateSub;
  StreamSubscription<bool>? _playingStateSub;

  // Upload state
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.address ?? 'Fetching location...';
    _currentLat = widget.latitude;
    _currentLng = widget.longitude;

    if (widget.incidentId == null) {
      _fetchCategories();
    } else {
      _isLoadingCategories = false;
    }

    _initSpeech();
    _initAudioServiceStreams();

    if (_currentLat == null || _currentLng == null || _currentAddress == 'Fetching location...') {
      _fetchCurrentLocation();
    }
  }

  void _initAudioServiceStreams() {
    _durationSub = _audioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _recordDuration = duration);
      }
    });

    _recordingStateSub = _audioService.recordingStateStream.listen((isRec) {
      if (mounted) {
        setState(() {
          _isRecording = isRec;
          _recordedFilePath = _audioService.recordedFilePath;
        });
      }
    });

    _playingStateSub = _audioService.playingStateStream.listen((isPlaying) {
      if (mounted) {
        setState(() => _isPlayingPreview = isPlaying);
      }
    });
  }

  void _initSpeech() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isSpeechListening = false);
          }
        },
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return;
    setState(() {
      _isFetchingLocation = true;
      _currentAddress = 'Fetching GPS location...';
    });

    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        final addr = await _locationService.reverseGeocode(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentAddress = addr.isNotEmpty ? addr : 'Location unavailable';
        });
      } else {
        if (!mounted) return;
        setState(() => _currentAddress = 'Location unavailable');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _currentAddress = 'Location unavailable');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ApiClient.instance.get('/api/sos/categories/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data as List
            : (response.data as Map<String, dynamic>)['results'] as List? ?? [];
        if (mounted) {
          setState(() {
            _categories = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            if (_categories.isNotEmpty) {
              _selectedCategory = _categories.first;
            }
            _isLoadingCategories = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
      debugPrint('Error fetching categories: $e');
    }
  }

  // ── Speech-to-Text Toggle ────────────────────────────────────────────────
  void _toggleSpeechToText() async {
    if (_isSpeechListening) {
      await _speech.stop();
      setState(() => _isSpeechListening = false);
    } else {
      if (!_isSpeechAvailable) {
        _isSpeechAvailable = await _speech.initialize();
      }
      if (_isSpeechAvailable) {
        setState(() => _isSpeechListening = true);
        await _speech.listen(
          onResult: (result) {
            if (result.recognizedWords.isNotEmpty && mounted) {
              setState(() {
                _messageController.text = result.recognizedWords;
                _messageController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _messageController.text.length),
                );

              });
            }
          },
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Voice Recording Controls ─────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } else {
      final hasPerm = await _audioService.hasPermission();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record voice message.'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final success = await _audioService.startRecording(
        onMaxDurationReached: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maximum 60 seconds voice recording reached.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );

      if (success && mounted) {
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _deleteRecording() async {
    await _audioService.deleteRecording();
    if (mounted) {
      setState(() {
        _recordedFilePath = null;
        _recordDuration = 0;
        _isRecording = false;
        _isPlayingPreview = false;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── Upload Message to Backend ─────────────────────────────────────────────
  Future<void> _uploadMessageForExistingIncident() async {
    final text = _messageController.text.trim();
    final hasVoice = _recordedFilePath != null && _recordedFilePath!.isNotEmpty;

    if (text.isEmpty && !hasVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an emergency description or record a voice message.'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      await _emergencyRepository.uploadSOSMessage(
        incidentId: widget.incidentId!,
        emergencyDescription: text,
        voiceFilePath: _recordedFilePath,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency message attached successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload emergency message: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _uploadMessageForExistingIncident,
          ),
        ),
      );
    }
  }

  void _proceedToReview() {
    if (_selectedCategory == null && widget.incidentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an emergency category.'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.push(
      '/sos-review',
      extra: {
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'message': _messageController.text.trim(),
        'emergency_description': _messageController.text.trim(),
        'voiceFilePath': _recordedFilePath,
        'latitude': _currentLat ?? 0.0,
        'longitude': _currentLng ?? 0.0,
        'address': _currentAddress,
      },
    );
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _recordingStateSub?.cancel();
    _playingStateSub?.cancel();
    _audioService.dispose();
    _speech.stop();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          widget.incidentId != null ? 'Attach Emergency Message' : 'SOS Emergency Details',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: AppTheme.danger))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // If not attaching to existing incident, show category & priority selection
                      if (widget.incidentId == null) ...[
                        // Category Selection
                        Text(
                          'Select Emergency Category',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: _selectedCategory,
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                              items: _categories.map((cat) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: cat,
                                  child: Row(
                                    children: [
                                      Text(
                                        cat['icon']?.toString() ?? '🚨',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        cat['name']?.toString() ?? 'Emergency',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Priority Selection
                        Text(
                          'Set Alert Priority',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((priority) {
                            final isSelected = _selectedPriority == priority;
                            final priorityColor = priority == 'CRITICAL'
                                ? Colors.red.shade900
                                : priority == 'HIGH'
                                    ? AppTheme.danger
                                    : priority == 'MEDIUM'
                                        ? Colors.orange
                                        : Colors.blue;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedPriority = priority),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? priorityColor : Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? priorityColor : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      priority,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF475569)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Text & Speech Input Card ────────────────────────────────
                      Text(
                        'Emergency Description',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _messageController,
                              maxLines: 4,
                              maxLength: 500,
                              decoration: InputDecoration(
                                hintText: 'Type or speak your emergency description (e.g., severe injury on 2nd floor)...',
                                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    // Speech to Text Mic Toggle Button
                                    Tooltip(
                                      message: 'Speech to Text',
                                      child: InkWell(
                                        onTap: _toggleSpeechToText,
                                        borderRadius: BorderRadius.circular(30),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _isSpeechListening
                                                ? Colors.red.shade100
                                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _isSpeechListening ? AppTheme.danger : Colors.transparent,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _isSpeechListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                                color: _isSpeechListening ? AppTheme.danger : (isDark ? Colors.white60 : const Color(0xFF475569)),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _isSpeechListening ? 'Listening...' : 'Speech to Text',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _isSpeechListening ? AppTheme.danger : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_messageController.text.length} / 500',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Voice Recording Card ────────────────────────────────────
                      Text(
                        'Voice Recording (Max 60 sec)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            if (_recordedFilePath == null && !_isRecording) ...[
                              // Idle Record State
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _toggleRecording,
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppTheme.danger.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3), width: 2),
                                      ),
                                      child: const Icon(Icons.mic_rounded, color: AppTheme.danger, size: 28),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tap to record voice message',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Hands-free recording up to 60s',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (_isRecording) ...[
                              // Active Recording State
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _toggleRecording,
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.danger,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.stop_rounded, color: Colors.white, size: 30),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppTheme.danger,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Recording in progress...',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                                color: AppTheme.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: _recordDuration / 60.0,
                                            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                            color: AppTheme.danger,
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_formatDuration(_recordDuration)} / 01:00',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Recorded Voice Preview & Action Controls
                              Row(
                                children: [
                                  // Play / Pause preview button
                                  InkWell(
                                    onTap: () => _audioService.togglePlayPreview(),
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isPlayingPreview ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: AppTheme.danger,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Voice Recording Captured',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Duration: ${_formatDuration(_recordDuration)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Re-record / Delete button
                                  IconButton(
                                    onPressed: _deleteRecording,
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                    tooltip: 'Delete and Re-record',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Alert Location Preview Box ─────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Text(
                            'Alert Location',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          IconButton(
                            onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                            icon: _isFetchingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.danger),
                                  )
                                : const Icon(Icons.my_location_rounded, color: AppTheme.danger, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Map coordinates header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF3B1D20) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? const Color(0xFF4A1D20) : const Color(0xFFFEE2E2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppTheme.danger, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'GPS Coordinates',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _currentLat != null && _currentLng != null
                                              ? 'Lat: ${_currentLat!.toStringAsFixed(6)}, Lng: ${_currentLng!.toStringAsFixed(6)}'
                                              : 'Coordinates unavailable',
                                          style: GoogleFonts.inter(
                                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'OpenStreetMap Resolved Address:',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentAddress,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Submit / Proceed Button ─────────────────────────────────
                      ElevatedButton(
                        onPressed: _isUploading
                            ? null
                            : (widget.incidentId != null
                                ? _uploadMessageForExistingIncident
                                : _proceedToReview),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.danger.withValues(alpha: 0.6),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isUploading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Uploading Audio (${(_uploadProgress * 100).toInt()}%)...',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              )
                            : Text(
                                widget.incidentId != null ? 'Upload Emergency Message' : 'Review SOS Summary',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Upload Progress Bar overlay if uploading
                if (_isUploading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      backgroundColor: Colors.transparent,
                      color: AppTheme.danger,
                      minHeight: 4,
                    ),
                  ),
              ],
            ),
    );
  }
}
