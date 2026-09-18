import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/api_constants.dart';
import 'media_cache_service.dart';
import 'storage_service.dart';

class MediaDownloadService {
  /// Downloads media to the user's Downloads/Documents folder.
  ///
  /// The app's offline vault is consulted first (Item 5): once a file has been
  /// sent or opened on this device it can always be saved again, even when the
  /// server no longer has it. A network download is additionally mirrored into
  /// the vault so the next save works offline.
  static Future<String?> downloadMedia({
    required String mediaUrl,
    required String fileName,
    String? token,
    String? mediaId,
    String? chatId,
    String? messageId,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final authToken = token ?? StorageService.getToken();
      final resolvedId = mediaId ?? _mediaIdFromUrl(mediaUrl);

      final cached = await MediaCacheService.instance.fileFor(resolvedId);
      if (cached != null) {
        final bytes = await cached.readAsBytes();
        onProgress?.call(bytes.length, bytes.length);
        return _writeToDownloads(fileName, bytes);
      }

      final fullUrl = mediaUrl.startsWith('http')
          ? mediaUrl
          : '${ApiConstants.baseUrl}${mediaUrl.startsWith('/') ? '' : '/'}$mediaUrl';
      
      final uri = Uri.parse(fullUrl).replace(queryParameters: {'download': '1'});

      final request = http.Request('GET', uri);
      if (authToken != null && authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.Client().send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final List<int> bytes = [];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress(received, total);
        }
      }

      final Uint8List fileBytes = Uint8List.fromList(bytes);

      // Keep our own copy so the file survives server-side data loss.
      if (resolvedId != null && resolvedId.isNotEmpty) {
        await MediaCacheService.instance.storeBytes(
          mediaId: resolvedId,
          bytes: fileBytes,
          fileName: fileName,
          chatId: chatId,
          messageId: messageId,
        );
      }

      if (kIsWeb) {
        // Web download behavior if running on web
        return fileName;
      }
      return _writeToDownloads(fileName, fileBytes);
    } catch (e) {
      debugPrint('Error downloading file: $e');
      rethrow;
    }
  }

  /// `/api/v1/media/<id>` (with or without query/host) → `<id>`.
  static String? _mediaIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const <String>[];
    final index = segments.lastIndexOf('media');
    if (index >= 0 && index + 1 < segments.length) return segments[index + 1];
    return segments.isEmpty ? null : segments.last;
  }

  static Future<String> _writeToDownloads(
    String fileName,
    Uint8List bytes,
  ) async {
    if (kIsWeb) return fileName;
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }

  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / (1 << (i * 10));
    return '${num.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
