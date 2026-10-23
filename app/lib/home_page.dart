import 'package:flutter/material.dart';

import 'light_page.dart';
import 'light_store.dart';
import 'wled.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final LightStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final lights = store.lights.values.toList();
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Lights', style: TextStyle(fontWeight: FontWeight.w600)),
            actions: [
              IconButton(tooltip: 'All off', icon: const Icon(Icons.power_settings_new), onPressed: store.allOff),
              IconButton(tooltip: 'Add by IP', icon: const Icon(Icons.add), onPressed: () => _addDialog(context)),
            ],
          ),
          body: lights.isEmpty
              ? const _Empty()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: lights.length,
                  itemBuilder: (_, i) => _LightTile(light: lights[i], store: store),
                ),
        );
      },
    );
  }

  Future<void> _addDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add light'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '192.168.1.50 or wled-kitchen.local'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    if (host != null) store.addManual(host);
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Looking for lights on your Wi-Fi…\nMake sure your WLED controllers are powered on, or tap + to add one by IP.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ),
      );
}

class _LightTile extends StatelessWidget {
  const _LightTile({required this.light, required this.store});
  final WledLight light;
  final LightStore store;

  @override
  Widget build(BuildContext context) {
    final glow = light.on && light.online ? light.color : Colors.white10;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LightPage(light: light))),
      onLongPress: () => store.remove(light.host),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF1A1A1E),
          gradient: light.on
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [glow.withValues(alpha: 0.55), const Color(0xFF1A1A1E)],
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.lightbulb, color: light.on ? glow : Colors.white24),
              const Spacer(),
              Switch(value: light.on, onChanged: light.online ? light.setOn : null),
            ]),
            const Spacer(),
            Text(light.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            Text(
              !light.online ? 'Offline' : light.on ? '${(light.brightness / 2.55).round()}%' : 'Off',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 10, activeTrackColor: glow),
              child: Slider(
                value: light.brightness.toDouble(),
                min: 1,
                max: 255,
                onChanged: light.online ? (v) => light.setBrightness(v.round()) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
