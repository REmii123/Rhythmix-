import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'media_item.dart';

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<MediaItem>? _currentPlaylist;
  int? _currentIndex;
  final BehaviorSubject<int> _currentIndexController = BehaviorSubject<int>();
  bool _isDisposed = false;

  AudioPlayer get player => _player;

  Future<void> initialize() async {
    _isDisposed = false;
    await _player.setLoopMode(LoopMode.off);
  }

  Stream<int> get currentIndexStream => _currentIndexController.stream;
  MediaItem? get currentSong => (_currentIndex != null &&
      _currentPlaylist != null &&
      _currentIndex! < _currentPlaylist!.length)
      ? _currentPlaylist![_currentIndex!]
      : null;

  List<MediaItem>? get currentPlaylist => _currentPlaylist;
  int? get currentIndex => _currentIndex;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> setPlaylist(List<MediaItem> playlist, int initialIndex) async {
    if (_isDisposed) return;

    try {
      await _player.stop();
      _currentPlaylist = playlist;
      _currentIndex = initialIndex;

      await _player.setAudioSource(
        ConcatenatingAudioSource(
          children: playlist
              .where((item) => item.id.isNotEmpty)
              .map((item) => AudioSource.uri(Uri.parse(item.id)))
              .toList(),
        ),
        initialIndex: initialIndex,
      );

      _currentIndexController.add(initialIndex);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting playlist: $e');
      rethrow;
    }
  }

  Future<void> play() async {
    if (_isDisposed || _currentPlaylist == null) return;
    await _player.play();
    notifyListeners();
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    await _player.pause();
    notifyListeners();
  }

  Future<void> skipToNext() async {
    if (_isDisposed || _currentPlaylist == null || _currentIndex == null) return;
    final nextIndex = (_currentIndex! + 1) % _currentPlaylist!.length;
    await _player.seek(Duration.zero, index: nextIndex);
    _currentIndex = nextIndex;
    _currentIndexController.add(nextIndex);
    notifyListeners();
  }

  Future<void> skipToPrevious() async {
    if (_isDisposed || _currentPlaylist == null || _currentIndex == null) return;
    final prevIndex = (_currentIndex! - 1) % _currentPlaylist!.length;
    await _player.seek(Duration.zero, index: prevIndex);
    _currentIndex = prevIndex;
    _currentIndexController.add(prevIndex);
    notifyListeners();
  }

  Future<void> seek(Duration position, {int? index}) async {
    if (_isDisposed) return;
    await _player.seek(position, index: index);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _currentIndexController.close();
    _player.dispose();
    super.dispose();
  }
}