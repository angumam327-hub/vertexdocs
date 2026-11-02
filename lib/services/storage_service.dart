import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_file_model.dart';
import '../models/chat_message_model.dart';
import '../utils/app_constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  final ValueNotifier<List<PdfFileModel>> recentFilesNotifier =
      ValueNotifier<List<PdfFileModel>>([]);
  final ValueNotifier<List<PdfFileModel>> savedFilesNotifier =
      ValueNotifier<List<PdfFileModel>>([]);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadRecentFiles();
    await _loadSavedFiles();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
          'StorageService has not been initialized. Call init() first.');
    }
    return _prefs!;
  }

  // --- Recent Files ---
  Future<void> _loadRecentFiles() async {
    final raw = _prefs?.getString(AppConstants.prefRecentFiles);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        recentFilesNotifier.value = list
            .map((e) => PdfFileModel.fromJson(e as Map<String, dynamic>))
            .where((f) => f.existsOnDisk)
            .toList();
      } catch (e) {
        debugPrint('Error loading recent files: $e');
        recentFilesNotifier.value = [];
      }
    } else {
      recentFilesNotifier.value = [];
    }
  }

  Future<void> addRecentFile(PdfFileModel file) async {
    final current = List<PdfFileModel>.from(recentFilesNotifier.value);
    current.removeWhere((item) => item.path == file.path);
    current.insert(0, file);
    // Keep up to 20 recent files
    if (current.length > 20) {
      current.removeRange(20, current.length);
    }
    recentFilesNotifier.value = current;
    await _persistRecentFiles();
    await addSavedFile(file);
  }

  Future<void> removeRecentFile(String path) async {
    final current = List<PdfFileModel>.from(recentFilesNotifier.value);
    current.removeWhere((item) => item.path == path);
    recentFilesNotifier.value = current;
    await _persistRecentFiles();
  }

  Future<void> clearRecentFiles() async {
    recentFilesNotifier.value = [];
    await _prefs?.remove(AppConstants.prefRecentFiles);
  }

  Future<void> _persistRecentFiles() async {
    final raw =
        jsonEncode(recentFilesNotifier.value.map((e) => e.toJson()).toList());
    await _prefs?.setString(AppConstants.prefRecentFiles, raw);
  }

  // --- Saved Files (My Files) ---
  Future<void> _loadSavedFiles() async {
    final raw = _prefs?.getString(AppConstants.prefSavedFiles);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        savedFilesNotifier.value = list
            .map((e) => PdfFileModel.fromJson(e as Map<String, dynamic>))
            .where((f) => f.existsOnDisk)
            .toList();
      } catch (e) {
        debugPrint('Error loading saved files: $e');
        savedFilesNotifier.value = [];
      }
    } else {
      savedFilesNotifier.value = [];
    }
  }

  Future<void> addSavedFile(PdfFileModel file) async {
    final current = List<PdfFileModel>.from(savedFilesNotifier.value);
    current.removeWhere((item) => item.path == file.path);
    current.insert(0, file);
    savedFilesNotifier.value = current;
    await _persistSavedFiles();
  }

  Future<void> removeSavedFile(String path) async {
    final current = List<PdfFileModel>.from(savedFilesNotifier.value);
    current.removeWhere((item) => item.path == path);
    savedFilesNotifier.value = current;
    await _persistSavedFiles();
    await removeRecentFile(path);
  }

  Future<void> updateSavedFile(PdfFileModel updated) async {
    final current = List<PdfFileModel>.from(savedFilesNotifier.value);
    final index = current.indexWhere(
        (item) => item.id == updated.id || item.path == updated.path);
    if (index != -1) {
      current[index] = updated;
      savedFilesNotifier.value = current;
      await _persistSavedFiles();
    }
    // Also update recent files if present
    final recent = List<PdfFileModel>.from(recentFilesNotifier.value);
    final rIndex = recent.indexWhere(
        (item) => item.id == updated.id || item.path == updated.path);
    if (rIndex != -1) {
      recent[rIndex] = updated;
      recentFilesNotifier.value = recent;
      await _persistRecentFiles();
    }
  }

  Future<void> clearAllSavedFiles() async {
    savedFilesNotifier.value = [];
    await _prefs?.remove(AppConstants.prefSavedFiles);
    await clearRecentFiles();
  }

  Future<void> _persistSavedFiles() async {
    final raw =
        jsonEncode(savedFilesNotifier.value.map((e) => e.toJson()).toList());
    await _prefs?.setString(AppConstants.prefSavedFiles, raw);
  }

  // --- Settings ---
  String getLanguage() {
    return _prefs?.getString(AppConstants.prefAppLanguage) ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    await _prefs?.setString(AppConstants.prefAppLanguage, lang);
  }

  String? getGeminiApiKey() {
    return _prefs?.getString(AppConstants.prefGeminiApiKey);
  }

  Future<void> setGeminiApiKey(String key) async {
    await _prefs?.setString(AppConstants.prefGeminiApiKey, key.trim());
  }

  bool getAutoSave() {
    return _prefs?.getBool(AppConstants.prefAutoSave) ?? true;
  }

  Future<void> setAutoSave(bool value) async {
    await _prefs?.setBool(AppConstants.prefAutoSave, value);
  }

  // --- AI Chat History ---
  static const String _prefChatHistory = 'vertex_chat_history';

  List<ChatMessageModel> getChatHistory() {
    final raw = _prefs?.getString(_prefChatHistory);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading chat history: $e');
      }
    }
    return [];
  }

  Future<void> saveChatHistory(List<ChatMessageModel> messages) async {
    final raw = jsonEncode(messages.map((e) => e.toJson()).toList());
    await _prefs?.setString(_prefChatHistory, raw);
  }

  Future<void> clearChatHistory() async {
    await _prefs?.remove(_prefChatHistory);
  }
}
