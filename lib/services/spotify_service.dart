import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/song.dart';

class SpotifyService {
  static final SpotifyService _instance = SpotifyService._();
  factory SpotifyService() => _instance;
  SpotifyService._();

  static const _clientId = '0d97c8af532d4b5ab5cb6fd0e64f2a1d';
  static const _clientSecret = '1e1dfb7c918e4ab8aa42d2835963607a';

  final _dio = Dio();
  String? _token;
  DateTime? _tokenExpiry;

  Future<void> _ensureToken() async {
    if (_token != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final res = await _dio.post(
      'https://accounts.spotify.com/api/token',
      data: 'grant_type=client_credentials',
      options: Options(headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      }),
    );
    _token = res.data['access_token'] as String;
    final expiresIn = res.data['expires_in'] as int;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
  }

  Future<List<Song>> search(String query) async {
    await _ensureToken();
    final res = await _dio.get(
      'https://api.spotify.com/v1/search',
      queryParameters: {
        'q': query,
        'type': 'track',
        'market': 'KR',
        'limit': 20,
      },
      options: Options(headers: {'Authorization': 'Bearer $_token'}),
    );
    final items = res.data['tracks']['items'] as List;
    return items.map((item) {
      final artists = (item['artists'] as List).map((a) => a['name'] as String).join(', ');
      final images = item['album']['images'] as List;
      final albumArt = images.isNotEmpty ? images[0]['url'] as String : '';
      return Song(
        id: 'spotify:${item['id']}',
        title: item['name'] as String,
        artist: artists,
        albumArt: albumArt,
      );
    }).toList();
  }

  // Returns original key (0-11) or null if unavailable
  Future<int?> getTrackKey(String spotifyId) async {
    await _ensureToken();
    try {
      final res = await _dio.get(
        'https://api.spotify.com/v1/audio-features/$spotifyId',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      final key = res.data['key'];
      return key is int && key >= 0 ? key : null;
    } catch (_) {
      return null;
    }
  }
}
