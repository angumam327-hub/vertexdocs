import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile_model.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  static const String _prefProfileKey = 'vertex_user_profile_data';

  final ValueNotifier<UserProfileModel> profileNotifier =
      ValueNotifier<UserProfileModel>(const UserProfileModel());

  final ImagePicker _picker = ImagePicker();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefProfileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(raw) as Map<String, dynamic>;
        final profile = UserProfileModel.fromJson(data);
        // Verify photo exists if specified
        if (profile.photoPath != null &&
            !File(profile.photoPath!).existsSync()) {
          profileNotifier.value = profile.copyWith(clearPhoto: true);
        } else {
          profileNotifier.value = profile;
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now());
    profileNotifier.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefProfileKey, jsonEncode(updated.toJson()));
  }

  Future<String?> pickPhotoFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    return await _savePhotoPermanently(file.path);
  }

  Future<String?> capturePhotoFromCamera() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    return await _savePhotoPermanently(file.path);
  }

  Future<void> removePhoto() async {
    final current = profileNotifier.value;
    if (current.photoPath != null) {
      final f = File(current.photoPath!);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    await saveProfile(current.copyWith(clearPhoto: true));
  }

  Future<String> _savePhotoPermanently(String tempPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final profileDir =
        Directory('${appDir.path}${Platform.pathSeparator}profile');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    final ext = tempPath.split('.').last;
    final targetPath =
        '${profileDir.path}${Platform.pathSeparator}avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final tempFile = File(tempPath);
    await tempFile.copy(targetPath);

    // Update current profile photo
    final updated = profileNotifier.value.copyWith(photoPath: targetPath);
    await saveProfile(updated);

    return targetPath;
  }
}
