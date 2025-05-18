import 'package:flutter/material.dart';
import 'music_service.dart';

// music_data.dart
class MusicData {
  static List<Map<String, dynamic>> recentlyAdded = [
    {
      'title': 'New Release 1',
      'artist': 'Artist A',
      'path': 'assets/audios/Sanson ki mala pe remix   NFAK .mp3',
      'isAsset': true,
      'color': Colors.purple,
    },
    {
      'title': 'Fresh Track',
      'artist': 'Artist B',
      'path': 'assets/audios/Skyfall- Adele.mp3',
      'isAsset': true,
      'color': Colors.blue,
    },
    {
      'title': 'Latest Sin',
      'artist': 'Artist C',
      'path': 'assets/audios/Young and beautiful-Lana Del Rey.mp3',
      'isAsset': true,
      'color': Colors.red,
    },
  ];

  static List<Map<String, dynamic>> favorites = [];
}