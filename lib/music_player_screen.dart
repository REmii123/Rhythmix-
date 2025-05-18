import 'dart:async';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_player_service.dart';
import 'media_item.dart';
import 'dart:developer' as developer;

class MusicPlayerScreen extends StatefulWidget {
  final List<MediaItem> playlist;
  final int initialIndex;
  final AudioPlayerService audioPlayer;
  final Function(MediaItem)? onFavoriteToggle;

  const MusicPlayerScreen({
    Key? key,
    required this.playlist,
    required this.initialIndex,
    required this.audioPlayer,
    this.onFavoriteToggle,
  }) : super(key: key);

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  late int currentIndex;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isFavorite = false;
  late StreamSubscription _positionSub;
  late StreamSubscription _durationSub;
  late StreamSubscription _stateSub;
  late StreamSubscription _indexSub;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _loadFavoriteStatus();
    _initPlayerListeners();
  }

  void _initPlayerListeners() {
    _positionSub = widget.audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => position = pos);
    });

    _durationSub = widget.audioPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => duration = dur ?? Duration.zero);
    });

    _stateSub = widget.audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => isPlaying = state.playing);
    });

    _indexSub = widget.audioPlayer.currentIndexStream.listen((index) {
      if (index != null && mounted) {
        setState(() {
          currentIndex = index;
          _loadFavoriteStatus();
        });
      }
    });
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final song = widget.playlist[currentIndex];
      final favorite = await _dbHelper.isFavorite(song.id);
      developer.log('Favorite status for ${song.id}: $favorite');
      if (mounted) {
        setState(() {
          isFavorite = favorite;
        });
      }
    } catch (e) {
      developer.log('Error loading favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final song = widget.playlist[currentIndex];
      developer.log('Toggling favorite for: ${song.id}');
      final wasFavorite = isFavorite;

      if (wasFavorite) {
        await _dbHelper.deleteFavorite(song.id);
      } else {
        await _dbHelper.insertFavorite(song.id);
      }

      if (mounted) {
        setState(() {
          isFavorite = !wasFavorite;
        });
      }

      widget.onFavoriteToggle?.call(song);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!wasFavorite
              ? 'Added to favorites'
              : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      developer.log('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update favorites'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _playPause() {
    if (isPlaying) {
      widget.audioPlayer.pause();
    } else {
      widget.audioPlayer.play();
    }
  }

  void _next() async {
    await widget.audioPlayer.skipToNext();
  }

  void _previous() async {
    await widget.audioPlayer.skipToPrevious();
  }

  @override
  void dispose() {
    _positionSub.cancel();
    _durationSub.cancel();
    _stateSub.cancel();
    _indexSub.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.playlist[currentIndex];
    final color = song.extras['color'] as Color;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                key: ValueKey<bool>(isFavorite),
                color: isFavorite ? Colors.red : Colors.white,
                size: 28,
              ),
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(Icons.music_note, size: 120, color: color.withOpacity(0.8)),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist ?? "Unknown Artist",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Slider(
              value: position.inSeconds.toDouble(),
              min: 0,
              max: duration.inSeconds.toDouble().clamp(1, double.infinity),
              onChanged: (value) {
                widget.audioPlayer.seek(Duration(seconds: value.toInt()));
              },
              activeColor: color,
              inactiveColor: Colors.white24,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white70)),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
                  onPressed: _previous,
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _playPause,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
                  onPressed: _next,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}