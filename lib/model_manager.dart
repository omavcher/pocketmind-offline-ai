import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sheets_service.dart';

class LocalModel {
  final String name;
  final String filename;
  final String url;
  final String sizeStr;
  final String subtitle;
  final String imageAsset;
  final Color iconBgColor;
  final Color iconColor;
  final List<String> chips;
  final String radioText;
  final String ram;
  final int speedStars;
  final int qualityStars;
  final bool isRecommended;

  LocalModel({
    required this.name,
    required this.filename,
    required this.url,
    required this.sizeStr,
    required this.subtitle,
    required this.imageAsset,
    required this.iconBgColor,
    required this.iconColor,
    required this.chips,
    required this.radioText,
    required this.ram,
    required this.speedStars,
    required this.qualityStars,
    required this.isRecommended,
  });
}

class ModelManager {
  static final downloadProgress = ValueNotifier<double>(0.0);
  static final isDownloading = ValueNotifier<bool>(false);
  static final isPaused = ValueNotifier<bool>(false);
  static Timer? _pollingTimer;
  static const _downloadChannel = MethodChannel('com.pocketmind.app/download');

  static final List<LocalModel> availableModels = [
    LocalModel(
      name: 'Qwen 2.5 0.5B Q4_K_M',
      filename: 'Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
      url: 'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
      sizeStr: '0.40 GB',
      subtitle: 'Good quality, default size for most use cases.\nPerfect for low-end phones, fast chatting, instant response.',
      imageAsset: 'assets/images/models_logs/qwen.webp',
      iconBgColor: const Color(0xFFFFEDD5),
      iconColor: const Color(0xFFF97316),
      chips: const ['Fast', 'Low-end Phones', 'Chat'],
      radioText: 'Instant response',
      ram: '1 GB+',
      speedStars: 5,
      qualityStars: 4,
      isRecommended: true,
    ),
    LocalModel(
      name: 'Qwen 2.5 3B Q6_K',
      filename: 'Qwen2.5-3B-Instruct-Q6_K.gguf',
      url: 'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q6_K.gguf',
      sizeStr: '2.54 GB',
      subtitle: 'Very high quality, near perfect.\nHighly recommended for complex tasks.',
      imageAsset: 'assets/images/models_logs/qwen.webp',
      iconBgColor: const Color(0xFFE0E7FF),
      iconColor: const Color(0xFF6366F1),
      chips: const ['High Quality', 'Near Perfect', 'Reasoning'],
      radioText: 'Best overall quality',
      ram: '4 GB+',
      speedStars: 4,
      qualityStars: 5,
      isRecommended: true,
    ),
    LocalModel(
      name: 'Gemma 2 2B Q8',
      filename: 'gemma-2-2b-it-Q8_0.gguf',
      url: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q8_0.gguf',
      sizeStr: '2.6 GB',
      subtitle: 'Extremely high quality quant.\nMaximum available intelligence for 2B.',
      imageAsset: 'assets/images/models_logs/gemma.webp',
      iconBgColor: const Color(0xFFE0E7FF),
      iconColor: const Color(0xFF6366F1),
      chips: const ['High Quality', 'Chat', 'Reasoning'],
      radioText: 'Balanced capability',
      ram: '4 GB+',
      speedStars: 4,
      qualityStars: 5,
      isRecommended: true,
    ),
    LocalModel(
      name: 'Mistral 7B Instruct v0.2',
      filename: 'mistral-7b-instruct-v0.2.Q4_K_M.gguf',
      url: 'https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf',
      sizeStr: '4.37 GB',
      subtitle: 'Medium, balanced quality.\nGreat for larger devices with more RAM.',
      imageAsset: 'assets/images/models_logs/mistral.webp',
      iconBgColor: const Color(0xFFDCFCE7),
      iconColor: const Color(0xFF16A34A),
      chips: const ['Balanced', '7B', 'Reliable'],
      radioText: 'Standard accuracy',
      ram: '6 GB+',
      speedStars: 3,
      qualityStars: 4,
      isRecommended: true,
    ),
    LocalModel(
      name: 'TinyLlama 1.1B Q8_0',
      filename: 'tinyllama-1.1b-chat-v1.0.Q8_0.gguf',
      url: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf',
      sizeStr: '1.17 GB',
      subtitle: 'Very large, extremely low quality loss.\nNot recommended due to size vs quality ratio.',
      imageAsset: 'assets/images/models_logs/ollama.webp',
      iconBgColor: const Color(0xFFF3E8FF),
      iconColor: const Color(0xFF9333EA),
      chips: const ['Low Loss', '1.1B', 'Chat'],
      radioText: 'Low quality loss',
      ram: '2 GB+',
      speedStars: 5,
      qualityStars: 3,
      isRecommended: false,
    ),
    LocalModel(
      name: 'TinyLlama 1.1B Chat',
      filename: 'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
      url: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf?download=true',
      sizeStr: '483 MB',
      subtitle: 'Fast and lightweight.\nPerfect for older devices or basic tasks.',
      imageAsset: 'assets/images/models_logs/ollama.webp',
      iconBgColor: const Color(0xFFFFEDD5),
      iconColor: const Color(0xFFF97316),
      chips: const ['Lightweight', 'Chat', 'Fast'],
      radioText: 'Fastest experience',
      ram: '1 GB+',
      speedStars: 5,
      qualityStars: 3,
      isRecommended: false,
    ),
  ];


  static Future<Directory> getModelsDirectory() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory();
    }
    baseDir ??= await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${baseDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  static Future<void> migrateModelsToExternal() async {
    if (!Platform.isAndroid) return;
    try {
      final internalBase = await getApplicationDocumentsDirectory();
      final internalDir = Directory('${internalBase.path}/models');
      if (await internalDir.exists()) {
        final externalDir = await getModelsDirectory();
        final files = internalDir.listSync();
        for (var entity in files) {
          if (entity is File && entity.path.endsWith('.gguf')) {
            final fileName = entity.path.split('/').last;
            final targetFile = File('${externalDir.path}/$fileName');
            if (!await targetFile.exists()) {
              await entity.copy(targetFile.path);
            }
            await entity.delete();
          }
        }
        try {
          await internalDir.delete(recursive: true);
        } catch (_) {}
        debugPrint('Pocket Mind: Models migrated to external storage successfully');
      }
    } catch (e) {
      debugPrint('Pocket Mind: Error migrating models to external: $e');
    }
  }

  static Future<List<File>> getInstalledModels() async {
    final dir = await getModelsDirectory();
    if (!await dir.exists()) return [];
    final files = dir.listSync();
    return files.whereType<File>().where((f) => f.path.endsWith('.gguf')).toList();
  }

  static Future<bool> isModelInstalled(String filename) async {
    final dir = await getModelsDirectory();
    final file = File('${dir.path}/$filename');
    return await file.exists();
  }

  static Future<void> deleteModel(String filename) async {
    final dir = await getModelsDirectory();
    final file = File('${dir.path}/$filename');
    if (await file.exists()) {
      await file.delete();
    }
    
    final prefs = await SharedPreferences.getInstance();
    final activeModel = prefs.getString('active_model');
    if (activeModel == filename) {
      await prefs.remove('active_model');
    }
  }

  static Future<String?> getActiveModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final activeFilename = prefs.getString('active_model');
    if (activeFilename == null) return null;
    
    final dir = await getModelsDirectory();
    final path = '${dir.path}/$activeFilename';
    if (await File(path).exists()) {
      return path;
    }
    return null;
  }

  static Future<void> setActiveModel(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_model', filename);
    // Sync change to Google Sheets
    SheetsService.syncUser(selectedModel: filename);
  }

  static const _storageChannel = MethodChannel('com.pocketmind.app/storage');

  static Future<Map<String, double>> getStorageInfo() async {
    try {
      final result = await _storageChannel.invokeMethod<Map<dynamic, dynamic>>('getStorageInfo');
      if (result != null) {
        return {
          'total': (result['total'] as num).toDouble(),
          'free': (result['free'] as num).toDouble(),
        };
      }
    } catch (e) {
      debugPrint('Error getting storage info via native channel: $e');
    }
    return {'total': 0, 'free': 0};
  }

  static Future<void> downloadModel({
    required LocalModel model,
    required void Function(double progress) onProgress,
    required VoidCallback onSuccess,
    required void Function(String error) onError,
  }) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }

      final downloadId = await _downloadChannel.invokeMethod<int>('enqueueDownload', {
        'url': model.url,
        'filename': model.filename,
        'title': model.name,
      });

      if (downloadId == null || downloadId == -1) {
        onError('Could not start download');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('download_id_${model.filename}', downloadId);

      isDownloading.value = true;
      isPaused.value = false;
      downloadProgress.value = 0.0;

      _startPolling(downloadId, model, onProgress, onSuccess, onError);
    } catch (e) {
      onError(e.toString());
    }
  }

  static void _startPolling(
    int downloadId,
    LocalModel model,
    void Function(double progress) onProgress,
    VoidCallback onSuccess,
    void Function(String error) onError,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final statusData = await _downloadChannel.invokeMapMethod<String, dynamic>(
          'getDownloadStatus',
          {'downloadId': downloadId},
        );

        if (statusData == null) return;

        final status = statusData['status'] as String?;
        final bytesDownloaded = (statusData['bytesDownloaded'] as num?)?.toDouble() ?? 0.0;
        final bytesTotal = (statusData['bytesTotal'] as num?)?.toDouble() ?? 0.0;

        if (status == 'notFound') {
          timer.cancel();
          isDownloading.value = false;
          isPaused.value = false;
          onError('Download task not found or removed');
          return;
        }

        double progress = 0.0;
        if (bytesTotal > 0) {
          progress = bytesDownloaded / bytesTotal;
          if (progress > 1.0) progress = 1.0;
          if (progress < 0.0) progress = 0.0;
        }

        downloadProgress.value = progress;
        onProgress(progress);

        if (status == 'successful') {
          timer.cancel();
          isDownloading.value = false;
          isPaused.value = false;
          
          await setActiveModel(model.filename);
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('download_id_${model.filename}');
          
          onSuccess();
        } else if (status == 'failed') {
          timer.cancel();
          isDownloading.value = false;
          isPaused.value = false;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('download_id_${model.filename}');
          
          final reason = statusData['reason'] as int?;
          onError('Download failed (code: $reason)');
        } else if (status == 'paused') {
          isPaused.value = true;
        } else if (status == 'running') {
          isPaused.value = false;
        }
      } catch (e) {
        debugPrint('Error polling download status: $e');
      }
    });
  }

  static Future<void> pauseDownload(LocalModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadId = prefs.getInt('download_id_${model.filename}');
    if (downloadId != null) {
      final success = await _downloadChannel.invokeMethod<bool>('pauseDownload', {'downloadId': downloadId});
      if (success == true) {
        isPaused.value = true;
      }
    }
  }

  static Future<void> resumeDownload(LocalModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadId = prefs.getInt('download_id_${model.filename}');
    if (downloadId != null) {
      final success = await _downloadChannel.invokeMethod<bool>('resumeDownload', {'downloadId': downloadId});
      if (success == true) {
        isPaused.value = false;
      }
    }
  }

  static Future<void> cancelDownload(LocalModel model) async {
    _pollingTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    final downloadId = prefs.getInt('download_id_${model.filename}');
    if (downloadId != null) {
      await _downloadChannel.invokeMethod('cancelDownload', {'downloadId': downloadId});
      await prefs.remove('download_id_${model.filename}');
    }
    isDownloading.value = false;
    isPaused.value = false;
    downloadProgress.value = 0.0;
  }

  static Future<void> resumeExistingDownloads() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (var model in availableModels) {
        final downloadId = prefs.getInt('download_id_${model.filename}');
        if (downloadId != null) {
          final statusData = await _downloadChannel.invokeMapMethod<String, dynamic>(
            'getDownloadStatus',
            {'downloadId': downloadId},
          );
          if (statusData != null) {
            final status = statusData['status'] as String?;
            if (status == 'running' || status == 'paused' || status == 'pending') {
              isDownloading.value = true;
              isPaused.value = status == 'paused';
              
              final bytesDownloaded = (statusData['bytesDownloaded'] as num?)?.toDouble() ?? 0.0;
              final bytesTotal = (statusData['bytesTotal'] as num?)?.toDouble() ?? 0.0;
              if (bytesTotal > 0) {
                downloadProgress.value = bytesDownloaded / bytesTotal;
              }
              
              _startPolling(
                downloadId,
                model,
                (p) => downloadProgress.value = p,
                () => isDownloading.value = false,
                (err) {
                  isDownloading.value = false;
                  debugPrint('Pocket Mind: Resume download failed: $err');
                },
              );
              break;
            } else {
              await prefs.remove('download_id_${model.filename}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Pocket Mind: Error resuming existing downloads: $e');
    }
  }
}
