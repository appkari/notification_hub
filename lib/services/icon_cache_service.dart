import 'dart:convert' show base64Decode;
import 'package:flutter/foundation.dart' show Uint8List, debugPrint;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

class IconCacheService {
  static final IconCacheService _instance = IconCacheService._internal();
  factory IconCacheService() => _instance;
  IconCacheService._internal();

  static const int _maxCacheSize = 100;
  final Map<String, Uint8List> _memoryCache = {};
  final List<String> _accessOrder = [];
  static const String _iconCacheKey = 'app_icons_cache';
  static const String _iconCacheOrderKey = 'app_icons_cache_order';

  void _touchKey(String packageName) {
    _accessOrder.remove(packageName);
    _accessOrder.add(packageName);
  }

  void _evictIfNeeded() {
    while (_memoryCache.length > _maxCacheSize && _accessOrder.isNotEmpty) {
      final evicted = _accessOrder.removeAt(0);
      _memoryCache.remove(evicted);
    }
  }

  Future<void> cacheIcon(String packageName, String base64Icon) async {
    try {
      final iconBytes = base64Decode(base64Icon);
      _memoryCache[packageName] = iconBytes;
      _touchKey(packageName);
      _evictIfNeeded();

      final prefs = await SharedPreferences.getInstance();
      final iconCache = prefs.getStringList(_iconCacheKey) ?? [];
      final existingIndex = iconCache.indexWhere(
        (item) => item.startsWith('$packageName:'),
      );

      if (existingIndex >= 0) {
        iconCache[existingIndex] = '$packageName:$base64Icon';
      } else {
        iconCache.add('$packageName:$base64Icon');
      }

      // Evict oldest entries from persistent cache
      final order = prefs.getStringList(_iconCacheOrderKey) ?? [];
      order.remove(packageName);
      order.add(packageName);
      while (iconCache.length > _maxCacheSize && order.isNotEmpty) {
        final evicted = order.removeAt(0);
        iconCache.removeWhere((item) => item.startsWith('$evicted:'));
      }

      await prefs.setStringList(_iconCacheKey, iconCache);
      await prefs.setStringList(_iconCacheOrderKey, order);
    } catch (e) {
      debugPrint('Failed to cache icon for $packageName: $e');
    }
  }

  Future<Uint8List?> getIcon(String packageName) async {
    if (_memoryCache.containsKey(packageName)) {
      _touchKey(packageName);
      return _memoryCache[packageName];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final iconCache = prefs.getStringList(_iconCacheKey) ?? [];
      final iconEntry = iconCache.firstWhere(
        (item) => item.startsWith('$packageName:'),
        orElse: () => '',
      );

      if (iconEntry.isNotEmpty) {
        final base64Icon = iconEntry.split(':')[1];
        final iconBytes = base64Decode(base64Icon);
        _memoryCache[packageName] = iconBytes;
        _touchKey(packageName);
        _evictIfNeeded();
        return iconBytes;
      }
    } catch (e) {
      debugPrint('Failed to load icon for $packageName: $e');
    }

    return null;
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    _accessOrder.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_iconCacheKey);
    await prefs.remove(_iconCacheOrderKey);
  }
}
