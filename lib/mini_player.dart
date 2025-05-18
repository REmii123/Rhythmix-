import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_player_service.dart';
import 'music_player_screen.dart';
import 'media_item.dart';

class MiniPlayer extends StatelessWidget {
  final AudioPlayerService audioPlayer;
  final VoidCallback? onTap;

  const MiniPlayer({
    Key? key,
    required this.audioPlayer,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final currentSong = audioPlayer.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final color = currentSong.extras['color'] as Color;

        return GestureDetector(
          onTap: onTap ?? () {
            if (audioPlayer.currentSong != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MusicPlayerScreen(
                    playlist: audioPlayer.currentPlaylist ?? [],
                    initialIndex: audioPlayer.currentIndex ?? 0,
                    audioPlayer: audioPlayer,
                  ),
                ),
              );
            }
          },
          child: Container(
            color: Colors.grey[900],
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        currentSong.artist ?? 'Unknown Artist',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (isPlaying) {
                      audioPlayer.pause();
                    } else {
                      audioPlayer.play();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: audioPlayer.skipToNext,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}