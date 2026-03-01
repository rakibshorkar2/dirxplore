import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';
import '../providers/proxy_provider.dart';
import '../models/proxy_model.dart';
import 'package:flutter/services.dart';

class ProxyTab extends StatelessWidget {
  const ProxyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final proxyProvider = context.watch<AppProxyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import YAML',
            onPressed: () => _importYamlProxies(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Proxy',
            onPressed: () => _showAddProxyDialog(context),
          )
        ],
      ),
      body: proxyProvider.proxies.isEmpty
          ? const Center(child: Text('No proxies added. Traffic goes DIRECT.'))
          : ListView.builder(
              itemCount: proxyProvider.proxies.length,
              itemBuilder: (context, index) {
                final proxy = proxyProvider.proxies[index];
                return ListTile(
                  leading: const Icon(Icons.security),
                  title: Text(proxy.displayUri),
                  subtitle: Text(
                    proxy.latencyMs == null
                        ? 'Not tested'
                        : (proxy.latencyMs == -1
                            ? 'Connection Failed'
                            : 'Latency: ${proxy.latencyMs}ms'),
                    style: TextStyle(
                      color: proxy.latencyMs == -1
                          ? Colors.red
                          : (proxy.latencyMs != null && proxy.latencyMs! < 500 ? Colors.green : Colors.orange),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: proxy.isActive,
                        onChanged: (val) => proxyProvider.toggleProxy(proxy.id, val),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'test',
                            child: Text('Test Ping'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'test') proxyProvider.testProxyLatency(proxy);
                          if (val == 'delete') proxyProvider.deleteProxy(proxy.id);
                        },
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAddProxyDialog(BuildContext context) {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '1080');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Manual SOCKS5'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostCtrl,
                decoration: const InputDecoration(labelText: 'Host IP/Domain', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: portCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password (Optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final host = hostCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim()) ?? 1080;
              final user = userCtrl.text.trim();
              final pass = passCtrl.text.trim();

              if (host.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host cannot be empty')));
                return;
              }

              // Reconstruct into model
              String uriStr = 'socks5://';
              if (user.isNotEmpty) {
                 uriStr += '$user:$pass@';
              }
              uriStr += '$host:$port';

              final model = ProxyModel.fromUri(uriStr);
              if (model != null) {
                 context.read<AppProxyProvider>().addProxy(model);
                 Navigator.pop(ctx);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Invalid proxy parameters!')),
                 );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _importYamlProxies(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Use FileType.any and manually check extension to avoid PlatformException on some Android versions
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!path.endsWith('.yaml') && !path.endsWith('.yml')) {
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid .yaml or .yml file')));
           }
           return;
        }
        final file = File(path);
        final yamlString = await file.readAsString();
        final Object? yamlDoc = loadYaml(yamlString);
        
        YamlList? proxyList;
        if (yamlDoc is YamlList) {
          proxyList = yamlDoc;
        } else if (yamlDoc is YamlMap) {
          final dynamic listValue = yamlDoc['proxies'];
          if (listValue is YamlList) {
            proxyList = listValue;
          }
        }

        if (proxyList != null) {
          int count = 0;
          for (var item in proxyList) {
             if (item is YamlMap) {
                // Determine format
                String type = item['type']?.toString() ?? 'socks5';
                String ip = item['ip']?.toString() ?? item['server']?.toString() ?? '';
                String port = item['port']?.toString() ?? '1080';
                String user = item['username']?.toString() ?? '';
                String pass = item['password']?.toString() ?? '';
                
                if (ip.isEmpty) continue;

                String uriStr = '$type://';
                if (user.isNotEmpty) uriStr += '$user:$pass@';
                uriStr += '$ip:$port';
                
                final model = ProxyModel.fromUri(uriStr);
                if (model != null) {
                   context.read<AppProxyProvider>().addProxy(model);
                   count++;
                }
             }
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count proxies from YAML')));
          }
        } else {
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid YAML structure. Expected a list.')));
           }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error parsing YAML: $e')));
      }
    }
  }
}
