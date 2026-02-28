import 'package:flutter/foundation.dart';
import '../models/directory_item.dart';
import '../services/dio_client.dart';
import '../services/html_parser.dart';
import 'package:dio/dio.dart';

class BrowserProvider with ChangeNotifier {
  final List<String> _history = [];
  String _currentUrl = '';
  List<DirectoryItem> _items = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Sorting & Filtering
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  bool _foldersFirst = true;

  String get currentUrl => _currentUrl;
  List<DirectoryItem> get items => _getFilteredAndSortedItems();
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get canGoBack => _history.length > 1;

  final Map<String, List<String>> _categories = {
    'All Categories': [],
    'Movies': ['1080p', '720p', 'bluray', 'mkv', 'mp4', 'avi', 'movie'],
    'Series/TV': ['s01', 'e01', 'season', 'episode', 'hdtv'],
    'Games': ['repack', 'iso', 'codex', 'skidrow', 'fitgirl', 'pc'],
    'Software': ['crack', 'keygen', 'setup', 'exe', 'mac', 'win'],
    'Anime': ['anime', 'sub', 'dub', '1080p', '720p', 'mkv'],
    'Images': ['jpg', 'png', 'gif', 'jpeg', 'webp'],
  };

  bool _isGridView = false;
  bool get isGridView => _isGridView;

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }
  
  List<String> get breadcrumbs {
    if (_currentUrl.isEmpty) return [];
    try {
      final uri = Uri.parse(_currentUrl);
      return [uri.host, ...uri.pathSegments.where((p) => p.isNotEmpty)];
    } catch (_) {
      return [];
    }
  }

  List<String> get categories => _categories.keys.toList();
  String get selectedCategory => _selectedCategory;

  void setCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q.toLowerCase();
    notifyListeners();
  }

  void toggleSort() {
    _foldersFirst = !_foldersFirst;
    notifyListeners();
  }

  void toggleSelection(DirectoryItem item) {
    item.isSelected = !item.isSelected;
    notifyListeners();
  }
  
  void selectAll(bool select) {
    for (var item in _items) {
      item.isSelected = select;
    }
    notifyListeners();
  }

  List<DirectoryItem> getSelectedItems() {
    return _items.where((i) => i.isSelected).toList();
  }

  void goBack() {
    if (canGoBack) {
      _history.removeLast();
      _loadUrl(_history.last, addToHistory: false);
    }
  }

  void goUp() {
    if (_currentUrl.isEmpty) return;
    try {
      final uri = Uri.parse(_currentUrl);
      final paths = uri.pathSegments.where((p) => p.isNotEmpty).toList();
      if (paths.isNotEmpty) {
        paths.removeLast();
        final newUri = uri.replace(pathSegments: paths);
        String finalUrl = newUri.toString();
        if (!finalUrl.endsWith('/')) finalUrl += '/';
        _loadUrl(finalUrl, addToHistory: true);
      }
    } catch (_) {}
  }

  void loadBreadcrumb(int index) {
    if (_currentUrl.isEmpty) return;
    try {
      final uri = Uri.parse(_currentUrl);
      final paths = uri.pathSegments.where((p) => p.isNotEmpty).toList();
      if (index == 0) {
        _loadUrl('${uri.scheme}://${uri.host}/', addToHistory: true);
      } else if (index <= paths.length) {
        final newPaths = paths.sublist(0, index);
        final newUri = uri.replace(pathSegments: newPaths);
        String finalUrl = newUri.toString();
        if (!finalUrl.endsWith('/')) finalUrl += '/';
        _loadUrl(finalUrl, addToHistory: true);
      }
    } catch (_) {}
  }

  Future<void> loadUrl(String url) async {
    if (!url.startsWith('http')) url = 'http://$url';
    if (!url.endsWith('/')) url += '/';
    _loadUrl(url, addToHistory: true);
  }

  Future<void> _loadUrl(String url, {bool addToHistory = true}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final dio = DioClient().dio;
      final response = await dio.get(url);
      
      final htmlStr = response.data.toString();
      _items = await HtmlParserService.parseApacheDirectoryAsync(htmlStr, url);
      
      _currentUrl = url;
      if (addToHistory) {
        if (_history.isEmpty || _history.last != url) {
          _history.add(url);
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        _errorMessage = 'Connection Timed Out. Please check your proxy or network.';
      } else {
        _errorMessage = 'Network Error: ${e.message ?? e.error?.toString() ?? "Unknown connection issue."}';
      }
      _items = [];
    } catch (e) {
      _errorMessage = 'Error parsing directory: $e';
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DirectoryItem> _getFilteredAndSortedItems() {
    var filtered = _items;

    // Apply Search Query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((i) => i.name.toLowerCase().contains(_searchQuery)).toList();
    }

    // Apply Category keywords
    if (_selectedCategory != 'All Categories') {
      final keywords = _categories[_selectedCategory]!;
      filtered = filtered.where((i) {
        final nameL = i.name.toLowerCase();
        return i.isDirectory || keywords.any((k) => nameL.contains(k));
      }).toList();
    }

    // Apply Sorting
    filtered.sort((a, b) {
      if (_foldersFirst) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }
}
