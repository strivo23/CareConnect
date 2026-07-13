import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        context.go('/login');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, Color(0xFFFFB266)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                child: Icon(Icons.shield_rounded, size: 42, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(height: 20),
              Text('CareConnect', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Emergency response and resident support', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
