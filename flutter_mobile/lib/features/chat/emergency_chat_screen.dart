import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/api_client.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/chat_websocket_service.dart';

class EmergencyChatScreen extends StatefulWidget {
  final Map<String, dynamic> incidentData;

  const EmergencyChatScreen({
    super.key,
    required this.incidentData,
  });

  @override
  State<EmergencyChatScreen> createState() => _EmergencyChatScreenState();
}

class _EmergencyChatScreenState extends State<EmergencyChatScreen> {
  late Map<String, dynamic> _incident;
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatWebSocketService _wsService = ChatWebSocketService();

  bool _isLoading = true;
  bool _isConnected = false;
  String _typingUser = '';
  Map<String, dynamic>? _replyingTo;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _connSubscription;

  bool get _isClosed => ['CLOSED', 'Closed'].contains(_incident['current_status'] ?? _incident['status']);

  @override
  void initState() {
    super.initState();
    _incident = Map<String, dynamic>.from(widget.incidentData);
    _fetchChatHistory();
    _initWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _connSubscription?.cancel();
    _wsService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatHistory() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;

    try {
      final res = await ApiClient.instance.get('/api/sos/incidents/$incidentId/chat/');
      if (res.data != null) {
        final List results = res.data['results'] ?? res.data ?? [];
        setState(() {
          _messages.clear();
          _messages.addAll(results.cast<Map<String, dynamic>>());
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _initWebSocket() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;

    final token = await ApiClient.getAccessToken();
    final isSecure = ApiClient.baseUrl.startsWith('https');
    final scheme = isSecure ? 'wss' : 'ws';
    final baseUrl = ApiClient.baseUrl.replaceAll('http://', '').replaceAll('https://', '').split('/')[0];
    final wsUrl = '$scheme://$baseUrl/ws/incidents/$incidentId/chat/?token=$token';

    _connSubscription = _wsService.connectionStream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });

    _wsSubscription = _wsService.messageStream.listen((data) {
      if (!mounted) return;

      final type = data['type'];
      if (type == 'chat_message' && data['message'] != null) {
        setState(() {
          _messages.add(Map<String, dynamic>.from(data['message']));
        });
        _scrollToBottom();
      } else if (type == 'typing_status') {
        setState(() {
          _typingUser = (data['is_typing'] == true) ? (data['user_name'] ?? '') : '';
        });
      }
    });

    _wsService.connect(wsUrl);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String type = 'TEXT', Map<String, dynamic>? extraData}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && type == 'TEXT') return;
    if (_isClosed) return;

    final payload = {
      'action': 'chat_message',
      'message': text,
      'message_type': type,
      if (_replyingTo != null) 'reply_to_id': _replyingTo!['id'],
      if (extraData != null) ...extraData,
    };

    if (_isConnected) {
      _wsService.sendMessage(payload);
    } else {
      try {
        final incidentId = _incident['id'];
        await ApiClient.instance.post('/api/sos/incidents/$incidentId/chat/', data: {
          'message': text,
          'message_type': type,
          if (_replyingTo != null) 'reply_to': _replyingTo!['id'],
          if (extraData != null) ...extraData,
        });
        _fetchChatHistory();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }

    _messageController.clear();
    setState(() => _replyingTo = null);
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      await _sendMessage(
        type: 'LOCATION',
        extraData: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'message': 'My Current Location: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch location permissions.')),
      );
    }
  }

  void _onLongPressMessage(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.blue),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.grey),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(ctx);
                if (msg['message'] != null) {
                  Clipboard.setData(ClipboardData(text: msg['message']));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _incident['current_status'] ?? _incident['status'] ?? 'OPEN';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency Chat #${_incident['id']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Live Connected' : 'Syncing...',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.grey.shade300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text('Incident is Closed. Chat is read-only.', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isSystem = msg['message_type'] == 'SYSTEM' || msg['sender_role'] == 'SYSTEM';

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              msg['message'] ?? '',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final role = msg['sender_role'] ?? 'USER';
                      final senderName = msg['sender_name'] ?? 'Participant';
                      final text = msg['message'] ?? '';

                      return GestureDetector(
                        onLongPress: () => _onLongPressMessage(msg),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(senderName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(role, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red.shade900)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (msg['reply_to_detail'] != null)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        margin: const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          border: const Border(left: BorderSide(color: Colors.red, width: 3)),
                                        ),
                                        child: Text(msg['reply_to_detail']['message'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                                      ),
                                    Text(text, style: GoogleFonts.inter(fontSize: 14)),
                                    if (msg['latitude'] != null) ...[
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => launchUrl(Uri.parse('https://maps.google.com/?q=${msg['latitude']},${msg['longitude']}')),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.location_on, color: Colors.red, size: 16),
                                            const SizedBox(width: 4),
                                            Text('Open GPS Location in Maps', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (_typingUser.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_typingUser is typing...', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
            ),

          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Replying to: ${_replyingTo!['message']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          if (!_isClosed)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: Colors.red),
                      onPressed: _sendLocation,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type emergency chat message...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.red.shade700,
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: () => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
