import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'database_helper.dart';
import 'media_item.dart';
import 'audio_player_service.dart';
import 'music_player_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final AudioPlayerService audioPlayer;

  const SearchScreen({
    Key? key,
    required this.mediaItems,
    required this.audioPlayer,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late List<MediaItem> _filteredItems;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.mediaItems;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    setState(() {
      _filteredItems = widget.mediaItems.where((item) =>
      item.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          (item.artist?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false))
          .toList();
    });
  }

  Future<void> _playSong(int index) async {
    try {
      final mediaItems = _filteredItems;
      await widget.audioPlayer.setPlaylist(mediaItems, index);
      await widget.audioPlayer.play();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MusicPlayerScreen(
            playlist: mediaItems,
            initialIndex: index,
            audioPlayer: widget.audioPlayer,
            onFavoriteToggle: (item) {
              _toggleFavorite(item);
              setState(() {});
            },
          ),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing song: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleFavorite(MediaItem item) async {
    try {
      final isFav = await _dbHelper.isFavorite(item.id);
      developer.log('Toggling favorite for: ${item.id}');

      if (isFav) {
        await _dbHelper.deleteFavorite(item.id);
      } else {
        await _dbHelper.insertFavorite(item.id);
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFav ? 'Removed from favorites' : 'Added to favorites'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorites'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search songs...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          final color = item.extras?['color'] as Color? ?? Colors.purpleAccent;
          return FutureBuilder<bool>(
            future: _dbHelper.isFavorite(item.id),
            builder: (context, snapshot) {
              final isFavorite = snapshot.data ?? false;
              return Card(
                color: Colors.grey[850],
                margin: const EdgeInsets.only(bottom: 12),
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
                    item.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    item.artist ?? 'Unknown Artist',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white70,
                    ),
                    onPressed: () => _toggleFavorite(item),
                  ),
                  onTap: () => _playSong(index),
                ),
              );
            },
          );
        },
      ),
    );
  }
}