import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../services/file_service.dart';
import '../services/profile_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_constants.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  String _currentLanguage = 'en';
  String _defaultTranslationLang = 'ta';
  String _defaultCompressionPreset = 'medium';
  bool _autoSave = true;

  @override
  void initState() {
    super.initState();
    _currentLanguage = _storage.getLanguage();
    _defaultTranslationLang = _storage.getDefaultTranslationLang();
    _defaultCompressionPreset = _storage.getDefaultCompressionMode();
    _autoSave = _storage.getAutoSave();
  }

  String _getLangName(String code) {
    switch (code) {
      case 'ta':
        return 'Tamil (தமிழ்)';
      case 'hi':
        return 'Hindi (हिन्दी)';
      case 'te':
        return 'Telugu (తెలుగు)';
      case 'ml':
        return 'Malayalam (മലയാളം)';
      case 'es':
        return 'Spanish (Español)';
      case 'fr':
        return 'French (Français)';
      case 'de':
        return 'German (Deutsch)';
      default:
        return 'English';
    }
  }

  String _getCompressionName(String mode) {
    switch (mode) {
      case 'low':
        return 'Low (High Quality)';
      case 'high':
        return 'High (Smallest Size)';
      default:
        return 'Medium (Recommended)';
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(
      text: _storage.getGeminiApiKey() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Gemini API Key',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add your Google Gemini API key to activate real-time cloud LLM document analysis.\n\nLeave empty to continue using VertexDocs on-device Demo Engine.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'AIzaSy...',
                prefixIcon: Icon(Icons.key_rounded, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              await _storage.setGeminiApiKey(controller.text);
              if (mounted) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.success,
                    content: Text('Gemini API key updated successfully!'),
                  ),
                );
              }
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              AppConstants.appName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appTagline,
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Version ${AppConstants.appVersion}\nDeveloped by ${AppConstants.developerName}',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'VertexDocs provides local, private, and high-performance PDF manipulation utilities along with bilingual AI assistance for modern Android devices.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasGeminiKey = _storage.getGeminiApiKey() != null &&
        _storage.getGeminiApiKey()!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Summary Card
            ValueListenableBuilder<UserProfileModel>(
              valueListenable: ProfileService().profileNotifier,
              builder: (context, profile, _) {
                final hasImage = profile.photoPath != null &&
                    File(profile.photoPath!).existsSync();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.secondary,
                        backgroundImage: hasImage
                            ? FileImage(File(profile.photoPath!))
                            : null,
                        child: !hasImage
                            ? Text(
                                profile.initials,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              profile.email,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (profile.bio.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                profile.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.primary),
                        tooltip: 'Edit Profile',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // App Branding Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          AppConstants.appTagline,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v${AppConstants.appVersion} • ${AppConstants.developerName}',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // AI Section
            _buildSectionHeader('AI ASSISTANT & LANGUAGE'),
            _buildSettingsGroup([
              ListTile(
                leading: const Icon(Icons.language_rounded,
                    color: AppColors.primary),
                title: Text('Assistant Language', style: _titleStyle),
                subtitle: Text(
                  _currentLanguage == 'ta' ? 'தமிழ் (Tamil)' : 'English',
                  style: _subStyle,
                ),
                trailing: DropdownButton<String>(
                  value: _currentLanguage,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _currentLanguage = val);
                      _storage.setLanguage(val);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.g_translate_rounded,
                    color: AppColors.primary),
                title: Text('Default Translation Target', style: _titleStyle),
                subtitle: Text(_getLangName(_defaultTranslationLang),
                    style: _subStyle),
                trailing: DropdownButton<String>(
                  value: _defaultTranslationLang,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ta', child: Text('Tamil (தமிழ்)')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(
                        value: 'hi', child: Text('Hindi (हिन्दी)')),
                    DropdownMenuItem(
                        value: 'te', child: Text('Telugu (తెలుగు)')),
                    DropdownMenuItem(
                        value: 'ml', child: Text('Malayalam (മലയാളം)')),
                    DropdownMenuItem(
                        value: 'es', child: Text('Spanish (Español)')),
                    DropdownMenuItem(
                        value: 'fr', child: Text('French (Français)')),
                    DropdownMenuItem(
                        value: 'de', child: Text('German (Deutsch)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _defaultTranslationLang = val);
                      _storage.setDefaultTranslationLang(val);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.key_rounded, color: AppColors.primary),
                title: Text('Google Gemini API Key', style: _titleStyle),
                subtitle: Text(
                  hasGeminiKey
                      ? 'Active (Cloud AI Enabled)'
                      : 'Local Demo Mode Active',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: hasGeminiKey
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight:
                        hasGeminiKey ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary),
                onTap: _showApiKeyDialog,
              ),
            ]),
            const SizedBox(height: 24),

            // Preferences
            _buildSectionHeader('PREFERENCES'),
            _buildSettingsGroup([
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary:
                    const Icon(Icons.save_rounded, color: AppColors.primary),
                title: Text('Auto-Save Processed Files', style: _titleStyle),
                subtitle: Text('Keep files in My Files automatically',
                    style: _subStyle),
                value: _autoSave,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _autoSave = val);
                  _storage.setAutoSave(val);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.tune_rounded, color: AppColors.primary),
                title: Text('Default Compression Preset', style: _titleStyle),
                subtitle: Text(_getCompressionName(_defaultCompressionPreset),
                    style: _subStyle),
                trailing: DropdownButton<String>(
                  value: _defaultCompressionPreset,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: 'low', child: Text('Low (High Quality)')),
                    DropdownMenuItem(
                        value: 'medium', child: Text('Medium (Recommended)')),
                    DropdownMenuItem(
                        value: 'high', child: Text('High (Max Savings)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _defaultCompressionPreset = val);
                      _storage.setDefaultCompressionMode(val);
                    }
                  },
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Storage & Maintenance
            _buildSectionHeader('STORAGE & MAINTENANCE'),
            _buildSettingsGroup([
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded,
                    color: AppColors.primary),
                title: Text('Clear Temp Cache', style: _titleStyle),
                subtitle: Text('Free up temporary processing cache',
                    style: _subStyle),
                onTap: () async {
                  await FileService().clearCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Temporary cache cleared!'),
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded,
                    color: AppColors.primary),
                title: Text('Clear Recent Files History', style: _titleStyle),
                subtitle: Text('Removes list from home screen (keeps files)',
                    style: _subStyle),
                onTap: () async {
                  await _storage.clearRecentFiles();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Recent files history cleared!'),
                      ),
                    );
                  }
                },
              ),
            ]),
            const SizedBox(height: 24),

            // About & Info
            _buildSectionHeader('ABOUT'),
            _buildSettingsGroup([
              ListTile(
                leading: const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary),
                title: Text('About VertexDocs', style: _titleStyle),
                subtitle:
                    Text('App details, version and license', style: _subStyle),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary),
                onTap: _showAboutDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.share_outlined, color: AppColors.primary),
                title: Text('Share VertexDocs', style: _titleStyle),
                subtitle:
                    Text('Tell colleagues about VertexDocs', style: _subStyle),
                onTap: () {
                  ShareService.shareFile(
                    '',
                    text:
                        'VertexDocs - Complete PDF Suite & AI Assistant for Android by JM Vertex Technologies.',
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Account & Session
            _buildSectionHeader('ACCOUNT'),
            _buildSettingsGroup([
              ListTile(
                leading:
                    const Icon(Icons.logout_rounded, color: AppColors.error),
                title: Text('Log Out',
                    style: _titleStyle.copyWith(color: AppColors.error)),
                subtitle: Text('Sign out of your VertexDocs account',
                    style: _subStyle),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      title: Text(
                        'Log Out',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      content: const Text(
                          'Are you sure you want to log out of VertexDocs?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await AuthService().logout();
                  }
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
      );

  TextStyle get _titleStyle => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  TextStyle get _subStyle => GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textSecondary,
      );
}
