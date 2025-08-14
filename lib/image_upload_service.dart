import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;

class ImageUploadService {
  static const List<String> _scopes = [drive.DriveApi.driveFileScope];
  static const String _credentialsPath = 'assets/sampleapp-456304-0e65d6f57b51.json';
  static const String _folderId = '1DACaW8omea5x0jb3GHyn4RE-noM5mZYK'; // Your Google Drive folder ID
  static const String _serviceAccountEmail = 'app-405@sampleapp-456304.iam.gserviceaccount.com';
  
  static Future<drive.DriveApi> _getDriveApi() async {
    final credentialsJson = await rootBundle.loadString(_credentialsPath);
    final credentials = ServiceAccountCredentials.fromJson(
      json.decode(credentialsJson) as Map<String, dynamic>
    );

    final client = await clientViaServiceAccount(credentials, _scopes);
    return drive.DriveApi(client);
  }

  static Future<String?> uploadProductImage(File imageFile) async {
    try {
      final driveApi = await _getDriveApi();
      
      // Create file metadata
      final file = drive.File()
        ..name = path.basename(imageFile.path)
        ..parents = [_folderId];

      // Upload file
      final media = drive.Media(
        imageFile.openRead(),
        await imageFile.length(),
      );

      final uploadedFile = await driveApi.files.create(
        file,
        uploadMedia: media,
      );

      // Make the file publicly accessible
      await driveApi.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        uploadedFile.id!,
      );

      // Get the web content link
      final fileDetails = await driveApi.files.get(
        uploadedFile.id!,
        $fields: 'webContentLink',
      );

      return fileDetails.webContentLink;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  static Future<File?> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  static Future<String?> getImageUrl(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      final file = await driveApi.files.get(
        fileId,
        $fields: 'webContentLink',
      );
      return file.webContentLink;
    } catch (e) {
      print('Error getting image URL: $e');
      return null;
    }
  }
} 