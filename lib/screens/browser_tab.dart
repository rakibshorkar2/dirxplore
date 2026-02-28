import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/browser_provider.dart';
import '../providers/download_provider.dart';
import '../providers/app_state.dart';

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default URL for starting point
    _urlCtrl.text = 'http://172.16.50.4/';
    
    // Automatically load the default URL on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BrowserProvider>().loadUrl(_urlCtrl.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final browserState = context.watch<BrowserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Directory Browser'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              children: [
                // URL Bar Row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: browserState.canGoBack ? browserState.goBack : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: browserState.goUp,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter URL (http://...)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (val) => browserState.loadUrl(val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => browserState.loadUrl(_urlCtrl.text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search/Filter...',
                          prefixIcon: Icon(Icons.filter_list),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: browserState.setSearchQuery,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: browserState.selectedCategory,
                      items: browserState.categories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) browserState.setCategory(val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(browserState.isGridView ? Icons.list : Icons.grid_view),
            tooltip: 'Toggle View',
            onPressed: browserState.toggleViewMode,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Toggle Sort Options',
            onPressed: browserState.toggleSort,
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb Trail
          if (browserState.breadcrumbs.isNotEmpty)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: browserState.breadcrumbs.length,
                separatorBuilder: (c, i) => const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      browserState.loadBreadcrumb(index);
                      _urlCtrl.text = browserState.currentUrl;
                    },
                    child: Center(
                      child: Text(
                        browserState.breadcrumbs[index],
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: browserState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : browserState.errorMessage.isNotEmpty
                    ? Center(child: Text(browserState.errorMessage, style: const TextStyle(color: Colors.red)))
                    : (browserState.isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.all(8.0),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: browserState.items.length,
                            itemBuilder: (context, index) {
                              final item = browserState.items[index];
                              return InkWell(
                                onTap: () {
                                  if (item.isDirectory) {
                                    _urlCtrl.text = item.url;
                                    browserState.loadUrl(item.url);
                                  }
                                },
                                onLongPress: () => browserState.toggleSelection(item),
                                child: Card(
                                  color: item.isSelected 
                                      ? Theme.of(context).colorScheme.primaryContainer 
                                      : null,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          Icon(
                                            item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                                            size: 48,
                                            color: item.isDirectory ? Colors.amber : Colors.blueGrey,
                                          ),
                                          if (item.isSelected) 
                                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            itemExtent: 72.0, // Significant performance boost for large lists
                            itemCount: browserState.items.length,
                            itemBuilder: (context, index) {
                              final item = browserState.items[index];
                              return ListTile(
                                leading: Icon(
                                  item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                                  color: item.isDirectory ? Colors.amber : Colors.blueGrey,
                                ),
                                title: Text(item.name),
                                subtitle: item.size != null && item.size!.isNotEmpty ? Text(item.size!) : null,
                                trailing: Checkbox(
                                  value: item.isSelected,
                                  onChanged: (val) => browserState.toggleSelection(item),
                                ),
                                onTap: () {
                                  if (item.isDirectory) {
                                    _urlCtrl.text = item.url;
                                    browserState.loadUrl(item.url);
                                  } else {
                                    browserState.toggleSelection(item);
                                  }
                                },
                              );
                            },
                          )),
          ),
        ],
      ),
      floatingActionButton: browserState.getSelectedItems().isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                 bool hasPermission = false;
                 if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
                   hasPermission = true;
                 } else {
                   final statusManage = await Permission.manageExternalStorage.request();
                   final statusStorage = await Permission.storage.request();
                   if (statusManage.isGranted || statusStorage.isGranted) {
                     hasPermission = true;
                   }
                 }

                 if (!hasPermission) {
                    if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Storage permission is required to download files.')),
                       );
                    }
                    return;
                 }

                 final dlProvider = context.read<DownloadProvider>();
                 final appState = context.read<AppState>();
                 final selected = browserState.getSelectedItems();
                 
                 for (var item in selected) {
                    if (item.isDirectory) {
                      dlProvider.addRecursiveDownload(item.url, item.name, appState.defaultSavePath);
                    } else {
                      dlProvider.addDownload(item.url, item.name, appState.defaultSavePath);
                    }
                 }
                 
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Added ${selected.length} items to queue')),
                   );
                 }
                 
                 browserState.selectAll(false);
              },
              icon: const Icon(Icons.download),
              label: Text('Queue Selected (${browserState.getSelectedItems().length})'),
            )
          : null,
    );
  }
}
