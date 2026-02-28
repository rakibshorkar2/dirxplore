import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/directory_item.dart';

class HtmlParserService {
  static Future<List<DirectoryItem>> parseApacheDirectoryAsync(String htmlContent, String baseUrl) async {
    return compute(_parseInternal, {'html': htmlContent, 'baseUrl': baseUrl});
  }

  static List<DirectoryItem> _parseInternal(Map<String, String> data) {
    return parseApacheDirectory(data['html']!, data['baseUrl']!);
  }

  static List<DirectoryItem> parseApacheDirectory(String htmlContent, String baseUrl) {
    final items = <DirectoryItem>[];
    
    try {
      final document = html_parser.parse(htmlContent);
      
      // Typical Apache/Nginx open directory structure:
      // <tr><td><a href="filename.ext">filename.ext</a></td><td align="right">Size</td>...</tr>
      // Or just a bunch of <a href="..."> links.
      
      final anchors = document.querySelectorAll('a');
      for (final a in anchors) {
        final href = a.attributes['href'];
        final text = a.text.trim();

        if (href == null || href.isEmpty) continue;
        
        // Skip parent directory links
        if (href == '../' || text.toLowerCase() == 'parent directory' || text == 'Name' || text == 'Size' || text == 'Date') {
          continue;
        }

        // Check if it's a directory (usually ends with '/')
        bool isDir = href.endsWith('/');
        String name = text;
        if (isDir && name.endsWith('/')) {
          name = name.substring(0, name.length - 1);
        }

        // Attempt to extract size from adjacent row cells if in a table
        String? sizeStr;
        Element? parent = a.parent;
        if (parent != null && parent.localName == 'td') {
          Element? row = parent.parent;
          if (row != null && row.localName == 'tr') {
            final cells = row.querySelectorAll('td');
            if (cells.length >= 4) {
              sizeStr = cells[3].text.trim();
              if (sizeStr == '-') sizeStr = '';
            }
          }
        }
        
        // Fallback for pre-formatted listings:
        if (sizeStr == null || sizeStr.isEmpty) {
          // You'd need regex to parse <pre> tags reliably. 
        }

        // Construct absolute URL and properly encode paths
        String itemUrl;
        try {
          final baseUri = Uri.parse(baseUrl);
          itemUrl = baseUri.resolve(href).toString();
        } catch (_) {
          continue; // Skip mathematically invalid URIs
        }

        items.add(DirectoryItem(
          name: name,
          url: itemUrl,
          type: isDir ? DirectoryItemType.directory : DirectoryItem.typeFromExtension(name),
          size: sizeStr,
        ));
      }
    } catch (e) {
      print("Error parsing HTML: $e");
    }
    
    return items;
  }
}
