import 'package:flutter/material.dart';

import 'color_controls.dart';
import 'light_control.dart';

class LightPage extends StatelessWidget {
  const LightPage({super.key, required this.light, this.subtitle, this.onEdit, this.editTooltip = 'Edit group'});
  final LightControl light;

  /// Shown under the title, e.g. the lights in a group.
  final String? subtitle;
  final VoidCallback? onEdit;
  final String editTooltip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: light,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(light.name),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 13, color: Colors.white54)),
            ]),
            actions: [
              if (onEdit != null) IconButton(tooltip: editTooltip, icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
              Switch(value: light.on, onChanged: light.setOn),
              const SizedBox(width: 12),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              ColorBeacon(color: light.color, on: light.on, brightness: light.brightness / 255),
              const _Label('Brightness'),
              LightBars(
                value: light.brightness / 255,
                color: light.color,
                onChanged: (v) => light.setBrightness((v * 254 + 1).round()),
              ),
              const _Label('Color'),
              ColorPad(
                color: light.color,
                onChanged: (c) => light.setColor(c),
              ),
              if (light.rgbw) ...[
                const _Label('White'),
                LightBars(
                  value: light.white / 255,
                  color: const Color(0xFFFFE8C8),
                  onChanged: (v) => light.setColor(light.color, w: (v * 255).round()),
                ),
              ],
              const _Label('Gems'),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    for (final (name, c, w) in gemSwatches)
                      GemSwatch(
                        label: name,
                        color: c,
                        selected: light.color.toARGB32() == c.toARGB32(),
                        onTap: () => light.setColor(c, w: w),
                      ),
                  ],
                ),
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
