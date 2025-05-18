import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  Future<void> setPlaylist(List<String> paths, {int initialIndex = 0}) async {
    await _player.setAudioSource(
      ConcatenatingAudioSource(
        children: paths.map((path) => AudioSource.uri(Uri.file(path))).toList(),
      ),
      initialIndex: initialIndex,
    );
  }

  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> skipToPrevious() async {
    final position = await _player.position;
    if (position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  Future<void> skipToIndex(int index) async {
    await _player.seek(Duration.zero, index: index);
  }

  void dispose() {
    _player.dispose();
  }
}