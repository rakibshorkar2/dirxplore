import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import '../services/dio_client.dart';
import '../services/html_parser.dart';

class DownloadProvider with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.example.nexus/downloads');
  final List<DownloadItem> _queue = [];
  final Map<String, CancelToken> _cancelTokens = {};
  int _maxConcurrent = 3;
  int _activeCount = 0;

  List<DownloadItem> get queue => _queue;

  Future<void> init() async {
    await _loadQueue();
  }

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('download_queue');
    if (jsonStr != null) {
      final List<dynamic> list = jsonDecode(jsonStr);
      _queue.clear();
      _queue.addAll(list.map((item) => DownloadItem.fromJson(item)).toList());
      notifyListeners();
      _processQueue();
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_queue.map((item) => item.toJson()).toList());
    await prefs.setString('download_queue', jsonStr);
  }

  void setMaxConcurrent(int max) {
    _maxConcurrent = max;
    _processQueue();
  }

  void addDownload(String url, String fileName, String saveDir, {String? batchId, String? batchName}) {
    // Check if exactly identical item exists in queue
    if (_queue.any((i) => i.url == url)) {
      final existing = _queue.firstWhere((i) => i.url == url);
      if (existing.status == DownloadStatus.paused || existing.status == DownloadStatus.error) {
        resume(existing.id);
      }
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString() + '_' + url.hashCode.toString();
    final savePath = p.join(saveDir, fileName);
    
    _queue.add(DownloadItem(
      id: id,
      url: url,
      fileName: fileName,
      savePath: savePath,
      batchId: batchId,
      batchName: batchName,
    ));
    
    _saveQueue();
    notifyListeners();
    _processQueue();
  }

  void addRecursiveDownload(String folderUrl, String folderName, String baseSaveDir) {
    final batchId = DateTime.now().millisecondsSinceEpoch.toString();
    _crawlAndQueue(folderUrl, p.join(baseSaveDir, folderName), batchId, folderName);
  }

  Future<void> _crawlAndQueue(String folderUrl, String targetDir, String batchId, String batchName) async {
    try {
      final dio = DioClient().dio;
      final response = await dio.get(folderUrl);
      final htmlStr = response.data.toString();
      final items = await HtmlParserService.parseApacheDirectoryAsync(htmlStr, folderUrl);
      
      for (var item in items) {
        if (item.isDirectory) {
          await _crawlAndQueue(item.url, p.join(targetDir, item.name), batchId, batchName);
        } else {
          // Filter to only download movies and subtitles automatically
          final ext = item.name.split('.').last.toLowerCase();
          const allowedExtensions = ['mp4', 'mkv', 'avi', 'mov', 'webm', 'srt', 'vtt', 'sub'];
          if (allowedExtensions.contains(ext)) {
            addDownload(item.url, item.name, targetDir, batchId: batchId, batchName: batchName);
          }
        }
      }
    } catch (e) {
      print("Error crawling $folderUrl: $e");
    }
  }

  void pause(String id) {
    _cancelTokens[id]?.cancel('Paused by user');
    _cancelTokens.remove(id);
    
    final item = _queue.firstWhere((i) => i.id == id);
    item.status = DownloadStatus.paused;
    item.speedBytesPerSec = 0;
    
    // Stop foreground service if this was the last active
    _stopForegroundIfNoActive();
    
    _activeCount--;
    _saveQueue();
    notifyListeners();
    _processQueue();
  }

  void _stopForegroundIfNoActive() {
    if (_activeCount <= 1) { // 1 because we are about to decrement
      _channel.invokeMethod('stopForegroundService', {'id': 0}).catchError((_) {});
    }
  }

  void resume(String id) {
    final item = _queue.firstWhere((i) => i.id == id);
    item.status = DownloadStatus.queued;
    item.errorMessage = null;
    _saveQueue();
    notifyListeners();
    _processQueue();
  }

  void stop(String id) {
    _cancelTokens[id]?.cancel('Stopped by user');
    _cancelTokens.remove(id);
    _queue.removeWhere((i) => i.id == id);
    if (_activeCount > 0) {
      _stopForegroundIfNoActive();
      _activeCount--;
    }
    _saveQueue();
    notifyListeners();
    _processQueue();
  }

  void clearDone() {
    _queue.removeWhere((i) => i.status == DownloadStatus.done || i.status == DownloadStatus.error);
    _saveQueue();
    notifyListeners();
  }

  void clearAll() {
    for (final token in _cancelTokens.values) {
      token.cancel('Cleared');
    }
    _cancelTokens.clear();
    _queue.clear();
    _activeCount = 0;
    _saveQueue();
    notifyListeners();
  }

  void pauseAll() {
    for (final id in _cancelTokens.keys.toList()) {
      pause(id);
    }
  }

  void resumeAll() {
    for (final item in _queue) {
      if (item.status == DownloadStatus.paused || item.status == DownloadStatus.error) {
        resume(item.id);
      }
    }
  }

  Future<void> _processQueue() async {
    while (_activeCount < _maxConcurrent) {
      final nextItem = _queue.firstWhere(
        (i) => i.status == DownloadStatus.queued,
        orElse: () => DownloadItem(id: '', url: '', fileName: '', savePath: ''),
      );

      if (nextItem.id.isEmpty) break; // Nothing to download

      _startDownload(nextItem);
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    _activeCount++;
    item.status = DownloadStatus.downloading;
    notifyListeners();

    // Start Foreground Service
    _channel.invokeMethod('startForegroundService', {
      'url': item.url,
      'filename': item.fileName,
      'id': 0, // In a real app with multiple concurrent progress bars, pass unique IDs
    }).catchError((_) {});

    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    final file = File(item.savePath);
    int existingBytes = 0;
    
    if (await file.exists()) {
      existingBytes = await file.length();
    }
    
    item.downloadedBytes = existingBytes;

    DateTime lastUpdate = DateTime.now();
    int bytesSinceLastUpdate = 0;

    try {
      final dio = DioClient().dio;
      
      final response = await dio.get<ResponseBody>(
        item.url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: existingBytes > 0 ? {'Range': 'bytes=$existingBytes-'} : null,
        ),
      );

      final totalHeader = response.headers.value(HttpHeaders.contentLengthHeader) ?? '-1';
      final total = int.tryParse(totalHeader) ?? -1;
      
      if (response.statusCode == 416) {
         // Server responded Range Not Satisfiable: We already have the complete file!
         item.status = DownloadStatus.done;
         item.speedBytesPerSec = 0;
         item.etaSeconds = 0;
         item.downloadedBytes = existingBytes;
         item.totalBytes = existingBytes;
         _cancelTokens.remove(item.id);
         return; // finally block will cleanup concurrency
      }

      if (total != -1) {
        if (response.statusCode == 206) {
           item.totalBytes = existingBytes + total;
        } else {
           // Server ignored range request
           item.totalBytes = total;
           existingBytes = 0; // The file will be overwritten
        }
      }

      final dir = Directory(p.dirname(item.savePath));
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (e) {
          // OS Error: A file exists with the exact same name as the target directory.
          // This happens if the user clicked the folder "as a file" before updates.
          final fileInWay = File(dir.path);
          if (await fileInWay.exists()) {
             await fileInWay.delete();
             await dir.create(recursive: true);
          } else {
             rethrow;
          }
        }
      }

      final raf = file.openSync(mode: existingBytes > 0 && response.statusCode == 206 ? FileMode.append : FileMode.write);
      final stream = response.data!.stream;
      final completer = Completer<void>();
      late StreamSubscription subscription;

      subscription = stream.listen(
        (chunk) {
          if (cancelToken.isCancelled) {
             subscription.cancel();
             raf.closeSync();
             if (!completer.isCompleted) {
               completer.completeError(DioException.requestCancelled(requestOptions: response.requestOptions!, reason: "Cancelled"), StackTrace.current);
             }
             return;
          }
          try {
             raf.writeFromSync(chunk);
             item.downloadedBytes += chunk.length;
             bytesSinceLastUpdate += chunk.length;

             final now = DateTime.now();
             final diff = now.difference(lastUpdate).inMilliseconds;
             
             if (diff > 1000) { 
               item.speedBytesPerSec = (bytesSinceLastUpdate / (diff / 1000)).toDouble();
               if (item.speedBytesPerSec > 0 && item.totalBytes > 0) {
                 final remaining = item.totalBytes - item.downloadedBytes;
                 item.etaSeconds = (remaining / item.speedBytesPerSec).round();
               }
               
               int progressPercent = 0;
               if (item.totalBytes > 0) {
                  progressPercent = ((item.downloadedBytes / item.totalBytes) * 100).toInt();
               }
               _channel.invokeMethod('updateProgress', {
                 'id': 0,
                 'progress': progressPercent,
                 'speed': '${(item.speedBytesPerSec / 1024 / 1024).toStringAsFixed(2)} MB/s',
               }).catchError((_) {});

               lastUpdate = now;
               bytesSinceLastUpdate = 0;
               notifyListeners();
             }
          } catch(e) {
             subscription.cancel();
             raf.closeSync();
             if (!completer.isCompleted) completer.completeError(e, StackTrace.current);
          }
        },
        onDone: () {
          raf.closeSync();
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e, st) {
          raf.closeSync();
          if (!completer.isCompleted) completer.completeError(e, st);
        },
        cancelOnError: true,
      );

      await completer.future;

      item.status = DownloadStatus.done;
      item.speedBytesPerSec = 0;
      item.etaSeconds = 0;
      item.downloadedBytes = item.totalBytes;
      _cancelTokens.remove(item.id);
      _saveQueue();

    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // Paused intentionally, status already updated
      } else if (e.response?.statusCode == 416) {
        // Catches strictly HTTP 416 Range Not Satisfiable inside Dio validation exceptions
        item.status = DownloadStatus.done;
        item.speedBytesPerSec = 0;
        item.etaSeconds = 0;
        item.downloadedBytes = item.totalBytes > 0 ? item.totalBytes : existingBytes;
        _cancelTokens.remove(item.id);
        _saveQueue();
      } else {
        if (item.retryCount < 3) {
          item.retryCount++;
          item.status = DownloadStatus.queued;
        } else {
          item.status = DownloadStatus.error;
          item.errorMessage = e.message;
        }
        _cancelTokens.remove(item.id);
        _saveQueue();
      }
    } catch (e) {
      item.status = DownloadStatus.error;
      item.errorMessage = e.toString();
      _cancelTokens.remove(item.id);
      _saveQueue();
    } finally {
      if (_activeCount > 0) {
         _stopForegroundIfNoActive();
         _activeCount--;
      }
      _saveQueue();
      notifyListeners();
      _processQueue();
    }
  }
}
