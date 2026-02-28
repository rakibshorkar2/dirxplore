import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';

class DownloadTab extends StatelessWidget {
  const DownloadTab({super.key});

  @override
  Widget build(BuildContext context) {
    final dlProvider = context.watch<DownloadProvider>();
    final queue = dlProvider.queue;

    // Grouping logic
    final Map<String?, List<DownloadItem>> grouped = {};
    for (var item in queue) {
      grouped.putIfAbsent(item.batchId, () => []).add(item);
    }

    final batchIds = grouped.keys.toList();
    // Move "null" (Singles) to the end or start? Let's keep them at the top if any.
    batchIds.sort((a, b) {
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            tooltip: 'Pause All',
            onPressed: dlProvider.pauseAll,
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Resume All',
            onPressed: dlProvider.resumeAll,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Done',
            onPressed: dlProvider.clearDone,
          ),
        ],
      ),
      body: queue.isEmpty
          ? const Center(child: Text('Download queue is empty.'))
          : ListView.builder(
              itemCount: batchIds.length,
              itemBuilder: (context, index) {
                final bId = batchIds[index];
                final items = grouped[bId]!;

                if (bId == null) {
                  // Single files
                  return Column(
                    children: items.map((item) => _buildDownloadCard(context, dlProvider, item)).toList(),
                  );
                } else {
                  // Batch / Folder
                  return _buildBatchTile(context, dlProvider, items);
                }
              },
            ),
    );
  }

  Widget _buildBatchTile(BuildContext context, DownloadProvider dlProvider, List<DownloadItem> items) {
    final batchName = items.first.batchName ?? 'Folder Download';
    final totalBytes = items.fold<int>(0, (sum, item) => sum + item.totalBytes);
    final downloadedBytes = items.fold<int>(0, (sum, item) => sum + item.downloadedBytes);
    final progress = totalBytes > 0 ? (downloadedBytes / totalBytes) : 0.0;
    final doneCount = items.where((i) => i.status == DownloadStatus.done).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(batchName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text('$doneCount of \${items.length} files done', style: const TextStyle(fontSize: 12)),
          ],
        ),
        children: items.map((item) => _buildDownloadCard(context, dlProvider, item, isNested: true)).toList(),
      ),
    );
  }

  Widget _buildDownloadCard(BuildContext context, DownloadProvider dlProvider, DownloadItem item, {bool isNested = false}) {
    return Card(
      elevation: isNested ? 0 : 1,
      color: isNested ? Colors.transparent : null,
      margin: isNested ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.fileName,
              style: TextStyle(fontWeight: isNested ? FontWeight.normal : FontWeight.bold, fontSize: isNested ? 13 : 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: item.progress),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatSpeedAndETA(item),
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  item.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: item.status == DownloadStatus.error
                        ? Colors.red
                        : (item.status == DownloadStatus.done ? Colors.green : Colors.blue),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (item.errorMessage != null)
               Text(item.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 10)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued)
                  IconButton(
                    icon: const Icon(Icons.pause, color: Colors.orange, size: 20),
                    onPressed: () => dlProvider.pause(item.id),
                  ),
                if (item.status == DownloadStatus.paused || item.status == DownloadStatus.error)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green, size: 20),
                    onPressed: () => dlProvider.resume(item.id),
                  ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.red, size: 20),
                  onPressed: () => dlProvider.stop(item.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSpeedAndETA(DownloadItem item) {
    if (item.status == DownloadStatus.done) return 'Completed';
    if (item.status == DownloadStatus.error) return 'Failed';
    if (item.speedBytesPerSec == 0) return '0 B/s | ETA: --';

    String speedStr = '';
    if (item.speedBytesPerSec > 1024 * 1024) {
      speedStr = '${(item.speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (item.speedBytesPerSec > 1024) {
      speedStr = '${(item.speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      speedStr = '${item.speedBytesPerSec.toStringAsFixed(0)} B/s';
    }

    int mm = item.etaSeconds ~/ 60;
    int ss = item.etaSeconds % 60;
    int hh = mm ~/ 60;
    mm = mm % 60;

    String etaStr = hh > 0 ? '${hh}h ${mm}m ${ss}s' : '${mm}m ${ss}s';

    return '$speedStr | ETA: $etaStr';
  }
}
