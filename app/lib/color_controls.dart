import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Named presets shown as gems under the color pad.
const gemSwatches = <(String, Color, int)>[
  ('Candle', Color(0xFFFFB46B), 200),
  ('Daylight', Color(0xFFFFF1E0), 0),
  ('Ember', Color(0xFFFF3B30), 0),
  ('Sunset', Color(0xFFFF9500), 0),
  ('Lemon', Color(0xFFFFD60A), 0),
  ('Lime', Color(0xFF34C759), 0),
  ('Lagoon', Color(0xFF00C7BE), 0),
  ('Ocean', Color(0xFF0A84FF), 0),
  ('Indigo', Color(0xFF5E5CE6), 0),
  ('Orchid', Color(0xFFBF5AF2), 0),
  ('Neon', Color(0xFFFF2D92), 0),
];

/// Big glowing diamond showing the live color, ringed by a slowly turning
/// spectrum halo.
class ColorBeacon extends StatefulWidget {
  const ColorBeacon({super.key, required this.color, required this.on, required this.brightness});
  final Color color;
  final bool on;
  final double brightness; // 0..1

  @override
  State<ColorBeacon> createState() => _ColorBeaconState();
}

class _ColorBeaconState extends State<ColorBeacon> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.on ? widget.color : Colors.white12;
    final level = widget.on ? 0.35 + widget.brightness * 0.65 : 0.0;
    return SizedBox(
      height: 190,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          final t = _spin.value * 2 * math.pi;
          final pulse = 1 + 0.04 * math.sin(t * 2);
          return Stack(alignment: Alignment.center, children: [
            Transform.rotate(
              angle: t,
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  gradient: SweepGradient(colors: [
                    for (var h = 0; h <= 360; h += 45)
                      HSVColor.fromAHSV(widget.on ? 0.55 : 0.12, h.toDouble(), 0.9, 1).toColor(),
                  ]),
                ),
              ),
            ),
            Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E10),
                borderRadius: BorderRadius.circular(44),
              ),
            ),
            Transform.scale(
              scale: pulse,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(glow, Colors.white, 0.55)!, glow, Color.lerp(glow, Colors.black, 0.35)!],
                    ),
                    boxShadow: [
                      BoxShadow(color: glow.withValues(alpha: 0.75 * level), blurRadius: 40 * level + 4, spreadRadius: 6 * level),
                    ],
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// 2D color field: hue left to right, saturation fading to white at the bottom.
/// The puck is a glowing diamond.
class ColorPad extends StatelessWidget {
  const ColorPad({super.key, required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    return LayoutBuilder(builder: (context, box) {
      const h = 220.0;
      final w = box.maxWidth;
      void update(Offset p) {
        final hue = (p.dx / w).clamp(0.0, 1.0) * 360;
        final sat = 1 - (p.dy / h).clamp(0.0, 1.0);
        onChanged(HSVColor.fromAHSV(1, hue == 360 ? 0 : hue, sat, 1).toColor());
      }

      final x = hsv.hue / 360 * w;
      final y = (1 - hsv.saturation) * h;
      return GestureDetector(
        // separate axis recognizers so a vertical drag here beats the page scroll
        onVerticalDragStart: (d) => update(d.localPosition),
        onVerticalDragUpdate: (d) => update(d.localPosition),
        onHorizontalDragStart: (d) => update(d.localPosition),
        onHorizontalDragUpdate: (d) => update(d.localPosition),
        onTapDown: (d) {
          HapticFeedback.selectionClick();
          update(d.localPosition);
        },
        child: SizedBox(
          height: h,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CustomPaint(painter: _PadPainter()),
              ),
            ),
            Positioned(
              left: x - 18,
              top: y - 18,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.9), blurRadius: 22, spreadRadius: 2),
                      const BoxShadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _PadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(colors: [
          for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h % 360.0, 1, 1).toColor(),
        ]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        ).createShader(rect),
    );
    // faint scanlines for a bit of texture
    final line = Paint()..color = const Color(0x14000000);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
  }

  @override
  bool shouldRepaint(_PadPainter old) => false;
}

/// Level meter made of rising bars, lit up to the current value with a glow.
class LightBars extends StatelessWidget {
  const LightBars({super.key, required this.value, required this.color, required this.onChanged, this.bars = 26});
  final double value; // 0..1
  final Color color;
  final ValueChanged<double> onChanged;
  final int bars;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      void update(Offset p) => onChanged((p.dx / box.maxWidth).clamp(0.0, 1.0));
      final lit = (value * bars).ceil();
      return GestureDetector(
        onTapDown: (d) => update(d.localPosition),
        onHorizontalDragUpdate: (d) => update(d.localPosition),
        child: SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 120 + i * 6),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 18 + 54 * (i + 1) / bars,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i < lit
                          ? LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color.lerp(color, Colors.black, 0.4)!, color, Color.lerp(color, Colors.white, 0.5)!],
                            )
                          : null,
                      color: i < lit ? null : Colors.white10,
                      boxShadow: i < lit ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10)] : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// A faceted gem swatch; the selected one lifts and glows.
class GemSwatch extends StatelessWidget {
  const GemSwatch({super.key, required this.label, required this.color, required this.selected, required this.onTap});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: SizedBox(
        width: 64,
        child: Column(children: [
          AnimatedScale(
            scale: selected ? 1.18 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0, 0.45, 0.55, 1],
                    colors: [
                      Color.lerp(color, Colors.white, 0.6)!,
                      color,
                      Color.lerp(color, Colors.black, 0.15)!,
                      Color.lerp(color, Colors.black, 0.45)!,
                    ],
                  ),
                  border: selected ? Border.all(color: Colors.white, width: 2) : null,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: selected ? 0.9 : 0.35), blurRadius: selected ? 22 : 8),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white54,
                letterSpacing: 0.4,
              )),
        ]),
      ),
    );
  }
}
