import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/eye_rest_model.dart';

/// EyeRestLocalDataSource
///
/// Data source responsible for caching and retrieving eye rest configurations
/// and continuous usage state from [SharedPreferences].
class EyeRestLocalDataSource {
  static const String _kEyeRestKey = 'eye_rest_settings';

  /// Saves the eye rest configuration model to local storage
  Future<void> saveEyeRestSettings(EyeRestModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEyeRestKey, jsonEncode(model.toJson()));
  }

  /// Retrieves the saved eye rest configuration model or default if not found
  Future<EyeRestModel> getEyeRestSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawString = prefs.getString(_kEyeRestKey);
    if (rawString != null) {
      try {
        final map = jsonDecode(rawString) as Map<String, dynamic>;
        return EyeRestModel.fromJson(map);
      } catch (_) {}
    }
    return EyeRestModel.fromEntity(EyeRestModel.fromJson({}));
  }
}
