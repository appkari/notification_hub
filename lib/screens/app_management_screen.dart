import 'package:flutter/material.dart'
    show
        AppBar,
        BorderRadius,
        BuildContext,
        Center,
        CircularProgressIndicator,
        Column,
        EdgeInsets,
        Expanded,
        Icon,
        Icons,
        Image,
        InputDecoration,
        ListTile,
        ListView,
        OutlineInputBorder,
        Padding,
        Scaffold,
        State,
        StatefulWidget,
        Text,
        TextField,
        Widget,
        FutureBuilder,
        ConnectionState,
        Switch,
        Row,
        SizedBox,
        TextStyle,
        Checkbox;
import 'package:provider/provider.dart' show Provider;
import '../providers/notification_provider.dart' show NotificationProvider;
import 'package:installed_apps/installed_apps.dart'
    show InstalledApps; // Changed import
import 'package:installed_apps/app_info.dart' show AppInfo;
import 'dart:async' show Timer;
import 'dart:typed_data' show Uint8List;
import '../services/icon_cache_service.dart' show IconCacheService;
import 'dart:convert' show base64Encode;

class AppManagementScreen extends StatefulWidget {
  const AppManagementScreen({super.key});

  @override
  State<AppManagementScreen> createState() => _AppManagementScreenState();
}

class _AppManagementScreenState extends State<AppManagementScreen> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _debounce;
  final IconCacheService _iconCacheService = IconCacheService();
  bool _showSystemApps = false;
  Set<String> _excludedApps = {};

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load all installed apps (without icons for speed)
      final apps = await InstalledApps.getInstalledApps(
        false, // shouldReturnIcons (faster)
        _showSystemApps, // shouldReturnSystemApps (controlled by switch)
        '',
      );
      if (!mounted) return;

      final provider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      final excludedApps = await provider.getExcludedApps();
      _excludedApps = excludedApps;
      setState(() {
        _apps = apps;
        _apps.sort((a, b) {
          final isAExcluded = excludedApps.contains(a.packageName);
          final isBExcluded = excludedApps.contains(b.packageName);
          if (isAExcluded != isBExcluded) {
            return isAExcluded ? -1 : 1;
          }
          return a.name.compareTo(b.name);
        });
        _filterApps();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterApps() {
    _filteredApps =
        _apps.where((app) {
          return app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              app.packageName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
        }).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<Uint8List?> _getAppIcon(String packageName) async {
    // Try cache first
    final cached = await _iconCacheService.getIcon(packageName);
    if (cached != null) return cached;
    try {
      final appInfo = await InstalledApps.getAppInfo(packageName, null);
      final icon = appInfo?.icon;
      if (icon != null) {
        await _iconCacheService.cacheIcon(packageName, base64Encode(icon));
      }
      return icon;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Apps')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (query) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 250), () {
                        setState(() {
                          _searchQuery = query;
                          _filterApps();
                        });
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search apps...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Switch(
                      value: _showSystemApps,
                      onChanged: (value) async {
                        setState(() {
                          _showSystemApps = value;
                        });
                        await _loadApps();
                      },
                    ),
                    Text('Show system apps', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredApps.isEmpty
                    ? const Center(child: Text('No apps found.'))
                    : ListView.builder(
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        final isSelected =
                            !_excludedApps.contains(app.packageName);
                        return ListTile(
                          leading: FutureBuilder<Uint8List?>(
                            future: _getAppIcon(app.packageName),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  width: 40,
                                  height: 40,
                                );
                              } else {
                                return const Icon(Icons.apps);
                              }
                            },
                          ),
                          title: Text(app.name),
                          subtitle: Text(app.packageName),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (checked) async {
                              final provider =
                                  Provider.of<NotificationProvider>(
                                    context,
                                    listen: false,
                                  );
                              setState(() {
                                if (checked == true) {
                                  _excludedApps.remove(app.packageName);
                                } else {
                                  _excludedApps.add(app.packageName);
                                }
                              });
                              if (checked == true) {
                                await provider.includeApp(app.packageName);
                              } else {
                                await provider.excludeApp(app.packageName);
                              }
                              // Refresh the list to reflect changes
                              await _loadApps();
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
