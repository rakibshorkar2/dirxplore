void main() {
  final baseUrl = 'http://172.16.50.14/DHAKA-FLIX-14/';
  
  final hrefs = [
    'Animation Movies/',
    '/DHAKA-FLIX-14/Animation Movies/',
    'Action Movies (2002)/',
    '../',
    'http://example.com/test'
  ];

  final baseUri = Uri.parse(baseUrl);
  
  for (final href in hrefs) {
    try {
      final resolved = baseUri.resolve(href);
      print("href: '\$href' -> \${resolved.toString()}");
    } catch (e) {
      print("Failed to resolve '\$href': \$e");
    }
  }
}
