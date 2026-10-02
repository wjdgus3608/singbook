import 'dart:convert';

class Song {
  final String id;
  final String title;
  final String artist;
  final String albumArt;
  int keyOffset;
  String memo;
  List<String> tags;
  final int updatedAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt = '',
    this.keyOffset = 0,
    this.memo = '',
    List<String>? tags,
    int? updatedAt,
  })  : tags = tags ?? [],
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album_art': albumArt,
        'key_offset': keyOffset,
        'memo': memo,
        'tags': jsonEncode(tags),
        'updated_at': updatedAt,
      };

  factory Song.fromMap(Map<String, dynamic> m) => Song(
        id: m['id'],
        title: m['title'],
        artist: m['artist'],
        albumArt: m['album_art'] ?? '',
        keyOffset: m['key_offset'] ?? 0,
        memo: m['memo'] ?? '',
        tags: List<String>.from(jsonDecode(m['tags'] ?? '[]')),
        updatedAt: m['updated_at'],
      );

  Song copyWith({int? keyOffset, String? memo, List<String>? tags}) => Song(
        id: id,
        title: title,
        artist: artist,
        albumArt: albumArt,
        keyOffset: keyOffset ?? this.keyOffset,
        memo: memo ?? this.memo,
        tags: tags ?? this.tags,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  String get keyLabel => keyOffset > 0 ? '+$keyOffset' : '$keyOffset';
}
