import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/api_client.dart';

/// Service for downloading files from API endpoints and saving/sharing them.
class FileDownloadService {
  final ApiClient _apiClient = ApiClient();

  /// Download a file from [endpoint], save it locally, and let the user
  /// open or share it via the system share sheet.
  ///
  /// [fileName] is used as the local file name (e.g. "receipt_123.pdf").
  /// Returns the saved [File] on success, or null on failure.
  Future<File?> downloadAndShare(
    String endpoint, {
    required String fileName,
    required BuildContext context,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Downloading...'),
          ],
        ),
        backgroundColor: const Color(0xFF199A8E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final response = await _apiClient.downloadRaw(
        endpoint,
        requiresAuth: true,
      );

      // Check if the response is actually a file (not a JSON error)
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Receipt not available yet'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return null;
      }

      if (response.bodyBytes.isEmpty) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Downloaded file is empty'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return null;
      }

      // Get temp directory to save the file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      scaffoldMessenger.clearSnackBars();

      // Get the render box for sharePositionOrigin (required on iPad)
      final box = context.findRenderObject() as RenderBox?;
      final shareOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // Open the share sheet so the user can save / share / preview
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
        sharePositionOrigin: shareOrigin,
      );

      return file;
    } catch (e) {
      debugPrint('FileDownloadService.downloadAndShare error: $e');
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return null;
    }
  }

  /// Download a file and save it without sharing.
  /// Returns the saved [File] on success.
  Future<File?> download(
    String endpoint, {
    required String fileName,
  }) async {
    try {
      final response = await _apiClient.downloadRaw(
        endpoint,
        requiresAuth: true,
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (e) {
      debugPrint('FileDownloadService error: $e');
      return null;
    }
  }
}
