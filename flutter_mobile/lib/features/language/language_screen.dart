import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';

class LanguageModel {
  final String code;
  final String flag;
  final String nativeName;
  final String englishName;

  const LanguageModel({
    required this.code,
    required this.flag,
    required this.nativeName,
    required this.englishName,
  });
}

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selectedCode;

  static const List<LanguageModel> _languages = [
    LanguageModel(code: 'en', flag: '🇬🇧', nativeName: 'English', englishName: 'English'),
    LanguageModel(code: 'hi', flag: '🇮🇳', nativeName: 'हिन्दी', englishName: 'Hindi'),
    LanguageModel(code: 'te', flag: '🇮🇳', nativeName: 'తెలుగు', englishName: 'Telugu'),
    LanguageModel(code: 'ta', flag: '🇮🇳', nativeName: 'தமிழ்', englishName: 'Tamil'),
    LanguageModel(code: 'kn', flag: '🇮🇳', nativeName: 'ಕನ್ನಡ', englishName: 'Kannada'),
    LanguageModel(code: 'ml', flag: '🇮🇳', nativeName: 'മലയാളം', englishName: 'Malayalam'),
    LanguageModel(code: 'es', flag: '🇪🇸', nativeName: 'Español', englishName: 'Spanish'),
    LanguageModel(code: 'fr', flag: '🇫🇷', nativeName: 'Français', englishName: 'French'),
    LanguageModel(code: 'de', flag: '🇩🇪', nativeName: 'Deutsch', englishName: 'German'),
    LanguageModel(code: 'it', flag: '🇮🇹', nativeName: 'Italiano', englishName: 'Italian'),
    LanguageModel(code: 'pt', flag: '🇵🇹', nativeName: 'Português', englishName: 'Portuguese'),
    LanguageModel(code: 'ru', flag: '🇷🇺', nativeName: 'Русский', englishName: 'Russian'),
    LanguageModel(code: 'tr', flag: '🇹🇷', nativeName: 'Türkçe', englishName: 'Turkish'),
    LanguageModel(code: 'ar', flag: '🇸🇦', nativeName: 'العربية', englishName: 'Arabic'),
    LanguageModel(code: 'zh', flag: '🇨🇳', nativeName: '简体中文', englishName: 'Chinese (Simplified)'),
    LanguageModel(code: 'ja', flag: '🇯🇵', nativeName: '日本語', englishName: 'Japanese'),
    LanguageModel(code: 'ko', flag: '🇰🇷', nativeName: '한국어', englishName: 'Korean'),
    LanguageModel(code: 'th', flag: '🇹🇭', nativeName: 'ไทย', englishName: 'Thai'),
    LanguageModel(code: 'vi', flag: '🇻🇳', nativeName: 'Tiếng Việt', englishName: 'Vietnamese'),
    LanguageModel(code: 'id', flag: '🇮🇩', nativeName: 'Bahasa Indonesia', englishName: 'Indonesian'),
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _selectedCode = auth.languageCode;
  }

  void _onSelectLanguage(String code) {
    setState(() {
      _selectedCode = code;
    });
    final auth = context.read<AuthProvider>();
    auth.setLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textWhite),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/landing');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER TITLE SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Text(
                    '🌐 ${loc.translate('chooseLanguage')}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.translate('selectLanguageSub'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LANGUAGE CARDS LIST
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = lang.code == _selectedCode;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _onSelectLanguage(lang.code),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                              : AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryTeal : const Color(0xFF1E293B),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Text(lang.flag, style: const TextStyle(fontSize: 32)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.nativeName,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppTheme.primaryTeal : AppTheme.textWhite,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lang.englishName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryTeal,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.darkBackground,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // CONTINUE BUTTON FOOTER
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final auth = context.read<AuthProvider>();
                    if (auth.isAuthenticated) {
                      context.go('/home');
                    } else {
                      context.go('/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: AppTheme.darkBackground,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Text(
                    loc.translate('continueText'),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
