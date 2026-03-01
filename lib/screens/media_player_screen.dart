import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const MediaPlayerScreen({super.key, required this.url, required this.title});

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool _initialized = false;
  Duration _savedPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    final posMillis = prefs.getInt('playback_pos_\${widget.url}') ?? 0;
    _savedPosition = Duration(milliseconds: posMillis);

    player.stream.playing.listen((playing) {
       if (playing && !_initialized && _savedPosition.inMilliseconds > 0) {
          _initialized = true;
          player.seek(_savedPosition);
       }
    });

    await player.open(Media(widget.url));
  }

  @override
  void dispose() {
    // Save position on exit
    final int pos = player.state.position.inMilliseconds;
    if (pos > 0) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('playback_pos_\${widget.url}', pos);
      });
    }
    
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: Text(widget.title),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Video(
          controller: controller,
          controls: MaterialVideoControls,
        ),
      ),
    );
  }
}
