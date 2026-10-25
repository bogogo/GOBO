import 'package:flutter/material.dart';

import 'light_control.dart';
import 'light_group.dart';
import 'light_page.dart';
import 'light_store.dart';
import 'logo_background.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final LightStore store;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: LogoBackground()),
      ListenableBuilder(
        listenable: store,
        builder: (context, _) {
        final lights = store.lights.values.toList();
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Image.asset('assets/brand/gobo_wordmark.png', height: 22, semanticLabel: 'GOBO'),
            actions: [
              IconButton(tooltip: 'All off', icon: const Icon(Icons.power_settings_new), onPressed: store.allOff),
              PopupMenuButton<String>(
                tooltip: 'Add',
                icon: const Icon(Icons.add),
                onSelected: (v) => v == 'group' ? editGroup(context, store) : _addDialog(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'group', child: Text('New group')),
                  PopupMenuItem(value: 'light', child: Text('Add light by IP')),
                ],
              ),
            ],
          ),
          body: lights.isEmpty
              ? const _Empty()
              : CustomScrollView(slivers: [
                  if (store.groups.isNotEmpty) ...[
                    const _Section('Groups'),
                    _grid([
                      for (final g in store.groups)
                        _LightTile(
                          light: g,
                          icon: Icons.layers,
                          detail: '${g.members.length} ${g.members.length == 1 ? 'light' : 'lights'}',
                          onTap: () => _openGroup(context, g),
                          onLongPress: () => editGroup(context, store, group: g),
                        ),
                    ]),
                  ],
                  if (store.groups.isNotEmpty) const _Section('All lights'),
                  _grid([
                    for (final l in lights)
                      _LightTile(
                        light: l,
                        icon: Icons.lightbulb,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LightPage(light: l))),
                        onLongPress: () => store.remove(l.host),
                      ),
                  ]),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ]),
        );
        },
      ),
    ]);
  }

  Widget _grid(List<Widget> tiles) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          delegate: SliverChildListDelegate(tiles),
        ),
      );

  void _openGroup(BuildContext context, LightGroup g) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ListenableBuilder(
          listenable: store,
          builder: (ctx, _) => LightPage(
            light: g,
            subtitle: g.members.map((l) => l.name).join(', '),
            onEdit: () => editGroup(ctx, store, group: g),
          ),
        ),
      ),
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

/// Bottom sheet to create a group, or rename, change or delete an existing one.
Future<void> editGroup(BuildContext context, LightStore store, {LightGroup? group}) {
  final name = TextEditingController(text: group?.name ?? '');
  final picked = <String>{...?group?.hosts};
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(group == null ? 'New group' : 'Edit group',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              autofocus: group == null,
              decoration: const InputDecoration(hintText: 'Name, e.g. Downstairs'),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final l in store.lights.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.name),
                    value: picked.contains(l.host),
                    onChanged: (v) => setState(() => v! ? picked.add(l.host) : picked.remove(l.host)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (group != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () {
                    store.deleteGroup(group);
                    Navigator.of(ctx)
                      ..pop()
                      ..popUntil((r) => r.isFirst);
                  },
                  child: const Text('Delete group'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: name.text.trim().isEmpty || picked.isEmpty
                    ? null
                    : () {
                        final hosts = [for (final h in store.lights.keys) if (picked.contains(h)) h];
                        group == null
                            ? store.createGroup(name.text.trim(), hosts)
                            : store.updateGroup(group, name.text.trim(), hosts);
                        Navigator.pop(ctx);
                      },
                child: const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    ),
  ).whenComplete(name.dispose);
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        sliver: SliverToBoxAdapter(
          child: Text(text, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w500)),
        ),
      );
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
  const _LightTile({required this.light, required this.icon, required this.onTap, required this.onLongPress, this.detail});
  final LightControl light;
  final IconData icon;
  final String? detail;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final glow = light.on && light.online ? light.color : Colors.white10;
    final status = !light.online ? 'Offline' : light.on ? '${(light.brightness / 2.55).round()}%' : 'Off';
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
              Icon(icon, color: light.on ? glow : Colors.white24),
              const Spacer(),
              Switch(value: light.on, onChanged: light.online ? light.setOn : null),
            ]),
            const Spacer(),
            Text(light.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            Text(detail == null ? status : '$detail · $status', style: const TextStyle(color: Colors.white54)),
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
