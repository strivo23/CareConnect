import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B250F) : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: isDark ? const Color(0xFFFBBF24) : Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: isDark ? const Color(0xFFFBBF24) : Colors.orange.shade900, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
