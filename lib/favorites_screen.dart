import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'database_helper.dart';
import 'media_item.dart';
import 'audio_player_service.dart';
import 'music_player_screen.dart';
import 'mini_player.dart';

class FavoritesScreen extends StatefulWidget {
  final List<MediaItem> allSongs;
  final AudioPlayerService audioPlayer;

  const FavoritesScreen({
    Key? key,
    required this.allSongs,
    required this.audioPlayer,
  }) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<MediaItem> favoriteSongs = [];
  final TextEditingController searchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    widget.audioPlayer.addListener(_updatePlayerState);
    searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    widget.audioPlayer.removeListener(_updatePlayerState);
    searchController.dispose();
    super.dispose();
  }

  void _updatePlayerState() {
    if (mounted) _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favoritePaths = await _dbHelper.getAllFavorites();
      developer.log('Loaded ${favoritePaths.length} favorite paths from DB');

      if (mounted) {
        setState(() {
          favoriteSongs = widget.allSongs.where((song) {
            if (song.id.isEmpty) return false;
            return favoritePaths.any((favPath) =>
                _dbHelper.isPathMatch(favPath, song.id));
          }).toList();
          developer.log('Found ${favoriteSongs.length} matching songs');
        });
      }
    } catch (e) {
      developer.log('Error loading favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading favorites: ${e.toString()}')),
        );
      }
    }
  }

  void _filterSongs() {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      _loadFavorites();
      return;
    }

    if (mounted) {
      setState(() {
        favoriteSongs = favoriteSongs.where((song) =>
        song.title.toLowerCase().contains(query) ||
            (song.artist?.toLowerCase().contains(query) ?? false))
            .toList();
      });
    }
  }

  Future<void> _toggleFavorite(MediaItem song) async {
    try {
      final isFav = await _dbHelper.isFavorite(song.id);
      developer.log('Toggling favorite for: ${song.id}');

      if (isFav) {
        await _dbHelper.deleteFavorite(song.id);
      } else {
        await _dbHelper.insertFavorite(song.id);
      }

      await _loadFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFav ? 'Removed from favorites' : 'Added to favorites'),
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

  Future<void> _playSong(int index) async {
    try {
      await widget.audioPlayer.setPlaylist(favoriteSongs, index);
      await widget.audioPlayer.play();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MusicPlayerScreen(
            playlist: favoriteSongs,
            initialIndex: index,
            audioPlayer: widget.audioPlayer,
            onFavoriteToggle: _toggleFavorite,
          ),
        ),
      );

      await _loadFavorites();
    } catch (e) {
      developer.log('Error playing song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing song: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: const Text('Favorites'),
                  floating: true,
                  pinned: true,
                  backgroundColor: Colors.black,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search favorites...',
                          filled: true,
                          fillColor: Colors.grey[850],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (favoriteSongs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_border, size: 60),
                          const SizedBox(height: 16),
                          const Text('No favorites yet'),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final song = favoriteSongs[index];
                        final color = song.extras['color'] as Color? ?? Colors.grey;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          color: Colors.grey[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.music_note, color: Colors.white),
                            ),
                            title: Text(
                              song.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              song.artist ?? 'Unknown Artist',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red),
                              onPressed: () => _toggleFavorite(song),
                            ),
                            onTap: () => _playSong(index),
                          ),
                        );
                      },
                      childCount: favoriteSongs.length,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.audioPlayer.currentSong != null)
            MiniPlayer(
              audioPlayer: widget.audioPlayer,
              onTap: () {
                if (widget.audioPlayer.currentSong != null) {
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
              },
            ),
        ],
      ),
    );
  }
}