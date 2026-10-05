import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:singbook/models/song.dart';

// Inline the parse logic to test without Dio dependency

List<Song> parseItunesResponse(dynamic responseData) {
  final data = responseData is String ? jsonDecode(responseData as String) : responseData;
  final items = data['results'] as List;
  return items.map<Song>((item) {
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

Song? parseItunesFirst(dynamic responseData) {
  final songs = parseItunesResponse(responseData);
  return songs.isEmpty ? null : songs.first;
}

// ACR parse logic
class _AcrResult {
  final String title;
  final String artist;
  _AcrResult(this.title, this.artist);
}

_AcrResult? parseAcrResponse(dynamic responseData) {
  final data = responseData is String ? jsonDecode(responseData as String) : responseData;
  final status = data['status'];
  final codeRaw = status['code'];
  final code = codeRaw is int ? codeRaw : int.tryParse(codeRaw.toString()) ?? -1;
  final msg = status['msg']?.toString() ?? 'unknown';
  if (code == 1001) return null;
  if (code != 0) throw Exception('ACR $code: $msg');

  final musics = data['metadata']?['music'] as List?;
  if (musics == null || musics.isEmpty) return null;
  final music = musics[0];
  return _AcrResult(music['title'] as String, (music['artists'] as List).first['name'] as String);
}

void main() {
  group('iTunes response parsing', () {
    final mapResponse = {
      'resultCount': 2,
      'results': [
        {
          'trackId': 12345,
          'trackName': 'Lilac',
          'artistName': 'IU',
          'artworkUrl100': 'https://example.com/100x100bb.jpg',
        },
        {
          'trackId': 67890,
          'trackName': 'Good Day',
          'artistName': 'IU',
          'artworkUrl100': 'https://example.com/100x100bb.jpg',
        }
      ]
    };

    final stringResponse = jsonEncode(mapResponse);

    test('parses Map response', () {
      final songs = parseItunesResponse(mapResponse);
      expect(songs.length, 2);
      expect(songs[0].title, 'Lilac');
      expect(songs[0].artist, 'IU');
      expect(songs[0].id, 'itunes:12345');
      expect(songs[0].albumArt, contains('600x600bb'));
    });

    test('parses String (raw JSON) response', () {
      final songs = parseItunesResponse(stringResponse);
      expect(songs.length, 2);
      expect(songs[0].title, 'Lilac');
    });

    test('handles empty results', () {
      final songs = parseItunesResponse({'resultCount': 0, 'results': []});
      expect(songs.isEmpty, true);
    });
  });

  group('ACR response parsing', () {
    test('success response (int code)', () {
      final data = {
        'status': {'code': 0, 'msg': 'Success'},
        'metadata': {
          'music': [
            {'title': '봄날', 'artists': [{'name': 'BTS'}]}
          ]
        }
      };
      final result = parseAcrResponse(data);
      expect(result?.title, '봄날');
      expect(result?.artist, 'BTS');
    });

    test('success response (String code)', () {
      final data = {
        'status': {'code': '0', 'msg': 'Success'},
        'metadata': {
          'music': [
            {'title': '봄날', 'artists': [{'name': 'BTS'}]}
          ]
        }
      };
      final result = parseAcrResponse(data);
      expect(result?.title, '봄날');
    });

    test('no match (code 1001)', () {
      final result = parseAcrResponse({'status': {'code': 1001, 'msg': 'No Result'}});
      expect(result, isNull);
    });

    test('no match (String code 1001)', () {
      final result = parseAcrResponse({'status': {'code': '1001', 'msg': 'No Result'}});
      expect(result, isNull);
    });

    test('auth error throws exception', () {
      expect(
        () => parseAcrResponse({'status': {'code': 3001, 'msg': 'Access denied'}}),
        throwsA(isA<Exception>()),
      );
    });

    test('parses String (raw JSON) response', () {
      final data = jsonEncode({
        'status': {'code': 0, 'msg': 'Success'},
        'metadata': {
          'music': [
            {'title': '봄날', 'artists': [{'name': 'BTS'}]}
          ]
        }
      });
      final result = parseAcrResponse(data);
      expect(result?.title, '봄날');
    });
  });
}
