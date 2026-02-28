import 'package:html/parser.dart' as html_parser;

void main() {
  final baseUrl = 'http://172.16.50.14/DHAKA-FLIX-14/';
  final htmlContent = '''
    <html>
      <body>
        <a href="/DHAKA-FLIX-14/Animation Movies/">Animation Movies</a>
        <a href="Action Movies/">Action Movies</a>
      </body>
    </html>
  ''';

  final document = html_parser.parse(htmlContent);
  final anchors = document.querySelectorAll('a');
  for (final a in anchors) {
    final href = a.attributes['href'];
    if (href == null) continue;

    String itemUrl;
    if (href.startsWith('http://') || href.startsWith('https://')) {
      itemUrl = href;
    } else if (href.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      itemUrl = '\${uri.scheme}://\${uri.host}:\${uri.port}$href';
    } else {
      String normalizedBase = baseUrl;
      if (!normalizedBase.endsWith('/')) normalizedBase += '/';
      itemUrl = '$normalizedBase$href';
    }
    print("href: $href -> $itemUrl");
  }
}
