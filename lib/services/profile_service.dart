// lib/services/profile_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api';

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String fullName,
    required String email,
    required String phone,
    File? profileImage,
  }) async {
    String? imageUrl;

    // Upload image if provided
    if (profileImage != null) {
      imageUrl = await _uploadProfileImage(token, profileImage);
    }

    // Prepare profile data
    final Map<String, dynamic> profileData = <String, dynamic>{
      'fullName': fullName,
      'email': email,
      'phone': phone,
    };

    if (imageUrl != null) {
      profileData['profileImage'] = imageUrl;
    }

    // Update profile via API
    final http.Response response = await http.put(
      Uri.parse('$_baseUrl/auth/profile'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(profileData),
    );

    if (response.statusCode != 200) {
      final Map<String, dynamic> error =
          jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(error['error'] ?? 'Failed to update profile');
    }

    return profileData;
  }

  Future<String?> _uploadProfileImage(String token, File imageFile) async {
    try {
      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload/profile-image'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Explicitly resolve the MIME type instead of letting the http
      // package guess from the file path. Some camera/gallery temp files
      // (especially on Android/iOS) don't have a clean .jpg/.png/.webp
      // extension, which caused the http package to fall back to
      // 'application/octet-stream' and made the backend reject valid
      // images with "invalid file type".
      String? mimeType = lookupMimeType(imageFile.path);
      const List<String> allowed = <String>[
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp',
      ];
      if (mimeType == null || !allowed.contains(mimeType)) {
        // Fall back to sniffing the first bytes if extension-based lookup
        // failed or returned something unexpected.
        final List<int> headerBytes =
            await imageFile.openRead(0, 12).first;
        mimeType = lookupMimeType(imageFile.path, headerBytes: headerBytes) ??
            'image/jpeg';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final http.StreamedResponse streamedResponse = await request.send();
      final http.Response response =
          await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return data['imageUrl'] as String?;
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      throw Exception('Failed to upload profile image');
    }
  }

  Future<Position?> getUserLocation({
    required Function(String) onError,
  }) async {
    // Check if location services are enabled
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError('Location services are disabled. Please enable them.');
      return null;
    }

    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError('Location permission denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError(
          'Location permission permanently denied. Please enable in settings.');
      return null;
    }

    // Get current position
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error fetching location: $e');
      onError('Error fetching location');
      return null;
    }
  }
}