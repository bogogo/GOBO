import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wled.dart';

/// Finds WLED controllers via mDNS (_wled._tcp) and remembers manually added ones.
class LightStore extends ChangeNotifier {
  final Map<String, WledLight> lights = {};
  BonsoirDiscovery? _discovery;

  Future<void> start() async {
    if (const bool.fromEnvironment('DEMO')) return _startDemo();
    final prefs = await SharedPreferences.getInstance();
    for (final host in prefs.getStringList('hosts') ?? const <String>[]) {
      _add(host);
    }
    _discover();
  }

  Future<void> _discover() async {
    try {
      _discovery = BonsoirDiscovery(type: '_wled._tcp');
      await _discovery!.ready;
      _discovery!.eventStream!.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          event.service!.resolve(_discovery!.serviceResolver);
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
          final s = event.service as ResolvedBonsoirService;
          final host = s.host?.replaceAll(RegExp(r'\.$'), '');
          if (host != null) _add(host, name: s.name, remember: true);
        }
      });
      await _discovery!.start();
    } catch (e) {
      debugPrint('mDNS discovery unavailable: $e');
    }
  }

  void _startDemo() {
    const demo = [
      ('Living room', true, 200, Color(0xFFFFB46B), true),
      ('Kitchen', true, 255, Color(0xFFFFF1E0), true),
      ('Bedroom', true, 70, Color(0xFFBF5AF2), false),
      ('Desk', false, 150, Color(0xFF0A84FF), false),
      ('TV backlight', true, 120, Color(0xFF00C7BE), false),
      ('Porch', false, 180, Color(0xFFFF9500), true),
    ];
    for (final (name, on, bri, color, rgbw) in demo) {
      final light = WledLight(host: name, name: name, demo: true)
        ..on = on
        ..brightness = bri
        ..color = color
        ..rgbw = rgbw
        ..white = rgbw ? 120 : 0
        ..connect();
      light.addListener(notifyListeners);
      lights[name] = light;
    }
    notifyListeners();
  }

  Future<void> addManual(String host) => _add(host.trim(), remember: true);

  Future<void> _add(String host, {String? name, bool remember = false}) async {
    if (host.isEmpty || lights.containsKey(host)) return;
    final light = WledLight(host: host, name: name)..connect();
    light.addListener(notifyListeners);
    lights[host] = light;
    notifyListeners();
    if (remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hosts', lights.keys.toList());
    }
  }

  Future<void> remove(String host) async {
    lights.remove(host)?.dispose();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hosts', lights.keys.toList());
  }

  void allOff() {
    for (final l in lights.values) {
      l.setOn(false);
    }
  }
}
