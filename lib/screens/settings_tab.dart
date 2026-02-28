import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../services/github_updater.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // UI Settings
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('UI & APPEARANCE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: appState.themeMode,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (val) {
                if (val != null) appState.setThemeMode(val);
              },
            ),
          ),
          const Divider(),

          // Download Settings
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('DOWNLOAD SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Default Save Directory'),
            subtitle: Text(appState.defaultSavePath),
            trailing: IconButton(
              icon: const Icon(Icons.folder),
              onPressed: () async {
                String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                if (selectedDirectory != null) {
                  appState.setDefaultSavePath(selectedDirectory);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Max Concurrent Downloads'),
            subtitle: Text('${appState.maxConcurrentDownloads} files at once'),
            trailing: DropdownButton<int>(
              value: appState.maxConcurrentDownloads,
              items: [1,2,3,4,5,10].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
              onChanged: (val) {
                if(val != null) appState.setMaxConcurrentDownloads(val);
              },
            ),
          ),
          const Divider(),

          // About & Updates
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('ABOUT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: Text(appState.appVersion),
          ),
          ListTile(
            title: const Text('Check for Updates'),
            subtitle: const Text('Check GitHub for new releases'),
            leading: const Icon(Icons.system_update),
            onTap: () => _checkForUpdates(context),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Created by RAKIB',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
             CircularProgressIndicator(),
             SizedBox(width: 20),
             Text('Checking GitHub...'),
          ]
        )
      )
    );
    
    final updateInfo = await GithubUpdater.checkUpdate();
    Navigator.pop(context); // Close loading dialog
    
    if (updateInfo != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Update Available: ${updateInfo.version}'),
          content: SingleChildScrollView(
            child: Text(updateInfo.releaseNotes ?? 'No release notes.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse(updateInfo.downloadUrl), mode: LaunchMode.externalApplication);
                Navigator.pop(ctx);
              },
              child: const Text('Download APK'),
            )
          ],
        )
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version!')),
      );
    }
  }
}
