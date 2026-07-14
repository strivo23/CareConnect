import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../services/location_service.dart';

class SOSMessageScreen extends StatefulWidget {
  const SOSMessageScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;

  @override
  State<SOSMessageScreen> createState() => _SOSMessageScreenState();
}

class _SOSMessageScreenState extends State<SOSMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final LocationService _locationService = LocationService();

  bool _isListening = false;
  String _selectedPriority = 'HIGH';
  Map<String, dynamic>? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;
  String _currentAddress = '';
  late double _currentLat;
  late double _currentLng;
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.address;
    _currentLat = widget.latitude;
    _currentLng = widget.longitude;
    _fetchCategories();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      await _speech.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ApiClient.instance.get('/api/sos/categories/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List 
            ? response.data as List 
            : (response.data as Map<String, dynamic>)['results'] as List? ?? [];
        setState(() {
          _categories = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      debugPrint('Error fetching categories: $e');
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            if (result.recognizedWords.isNotEmpty) {
              setState(() {
                _messageController.text = result.recognizedWords;
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
          ),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _refreshLocation() async {
    setState(() => _isUpdatingLocation = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        final addr = await _locationService.reverseGeocode(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentAddress = addr;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating location: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      setState(() => _isUpdatingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'SOS Emergency Details',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: AppTheme.danger))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Selection
                  Text(
                    'Select Emergency Category',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedCategory,
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
                                    color: const Color(0xFF1E293B),
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
                      color: const Color(0xFF0F172A),
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
                              color: isSelected ? priorityColor : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? priorityColor : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                priority,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Message Input Area
                  Text(
                    'Emergency Message (Optional)',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: _messageController,
                          maxLines: 5,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText: 'Describe the emergency (e.g. medical crisis on 3rd floor block B)...',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
                          onChanged: (_) => setState(() {}),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _listen,
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: _isListening ? Colors.red.shade100 : const Color(0xFFF1F5F9),
                                child: Icon(
                                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                  color: _isListening ? AppTheme.danger : const Color(0xFF475569),
                                  size: 22,
                                ),
                              ),
                            ),
                            Text(
                              '${_messageController.text.length} / 500',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location Preview Box
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Alert Location',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        onPressed: _isUpdatingLocation ? null : _refreshLocation,
                        icon: _isUpdatingLocation
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mock/Static Map Preview Fallback
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFEE2E2)),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Grid Background Lines to simulate map
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.1,
                                  child: Image.network(
                                    'https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&q=80&w=400',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppTheme.danger, size: 40),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Map Coordinates Captured',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF991B1B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Lat: ${_currentLat.toStringAsFixed(5)}, Lng: ${_currentLng.toStringAsFixed(5)}',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF7F1D1D),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Reverse-Geocoded Address:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAddress,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Next Review Button
                  ElevatedButton(
                    onPressed: () {
                      if (_selectedCategory == null) return;
                      context.push(
                        '/sos-review',
                        extra: {
                          'category': _selectedCategory,
                          'priority': _selectedPriority,
                          'message': _messageController.text,
                          'latitude': _currentLat,
                          'longitude': _currentLng,
                          'address': _currentAddress,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Review SOS Summary',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
