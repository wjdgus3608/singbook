import 'dart:convert';

class Song {
  final String id;
  final String title;
  final String artist;
  final String albumArt;
  Map<String, int> keyOffsets; // {'tj': 0, 'ky': 0, 'other': 0}
  String origKey;
  String memo;
  List<String> tags;
  final int updatedAt;

  static const brands = ['tj', 'ky', 'other'];
  static const brandLabels = {'tj': 'TJ', 'ky': '금영', 'other': '기타'};

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt = '',
    Map<String, int>? keyOffsets,
    this.origKey = '',
    this.memo = '',
    List<String>? tags,
    int? updatedAt,
  })  : keyOffsets = keyOffsets ?? {},
        tags = tags ?? [],
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  int keyOffsetFor(String brand) => keyOffsets[brand] ?? 0;
  bool get hasAnyOffset => brands.any((b) => keyOffsetFor(b) != 0);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album_art': albumArt,
        'key_offsets': jsonEncode(keyOffsets),
        'orig_key': origKey,
        'memo': memo,
        'tags': jsonEncode(tags),
        'updated_at': updatedAt,
      };

  factory Song.fromMap(Map<String, dynamic> m) => Song(
        id: m['id'],
        title: m['title'],
        artist: m['artist'],
        albumArt: m['album_art'] ?? '',
        keyOffsets: _parseKeyOffsets(m),
        origKey: m['orig_key'] ?? '',
        memo: m['memo'] ?? '',
        tags: List<String>.from(jsonDecode(m['tags'] ?? '[]')),
        updatedAt: m['updated_at'],
      );

  static Map<String, int> _parseKeyOffsets(Map<String, dynamic> m) {
    try {
      final raw = m['key_offsets'];
      if (raw != null && raw != '{}' && raw != '') {
        final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (_) {}
    // Legacy fallback: migrate old key_offset to all brands
    final legacy = m['key_offset'] as int? ?? 0;
    if (legacy != 0) {
      return {'tj': legacy, 'ky': legacy, 'other': legacy};
    }
    return {};
  }

  Song copyWith({
    Map<String, int>? keyOffsets,
    String? origKey,
    String? memo,
    List<String>? tags,
  }) =>
      Song(
        id: id,
        title: title,
        artist: artist,
        albumArt: albumArt,
        keyOffsets: keyOffsets ?? Map.from(this.keyOffsets),
        origKey: origKey ?? this.origKey,
        memo: memo ?? this.memo,
        tags: tags ?? this.tags,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
}
