import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

class PitchService {
  static final PitchService _instance = PitchService._();
  factory PitchService() => _instance;
  PitchService._();

  final _recorder = AudioRecorder();

  static const _sampleRate = 44100;
  static const _bufferSize = 4096; // samples (= 8192 bytes for PCM16)

  final _detector = PitchDetector(
    audioSampleRate: _sampleRate.toDouble(),
    bufferSize: _bufferSize,
  );

  final _byteBuffer = <int>[];
  StreamSubscription<Uint8List>? _sub;
  StreamController<double?>? _ctrl;
  bool _active = false;
  bool _processing = false;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Stream<double?>> start() async {
    if (_active) await stop();
    _byteBuffer.clear();
    _ctrl = StreamController<double?>.broadcast();
    _active = true;
    _processing = false;

    final byteStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );

    _sub = byteStream.listen(_onBytes, onDone: () => _active = false);
    return _ctrl!.stream;
  }

  void _onBytes(Uint8List bytes) {
    _byteBuffer.addAll(bytes);
    if (_byteBuffer.length >= _bufferSize * 2 && !_processing) {
      _processing = true;
      final chunk =
          Uint8List.fromList(_byteBuffer.sublist(0, _bufferSize * 2));
      _byteBuffer.removeRange(0, _bufferSize * 2);
      _detector.getPitchFromIntBuffer(chunk).then((result) {
        _processing = false;
        if (!_active) return;
        // 80Hz(E2) ~ 1200Hz(D6) 범위만 유효한 보컬로 처리
        _ctrl?.add(
          (result.pitched && result.pitch > 80 && result.pitch < 1200)
              ? result.pitch
              : null,
        );
      }).catchError((_) {
        _processing = false;
        _ctrl?.add(null);
      });
    }
  }

  Future<void> stop() async {
    _active = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _byteBuffer.clear();
    _processing = false;
    await _ctrl?.close();
    _ctrl = null;
  }

  // ── Note utilities ────────────────────────────────────────────────────────

  static const _names = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static String hzToNote(double hz) {
    if (hz <= 0) return '';
    final midi = (12 * log(hz / 440.0) / log(2) + 69).round();
    if (midi < 24 || midi > 96) return ''; // C1~C7
    return '${_names[midi % 12]}${(midi ~/ 12) - 1}';
  }

  static int noteToMidi(String note) {
    if (note.isEmpty) return -1;
    final m = RegExp(r'^([A-G]#?)(-?\d+)$').firstMatch(note);
    if (m == null) return -1;
    final idx = _names.indexOf(m.group(1)!);
    return idx < 0 ? -1 : (int.parse(m.group(2)!) + 1) * 12 + idx;
  }

  static int rangeSpan(String low, String high) {
    final l = noteToMidi(low), h = noteToMidi(high);
    return (l < 0 || h < 0) ? 0 : h - l;
  }

  static String midiToNote(int midi) {
    if (midi < 0 || midi > 127) return '';
    return '${_names[midi % 12]}${(midi ~/ 12) - 1}';
  }

  static const _solfege = [
    '도', '도♯', '레', '레♯', '미', '파', '파♯', '솔', '솔♯', '라', '라♯', '시'
  ];

  static String noteToSolfege(String note) {
    if (note.isEmpty) return '';
    final m = RegExp(r'^([A-G]#?)(-?\d+)$').firstMatch(note);
    if (m == null) return '';
    final idx = _names.indexOf(m.group(1)!);
    if (idx < 0) return '';
    return '${_solfege[idx]}${m.group(2)}';
  }

  // "18반음 (1.5옥타브)" 형태
  static String spanLabel(int span) {
    if (span <= 0) return '';
    final oct = span / 12;
    final octStr = oct == oct.truncateToDouble()
        ? oct.toInt().toString()
        : oct.toStringAsFixed(1);
    return '$span반음 ($octStr옥타브)';
  }

  // origKey ("F#") + offset → MIDI (C4=60 기준)
  static int origKeyToMidi(String key, int offset) {
    if (key.isEmpty) return -1;
    final idx = _names.indexOf(key);
    if (idx < 0) return -1;
    return 60 + idx + offset; // C4=60
  }

  // song range와 user range 비교: 'fit' / 'partial' / 'over'
  static String fitStatus(
      String sLow, String sHigh, String uLow, String uHigh) {
    if (sLow.isEmpty || sHigh.isEmpty || uLow.isEmpty || uHigh.isEmpty) {
      return 'unknown';
    }
    final sl = noteToMidi(sLow), sh = noteToMidi(sHigh);
    final ul = noteToMidi(uLow), uh = noteToMidi(uHigh);
    if (sl < 0 || sh < 0 || ul < 0 || uh < 0) return 'unknown';
    if (sl >= ul && sh <= uh) return 'fit';
    if (sh < ul || sl > uh) return 'over';
    return 'partial';
  }
}
