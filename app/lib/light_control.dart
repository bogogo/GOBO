import 'package:flutter/material.dart';

/// Anything the controls page can drive: a single light or a group of lights.
abstract interface class LightControl implements Listenable {
  String get name;
  bool get online;
  bool get on;
  int get brightness;
  Color get color;
  int get white;
  bool get rgbw;
  int get effect;
  List<String> get effects;
  Map<int, String> get presets;

  void setOn(bool v);
  void setBrightness(int v);
  void setColor(Color c, {int? w});
  void setEffect(int fx);
  void applyPreset(int id);
}
