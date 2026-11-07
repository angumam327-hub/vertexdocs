import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_service.dart';

class UserAuthModel {
  final String uid;
  final String name;
  final String email;
  final DateTime createdAt;

  const UserAuthModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserAuthModel.fromJson(Map<String, dynamic> json) => UserAuthModel(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? 'User',
        email: json['email'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _prefIsLoggedIn = 'vertex_auth_is_logged_in';
  static const String _prefCurrentUser = 'vertex_auth_current_user';
  static const String _prefRegisteredUsers = 'vertex_auth_registered_users';

  bool _isLoggedIn = false;
  UserAuthModel? _currentUser;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  UserAuthModel? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;

  /// Initializes authentication state from SharedPreferences
  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_prefIsLoggedIn) ?? false;

    final userJson = prefs.getString(_prefCurrentUser);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        _currentUser =
            UserAuthModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Logs in a user with email and password
  Future<({bool success, String? error})> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return (success: false, error: 'Please enter a valid email address.');
    }
    if (cleanPass.length < 6) {
      return (
        success: false,
        error: 'Password must be at least 6 characters long.'
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString(_prefRegisteredUsers);
    Map<String, dynamic> users = {};
    if (rawUsers != null) {
      try {
        users = jsonDecode(rawUsers) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Check if account exists
    if (users.containsKey(cleanEmail)) {
      final userData = users[cleanEmail] as Map<String, dynamic>;
      final savedPass = userData['password'] as String?;
      if (savedPass != cleanPass) {
        return (success: false, error: 'Incorrect password. Please try again.');
      }
      _currentUser = UserAuthModel(
        uid: userData['uid'] as String? ?? cleanEmail,
        name: userData['name'] as String? ?? 'VertexDocs User',
        email: cleanEmail,
        createdAt: DateTime.now(),
      );
    } else {
      // First time login with this email: auto-create account for seamless UX
      final name = cleanEmail.split('@').first;
      final formattedName = name.isNotEmpty
          ? '${name[0].toUpperCase()}${name.substring(1)}'
          : 'VertexDocs User';
      _currentUser = UserAuthModel(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: formattedName,
        email: cleanEmail,
        createdAt: DateTime.now(),
      );
      users[cleanEmail] = {
        'uid': _currentUser!.uid,
        'name': _currentUser!.name,
        'email': cleanEmail,
        'password': cleanPass,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_prefRegisteredUsers, jsonEncode(users));
    }

    // Persist login session
    _isLoggedIn = true;
    await prefs.setBool(_prefIsLoggedIn, true);
    await prefs.setString(_prefCurrentUser, jsonEncode(_currentUser!.toJson()));

    // Synchronize user profile in ProfileService
    await ProfileService().saveProfile(
      ProfileService().profileNotifier.value.copyWith(
            name: _currentUser!.name,
            email: _currentUser!.email,
          ),
    );

    notifyListeners();
    return (success: true, error: null);
  }

  /// Registers a new user with full name, email and password
  Future<({bool success, String? error})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanName.isEmpty) {
      return (success: false, error: 'Please enter your full name.');
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return (success: false, error: 'Please enter a valid email address.');
    }
    if (cleanPass.length < 6) {
      return (
        success: false,
        error: 'Password must be at least 6 characters long.'
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString(_prefRegisteredUsers);
    Map<String, dynamic> users = {};
    if (rawUsers != null) {
      try {
        users = jsonDecode(rawUsers) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (users.containsKey(cleanEmail)) {
      return (
        success: false,
        error: 'An account with this email already exists. Please log in.'
      );
    }

    final newUser = UserAuthModel(
      uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      createdAt: DateTime.now(),
    );

    users[cleanEmail] = {
      'uid': newUser.uid,
      'name': cleanName,
      'email': cleanEmail,
      'password': cleanPass,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_prefRegisteredUsers, jsonEncode(users));

    // Auto login
    _currentUser = newUser;
    _isLoggedIn = true;
    await prefs.setBool(_prefIsLoggedIn, true);
    await prefs.setString(_prefCurrentUser, jsonEncode(newUser.toJson()));

    // Sync with ProfileService
    await ProfileService().saveProfile(
      ProfileService().profileNotifier.value.copyWith(
            name: cleanName,
            email: cleanEmail,
          ),
    );

    notifyListeners();
    return (success: true, error: null);
  }

  /// Sends password reset link/confirmation
  Future<({bool success, String? message})> sendPasswordReset(
      String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return (success: false, message: 'Please enter a valid email address.');
    }

    // In local persistent mode, simulate email delivery
    await Future.delayed(const Duration(milliseconds: 600));
    return (
      success: true,
      message: 'Password reset link sent to $cleanEmail. Please check your inbox.'
    );
  }

  /// Logs out user and clears active session
  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsLoggedIn, false);
    await prefs.remove(_prefCurrentUser);
    notifyListeners();
  }
}
