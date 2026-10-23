import 'package:flutter/material.dart';

import 'wled.dart';

const _swatches = <Color>[
  Color(0xFFFFB46B), // warm white
  Color(0xFFFFF1E0), // daylight
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFD60A),
  Color(0xFF34C759),
  Color(0xFF00C7BE),
  Color(0xFF0A84FF),
  Color(0xFF5E5CE6),
  Color(0xFFBF5AF2),
  Color(0xFFFF2D92),
];

class LightPage extends StatelessWidget {
  const LightPage({super.key, required this.light});
  final WledLight light;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: light,
      builder: (context, _) {
        final hsv = HSVColor.fromColor(light.color);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(light.name),
            actions: [Switch(value: light.on, onChanged: light.setOn), const SizedBox(width: 12)],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _Label('Brightness'),
              _GradientSlider(
                colors: [Colors.black, light.color],
                value: light.brightness / 255,
                onChanged: (v) => light.setBrightness((v * 254 + 1).round()),
              ),
              const _Label('Color'),
              _GradientSlider(
                colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()],
                value: hsv.hue / 360,
                onChanged: (v) => light.setColor(hsv.withHue(v * 360).withSaturation(hsv.saturation == 0 ? 1 : hsv.saturation).withValue(1).toColor()),
              ),
              const _Label('Saturation'),
              _GradientSlider(
                colors: [Colors.white, hsv.withSaturation(1).withValue(1).toColor()],
                value: hsv.saturation,
                onChanged: (v) => light.setColor(hsv.withSaturation(v).withValue(1).toColor()),
              ),
              if (light.rgbw) ...[
                const _Label('White'),
                _GradientSlider(
                  colors: const [Colors.black, Color(0xFFFFE8C8)],
                  value: light.white / 255,
                  onChanged: (v) => light.setColor(light.color, w: (v * 255).round()),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in _swatches)
                    GestureDetector(
                      onTap: () => light.setColor(c, w: c == _swatches[0] ? 200 : 0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              if (light.presets.isNotEmpty) ...[
                const _Label('Scenes'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in light.presets.entries)
                    ActionChip(label: Text(p.value), onPressed: () => light.applyPreset(p.key)),
                ]),
              ],
              if (light.effects.isNotEmpty) ...[
                const _Label('Effects'),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: light.effects.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ChoiceChip(
                      label: Text(light.effects[i]),
                      selected: light.effect == i,
                      onSelected: (_) => light.setEffect(i),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(text, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w500)),
      );
}

/// A thick pill slider drawn over a color gradient.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({required this.colors, required this.value, required this.onChanged});
  final List<Color> colors;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      void update(Offset p) => onChanged((p.dx / box.maxWidth).clamp(0.0, 1.0));
      return GestureDetector(
        onTapDown: (d) => update(d.localPosition),
        onHorizontalDragUpdate: (d) => update(d.localPosition),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(colors: colors),
          ),
          child: Align(
            alignment: Alignment(value.clamp(0.0, 1.0) * 2 - 1, 0),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black45)],
              ),
            ),
          ),
        ),
      );
    });
  }
}
