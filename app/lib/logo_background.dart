import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Slow looping render of the GOBO rings, dimmed so it sits behind the tiles.
class LogoBackground extends StatefulWidget {
  const LogoBackground({super.key});

  @override
  State<LogoBackground> createState() => _LogoBackgroundState();
}

class _LogoBackgroundState extends State<LogoBackground> {
  final _video = VideoPlayerController.asset('assets/brand/gobo_loop.mp4');
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _video
      ..setLooping(true)
      ..setVolume(0);
    _video.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _video.play();
    }).catchError(
        (_) {}); // no video support on this platform: plain background
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF0E0E10),
        child: AnimatedOpacity(
          opacity: _ready ? 0.45 : 0,
          duration: const Duration(milliseconds: 800),
          child: _ready
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _video.value.size.width,
                    height: _video.value.size.height,
                    child: VideoPlayer(_video),
                  ),
                )
              : const SizedBox.expand(),
        ),
      );
}
