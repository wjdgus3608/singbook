import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/api_keys.dart';

class AcrResult {
  final String title;
  final String artist;
  final String? albumArt;
  final int? spotifyKey;

  const AcrResult({
    required this.title,
    required this.artist,
    this.albumArt,
    this.spotifyKey,
  });
}

enum AcrFailReason { silent, noMatch, apiError }

class AcrFailure {
  final AcrFailReason reason;
  final String? message;
  const AcrFailure(this.reason, [this.message]);
}

class AcrCloudService {
  static final AcrCloudService _instance = AcrCloudService._();
  factory AcrCloudService() => _instance;
  AcrCloudService._();

  static String get _host => ApiKeys.acrHost;
  static String get _accessKey => ApiKeys.acrAccessKey;
  static String get _accessSecret => ApiKeys.acrAccessSecret;

  // WAV header = 44 bytes; 16kHz 16bit mono 10s = ~320KB
  // If PCM amplitude (post-header) is very low, audio was silent
  static const _silenceThreshold = 800; // out of 32768 max
  static const _wavHeaderBytes = 44;

  final _recorder = AudioRecorder();
  final _dio = Dio();
  String? _recordPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/acr_sample.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: _recordPath!,
    );
  }

  // Returns AcrResult on success, throws AcrFailure on failure
  Future<AcrResult?> stopAndRecognize() async {
    await _recorder.stop();
    if (_recordPath == null) throw const AcrFailure(AcrFailReason.silent);

    final file = File(_recordPath!);
    if (!file.existsSync()) throw const AcrFailure(AcrFailReason.silent);

    final bytes = await file.readAsBytes();
    if (_isSilent(bytes)) throw const AcrFailure(AcrFailReason.silent);

    return _identify(bytes);
  }

  Future<void> cancelRecording() async {
    await _recorder.stop();
  }

  bool _isSilent(Uint8List bytes) {
    if (bytes.length <= _wavHeaderBytes) return true;
    final pcm = bytes.buffer.asInt16List(_wavHeaderBytes);
    if (pcm.isEmpty) return true;
    // sample ~2000 frames spread across recording
    final step = (pcm.length / 2000).ceil().clamp(1, pcm.length);
    double sum = 0;
    int count = 0;
    for (int i = 0; i < pcm.length; i += step) {
      sum += pcm[i].abs();
      count++;
    }
    return (sum / count) < _silenceThreshold;
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

    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    return _parse(data);
  }

  String _sign(String stringToSign) {
    final key = utf8.encode(_accessSecret);
    final msg = utf8.encode(stringToSign);
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(msg);
    return base64Encode(digest.bytes);
  }

  AcrResult? _parse(dynamic data) {
    final status = data['status'];
    final codeRaw = status['code'];
    final code = codeRaw is int ? codeRaw : int.tryParse(codeRaw.toString()) ?? -1;
    final msg = status['msg']?.toString() ?? 'unknown';
    if (code == 1001) throw const AcrFailure(AcrFailReason.noMatch);
    if (code != 0) throw AcrFailure(AcrFailReason.apiError, 'ACR $code: $msg');

    final musics = data['metadata']?['music'] as List?;
    if (musics == null || musics.isEmpty) throw const AcrFailure(AcrFailReason.noMatch);

    final music = musics[0];
    final title = music['title'] as String;
    final artist = (music['artists'] as List).first['name'] as String;
    return AcrResult(title: title, artist: artist);
  }
}
