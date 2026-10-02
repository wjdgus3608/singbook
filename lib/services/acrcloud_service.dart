import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AcrResult {
  final String title;
  final String artist;
  final String? albumArt;
  final int? spotifyKey; // 0-11 or null

  const AcrResult({
    required this.title,
    required this.artist,
    this.albumArt,
    this.spotifyKey,
  });
}

class AcrCloudService {
  static final AcrCloudService _instance = AcrCloudService._();
  factory AcrCloudService() => _instance;
  AcrCloudService._();

  // ACRCloud credentials — host from console project page
  static const _host = 'identify-ap-southeast-1.acrcloud.com';
  static const _accessKey = '87e115edf100ce03634fa1ccd051be48';
  static const _accessSecret = 'EFoJf97wY4dDYSZygh6N7aK2jQjHV73gl9u9XPFx';

  final _recorder = AudioRecorder();
  final _dio = Dio();
  String? _recordPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/acr_sample.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 8000),
      path: _recordPath!,
    );
  }

  Future<AcrResult?> stopAndRecognize() async {
    await _recorder.stop();
    if (_recordPath == null) return null;

    final file = File(_recordPath!);
    if (!file.existsSync()) return null;

    final bytes = await file.readAsBytes();
    return _identify(bytes);
  }

  Future<void> cancelRecording() async {
    await _recorder.stop();
  }

  Future<AcrResult?> _identify(List<int> bytes) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final stringToSign =
        'POST\n/v1/identify\n$_accessKey\naudio\n1\n$timestamp';
    final sig = _sign(stringToSign);

    final formData = FormData.fromMap({
      'sample': MultipartFile.fromBytes(bytes, filename: 'sample.wav'),
      'access_key': _accessKey,
      'data_type': 'audio',
      'signature_version': '1',
      'signature': sig,
      'sample_bytes': bytes.length.toString(),
      'timestamp': timestamp,
    });

    final res = await _dio.post(
      'https://$_host/v1/identify',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return _parse(res.data);
  }

  String _sign(String stringToSign) {
    final key = utf8.encode(_accessSecret);
    final msg = utf8.encode(stringToSign);
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(msg);
    return base64Encode(digest.bytes);
  }

  AcrResult? _parse(dynamic data) {
    try {
      final status = data['status'];
      if (status['code'] != 0) return null; // no match

      final music = data['metadata']['music'][0];
      final title = music['title'] as String;
      final artist = (music['artists'] as List).first['name'] as String;

      String? albumArt;
      final spotify = music['external_metadata']?['spotify'];
      if (spotify != null) {
        // Spotify album art not in ACRCloud response directly;
        // use track ID for later lookup if needed
      }

      return AcrResult(title: title, artist: artist, albumArt: albumArt);
    } catch (_) {
      return null;
    }
  }
}
