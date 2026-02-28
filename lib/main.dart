import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/proxy_provider.dart';
import 'providers/download_provider.dart';
import 'providers/browser_provider.dart';

import 'screens/browser_tab.dart';
import 'screens/download_tab.dart';
import 'screens/proxy_tab.dart';
import 'screens/settings_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appState = AppState();
  await appState.init();
  
  final proxyProvider = AppProxyProvider();
  await proxyProvider.init();

  final dlProvider = DownloadProvider();
  await dlProvider.init();
  dlProvider.setMaxConcurrent(appState.maxConcurrentDownloads);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: proxyProvider),
        ChangeNotifierProvider.value(value: dlProvider),
        ChangeNotifierProvider(create: (_) => BrowserProvider()),
      ],
      child: const OpenDirApp(),
    ),
  );
}

class OpenDirApp extends StatelessWidget {
  const OpenDirApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return MaterialApp(
      title: 'OpenDir Browser',
      themeMode: appState.themeMode,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple, 
          brightness: Brightness.dark
        ),
      ),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const BrowserTab(),
    const DownloadTab(),
    const ProxyTab(),
    const SettingsTab(),
  ];

  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        
        final now = DateTime.now();
        final maxDuration = const Duration(seconds: 2);
        final isWarning = _lastPressedAt == null || now.difference(_lastPressedAt!) > maxDuration;

        if (isWarning) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // Exit app
        Navigator.pop(context); // Optional depending on router but generally system channel is better:
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.explore), label: 'Browser'),
            NavigationDestination(icon: Icon(Icons.download), label: 'Downloads'),
            NavigationDestination(icon: Icon(Icons.security), label: 'Proxy'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
