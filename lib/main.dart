import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_player_service.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'favorites_screen.dart';
import 'media_item.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RhythMix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.purpleAccent,
          secondary: Colors.purpleAccent,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeWrapper(),
      },
    );
  }
}

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _currentIndex = 0;
  late final AudioPlayerService audioPlayer;
  List<MediaItem> mediaItems = [];

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayerService();
    _initializeAudioPlayer();
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      await audioPlayer.initialize();
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(audioPlayer: audioPlayer),
          LibraryScreen(
            audioPlayer: audioPlayer,
            onSongsLoaded: (songs) => mediaItems = songs,
          ),
          FavoritesScreen(
            allSongs: mediaItems,
            audioPlayer: audioPlayer,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.white70,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}