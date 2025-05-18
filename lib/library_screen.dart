import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:developer' as developer;
import 'database_helper.dart';
import 'media_item.dart';
import 'audio_player_service.dart';
import 'music_player_screen.dart';
import 'mini_player.dart';

class LibraryScreen extends StatefulWidget {
  final AudioPlayerService audioPlayer;
  final List<MediaItem>? mediaItems;
  final Function(List<MediaItem>)? onSongsLoaded;

  const LibraryScreen({
    Key? key,
    required this.audioPlayer,
    this.mediaItems,
    this.onSongsLoaded,
  }) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _sortBy = 'title';
  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    if (widget.mediaItems != null) {
      _mediaItems = widget.mediaItems!;
      _isLoading = false;
    } else {
      _loadSongs();
    }
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
        return;
      }

      final status = await Permission.audio.request();
      if (!status.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          setState(() => _permissionDenied = true);
          throw Exception('Audio and storage permissions denied');
        }
      }
    } catch (e) {
      developer.log('Permission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permissions are required to access music files'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _loadSongs() async {
    try {
      setState(() {
        _isLoading = true;
        _permissionDenied = false;
      });

      await _requestPermissions();

      final List<MediaItem> foundSongs = [];
      final Set<String> seenPaths = {};
      final directories = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/sdcard/Music',
        '/sdcard/Download',
      ];

      for (final dirPath in directories) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          try {
            await for (final file in dir.list(recursive: true)) {
              if (file is File && _isAudioFile(file.path)) {
                final path = file.path;
                if (seenPaths.contains(path)) continue;

                seenPaths.add(path);
                final fileName = p.basenameWithoutExtension(file.path);

                foundSongs.add(MediaItem(
                  id: path,
                  title: fileName,
                  artist: 'Unknown Artist',
                  extras: {
                    'color': _getColor(foundSongs.length),
                    'lastModified': (await file.lastModified()).millisecondsSinceEpoch,
                  },
                ));
              }
            }
          } catch (e) {
            developer.log('Error scanning $dirPath: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _mediaItems = foundSongs;
          _isLoading = false;
        });
        widget.onSongsLoaded?.call(foundSongs);
      }
    } catch (e) {
      developer.log('Error loading songs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (!_permissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading songs: ${e.toString()}')),
          );
        }
      }
    }
  }

  bool _isAudioFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp3', '.m4a', '.aac', '.wav', '.flac'].contains(ext);
  }

  Color _getColor(int index) {
    const colors = [
      Color(0xFF6A8D92),
      Color(0xFF7D5A5A),
      Color(0xFF8F6F56),
      Color(0xFF6E7582),
      Color(0xFF7E7F9A),
      Color(0xFF9A8F7E),
    ];
    return colors[index % colors.length];
  }

  void _filterItems() {
    setState(() {});
  }

  List<MediaItem> get sortedMediaItems {
    List<MediaItem> items = List.from(_mediaItems);

    if (_searchController.text.isNotEmpty) {
      items = items.where((item) =>
      item.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          (item.artist?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false))
          .toList();
    }

    if (_sortBy == 'title') {
      items.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortBy == 'artist') {
      items.sort((a, b) => (a.artist ?? '').compareTo(b.artist ?? ''));
    }

    return items;
  }

  Future<void> _playSong(int index) async {
    try {
      final playlist = sortedMediaItems;
      if (index < 0 || index >= playlist.length) return;

      await widget.audioPlayer.setPlaylist(playlist, index);
      await widget.audioPlayer.play();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MusicPlayerScreen(
            playlist: playlist,
            initialIndex: index,
            audioPlayer: widget.audioPlayer,
            onFavoriteToggle: _toggleFavorite,
          ),
        ),
      );
    } catch (e) {
      developer.log('Error playing song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing song: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(MediaItem song) async {
    try {
      if (song.id.isEmpty) {
        throw Exception('Cannot favorite - empty song path');
      }

      final isFavorite = await _dbHelper.isFavorite(song.id);
      developer.log('Toggling favorite for: ${song.id}');

      if (isFavorite) {
        await _dbHelper.deleteFavorite(song.id);
      } else {
        await _dbHelper.insertFavorite(song.id);
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite
                ? 'Removed from favorites'
                : 'Added to favorites'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      developer.log('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildPermissionDeniedUI() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Permission Required',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please grant storage permission to access your music library',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: openAppSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUI() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading songs...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLibraryUI() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 50, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No songs found in library'
                  : 'No matching songs found',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            TextButton(
              onPressed: _loadSongs,
              child: const Text(
                'Refresh',
                style: TextStyle(color: Colors.purpleAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final song = sortedMediaItems[index];
            final color = (song.extras?['color'] as Color?) ?? Colors.grey;
            return FutureBuilder<bool>(
              future: _dbHelper.isFavorite(song.id),
              builder: (context, snapshot) {
                final isFavorite = snapshot.data ?? false;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      song.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist ?? 'Unknown Artist',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white70,
                        size: 24,
                      ),
                      onPressed: () => _toggleFavorite(song),
                    ),
                    onTap: () => _playSong(index),
                  ),
                );
              },
            );
          },
          childCount: sortedMediaItems.length,
        ),
      ),
    );
  }

  void _openCurrentPlayer() {
    if (widget.audioPlayer.currentSong != null &&
        widget.audioPlayer.currentPlaylist != null &&
        widget.audioPlayer.currentIndex != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MusicPlayerScreen(
            playlist: widget.audioPlayer.currentPlaylist!,
            initialIndex: widget.audioPlayer.currentIndex!,
            audioPlayer: widget.audioPlayer,
            onFavoriteToggle: _toggleFavorite,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                title: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search songs...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500]),
                      onPressed: () => _searchController.clear(),
                    )
                        : null,
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.black,
                elevation: 0,
                pinned: true,
                floating: false,
                expandedHeight: 0,
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    onSelected: (value) => setState(() => _sortBy = value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'title',
                        child: Text('Sort by Title'),
                      ),
                      const PopupMenuItem(
                        value: 'artist',
                        child: Text('Sort by Artist'),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadSongs,
                  ),
                ],
              ),
              if (_permissionDenied)
                _buildPermissionDeniedUI()
              else if (_isLoading)
                _buildLoadingUI()
              else if (sortedMediaItems.isEmpty)
                  _buildEmptyLibraryUI()
                else
                  _buildSongList(),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
          if (widget.audioPlayer.currentSong != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: MiniPlayer(
                audioPlayer: widget.audioPlayer,
                onTap: _openCurrentPlayer,
              ),
            ),
        ],
      ),
    );
  }
}