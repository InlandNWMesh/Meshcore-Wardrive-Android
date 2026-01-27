import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import '../models/models.dart';
import '../constants/app_version.dart';

class UploadService {
  bool _isDefaultEndpoint(String url) {
    String norm(String u) {
      var s = u.trim().toLowerCase();
      if (s.endsWith('/')) s = s.substring(0, s.length - 1);
      return s;
    }
    return norm(url) == norm(defaultApiUrl);
  }
  static const String _apiUrlKey = 'upload_api_url';
  static const String _autoUploadKey = 'auto_upload_enabled';
  static const String _lastUploadKey = 'last_upload_timestamp';
  
  // Default URL (user can change this)
  static const String defaultApiUrl = 'https://meshwar-map.pages.dev/api/samples';
  
  final DatabaseService _db = DatabaseService();
  
  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? defaultApiUrl;
  }
  
  Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }
  
  Future<bool> isAutoUploadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoUploadKey) ?? false;
  }
  
  Future<void> setAutoUploadEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUploadKey, enabled);
  }
  
  Future<DateTime?> getLastUploadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastUploadKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }
  
  Future<void> _setLastUploadTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUploadKey, time.millisecondsSinceEpoch);
  }
  
  /// Upload all unuploaded samples to the configured API
  Future<UploadResult> uploadAllSamples({Map<String, String>? repeaterNames}) async {
    try {
      final apiUrl = await getApiUrl();
      final bool isDefault = _isDefaultEndpoint(apiUrl);
      final samples = isDefault
          ? await _db.getUnuploadedSamples()
          : await _db.getAllSamples();
      
      if (samples.isEmpty) {
        return UploadResult(success: true, message: 'No new samples to upload');
      }
      
      // Convert samples to JSON (include stable id for server-side dedupe)
      final samplesJson = samples.map((sample) => {
        'id': sample.id,
        'nodeId': (sample.path == null || sample.path!.isEmpty)
            ? 'Unknown'
            : (sample.path!.length > 8 ? sample.path!.substring(0, 8).toUpperCase() : sample.path!.toUpperCase()),
'repeaterName': (() {
          final name = (sample.path != null && repeaterNames != null)
              ? repeaterNames![sample.path]
              : null;
          if (name != null && name.isNotEmpty) return name;
          if (sample.path == null || sample.path!.isEmpty) return 'Unknown';
          final short = sample.path!.length > 8 ? sample.path!.substring(0,8).toUpperCase() : sample.path!.toUpperCase();
          return short;
        })(),
        'latitude': sample.position.latitude,
        'longitude': sample.position.longitude,
        'rssi': sample.rssi,
        'snr': sample.snr,
        'pingSuccess': sample.pingSuccess,
        'timestamp': sample.timestamp.toIso8601String(),
        'appVersion': appVersion, // App version from constants
      }).toList();
      
      // Debug: log first 3 samples
      if (samplesJson.isNotEmpty) {
        print('Uploading ${samplesJson.length} samples');
        print('Sample 1: ${samplesJson.first}');
        if (samplesJson.length > 1) {
          print('Sample 2: ${samplesJson[1]}');
        }
      }
      
      // Send POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'samples': samplesJson}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        await _setLastUploadTime(DateTime.now());
        
        // Mark these samples as uploaded only for the default endpoint
        final sampleIds = samples.map((s) => s.id).toList();
        if (isDefault) {
          await _db.markSamplesAsUploaded(sampleIds);
        }
        
        return UploadResult(
          success: true,
          message: 'Upload Complete',
          uploadedCount: samples.length,
          totalCount: responseData['totalCells'],
        );
      } else {
        return UploadResult(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return UploadResult(
        success: false,
        message: 'Upload failed: $e',
      );
    }
  }
  
  /// Upload only samples since last upload (deprecated - use uploadAllSamples instead)
  Future<UploadResult> uploadNewSamples({Map<String, String>? repeaterNames}) async {
    // Just redirect to uploadAllSamples since it now only uploads unuploaded samples
    return uploadAllSamples(repeaterNames: repeaterNames);
  }
}

class UploadResult {
  final bool success;
  final String message;
  final int? uploadedCount;
  final int? totalCount;
  
  UploadResult({
    required this.success,
    required this.message,
    this.uploadedCount,
    this.totalCount,
  });
}
