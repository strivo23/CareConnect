import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'routes/app_router.dart';

class CareConnectApp extends StatelessWidget {
  const CareConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp.router(
      title: 'CareConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(false),
      darkTheme: AppTheme.lightTheme(true),
      themeMode: authProvider.themeMode,
      routerConfig: AppRouter.router(authProvider),
      builder: (context, child) {
        final base = child ?? const SizedBox.shrink();
        return DefaultTextStyle.merge(
          style: GoogleFonts.interTextTheme(Theme.of(context).textTheme).bodyMedium ?? const TextStyle(),
          child: base,
        );
      },
    );
  }
}
