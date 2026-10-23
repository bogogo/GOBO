import 'package:flutter/material.dart';

import 'light_control.dart';
import 'light_store.dart';
import 'wled.dart';

/// A named set of lights that are switched, dimmed and colored together.
class LightGroup implements LightControl {
  LightGroup({required this.id, required this.name, required this.hosts, required this.store});

  final String id;
  @override
  String name;
  List<String> hosts;
  final LightStore store;

  List<WledLight> get members => [for (final h in hosts) if (store.lights[h] != null) store.lights[h]!];
  List<WledLight> get _online => members.where((l) => l.online).toList();
  WledLight? get _lead {
    final lit = _online.where((l) => l.on);
    return lit.isNotEmpty ? lit.first : (_online.isNotEmpty ? _online.first : null);
  }

  @override
  bool get online => _online.isNotEmpty;
  @override
  bool get on => _online.any((l) => l.on);
  @override
  int get brightness {
    final lit = _online.where((l) => l.on).toList();
    if (lit.isEmpty) return _lead?.brightness ?? 128;
    return lit.map((l) => l.brightness).reduce((a, b) => a + b) ~/ lit.length;
  }

  @override
  Color get color => _lead?.color ?? Colors.white;
  @override
  int get white => _lead?.white ?? 0;
  @override
  bool get rgbw => _online.any((l) => l.rgbw);
  @override
  int get effect => _lead?.effect ?? 0;
  @override
  List<String> get effects => _lead?.effects ?? const [];

  /// Scenes saved under the same name on every light in the group.
  List<String> get _sharedPresetNames {
    final lights = _online;
    if (lights.isEmpty) return const [];
    return lights.first.presets.values
        .where((n) => lights.every((l) => l.presets.containsValue(n)))
        .toList();
  }

  @override
  Map<int, String> get presets => _sharedPresetNames.asMap();

  @override
  void setOn(bool v) => _each((l) => l.setOn(v));
  @override
  void setBrightness(int v) => _each((l) => l.setBrightness(v));
  @override
  void setColor(Color c, {int? w}) => _each((l) => l.setColor(c, w: w));
  @override
  void setEffect(int fx) => _each((l) => l.setEffect(fx));
  @override
  void applyPreset(int id) {
    final name = _sharedPresetNames[id];
    _each((l) => l.applyPreset(l.presets.entries.firstWhere((e) => e.value == name).key));
  }

  void _each(void Function(WledLight) f) {
    for (final l in _online) {
      f(l);
    }
  }

  @override
  void addListener(VoidCallback listener) => store.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => store.removeListener(listener);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hosts': hosts};
}
