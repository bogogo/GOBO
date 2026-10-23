import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// One WLED controller on the local network, kept in sync over its WebSocket.
class WledLight extends ChangeNotifier {
  WledLight({required this.host, String? name}) : name = name ?? host;

  final String host;
  String name;
  bool online = false;
  bool on = false;
  int brightness = 128; // 0-255
  Color color = Colors.white;
  int white = 0; // RGBW strips only
  bool rgbw = false;
  int effect = 0;
  List<String> effects = const [];
  Map<int, String> presets = const {};

  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  Timer? _retry;
  Timer? _debounce;
  Map<String, dynamic> _pending = {};

  Uri _uri(String path) => Uri.parse('http://$host$path');

  Future<void> connect() async {
    try {
      final res = await http.get(_uri('/json')).timeout(const Duration(seconds: 4));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      effects = List<String>.from(body['effects'] ?? const []);
      _applyInfo(body['info']);
      _applyState(body['state']);
      online = true;
      notifyListeners();
      _loadPresets();
      _openSocket();
    } catch (_) {
      _markOffline();
    }
  }

  void _openSocket() {
    _sub?.cancel();
    _ws = WebSocketChannel.connect(Uri.parse('ws://$host/ws'));
    _sub = _ws!.stream.listen((msg) {
      final data = jsonDecode(msg as String) as Map<String, dynamic>;
      if (data['info'] != null) _applyInfo(data['info']);
      if (data['state'] != null) _applyState(data['state']);
      online = true;
      notifyListeners();
    }, onError: (_) => _markOffline(), onDone: _markOffline);
  }

  Future<void> _loadPresets() async {
    try {
      final res = await http.get(_uri('/presets.json')).timeout(const Duration(seconds: 4));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      presets = {
        for (final e in body.entries)
          if (e.key != '0' && e.value is Map && (e.value as Map)['n'] != null)
            int.parse(e.key): (e.value as Map)['n'] as String,
      };
      notifyListeners();
    } catch (_) {}
  }

  void _markOffline() {
    online = false;
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 5), connect);
  }

  void _applyInfo(dynamic info) {
    if (info is! Map) return;
    name = (info['name'] as String?) ?? name;
    rgbw = info['leds']?['rgbw'] == true;
  }

  void _applyState(dynamic s) {
    if (s is! Map) return;
    on = s['on'] ?? on;
    brightness = s['bri'] ?? brightness;
    final segs = s['seg'];
    if (segs is List && segs.isNotEmpty) {
      final seg = segs.first as Map;
      effect = seg['fx'] ?? effect;
      final col = seg['col'];
      if (col is List && col.isNotEmpty && col.first is List) {
        final c = List<int>.from(col.first);
        if (c.length >= 3) color = Color.fromARGB(255, c[0], c[1], c[2]);
        if (c.length >= 4) white = c[3];
      }
    }
  }

  /// Sends a partial state update. Rapid slider changes are coalesced.
  void send(Map<String, dynamic> patch) {
    _pending = {..._pending, ...patch};
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), () {
      final body = jsonEncode(_pending);
      _pending = {};
      if (_ws != null && online) {
        _ws!.sink.add(body);
      } else {
        http.post(_uri('/json/state'), headers: {'Content-Type': 'application/json'}, body: body);
      }
    });
  }

  void setOn(bool v) {
    on = v;
    notifyListeners();
    send({'on': v});
  }

  void setBrightness(int v) {
    brightness = v;
    on = v > 0;
    notifyListeners();
    send({'on': on, 'bri': v});
  }

  void setColor(Color c, {int? w}) {
    color = c;
    if (w != null) white = w;
    notifyListeners();
    final rgb = [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()];
    send({
      'on': true,
      'seg': [
        {'fx': 0, 'col': [rgbw ? [...rgb, white] : rgb]}
      ]
    });
    effect = 0;
  }

  void setEffect(int fx) {
    effect = fx;
    notifyListeners();
    send({'on': true, 'seg': [{'fx': fx}]});
  }

  void applyPreset(int id) => send({'ps': id});

  @override
  void dispose() {
    _retry?.cancel();
    _debounce?.cancel();
    _sub?.cancel();
    _ws?.sink.close();
    super.dispose();
  }
}
