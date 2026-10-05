import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/song.dart';

class MusicSearchService {
  static final MusicSearchService _instance = MusicSearchService._();
  factory MusicSearchService() => _instance;
  MusicSearchService._();

  final _dio = Dio();

  Future<List<Song>> search(String query) async {
    final res = await _dio.get(
      'https://itunes.apple.com/search',
      queryParameters: {
        'term': query,
        'media': 'music',
        'entity': 'song',
        'country': 'KR',
        'limit': 20,
      },
    );
    final body = res.data is String ? jsonDecode(res.data as String) : res.data;
    final items = body['results'] as List;
    return items.map((item) {
      final artwork = (item['artworkUrl100'] as String? ?? '')
          .replaceAll('100x100bb', '600x600bb');
      return Song(
        id: 'itunes:${item['trackId']}',
        title: item['trackName'] as String? ?? '',
        artist: item['artistName'] as String? ?? '',
        albumArt: artwork,
      );
    }).toList();
  }
}
