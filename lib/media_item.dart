class MediaItem {
  final String id;
  final String title;
  final String? artist;
  final Uri? artUri;
  final Map<String, dynamic> extras;

  MediaItem({
    required this.id,
    required this.title,
    this.artist,
    this.artUri,
    this.extras = const {},
  });
}