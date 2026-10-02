import 'dart:async';
import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../services/acrcloud_service.dart';
import '../services/spotify_service.dart';
import '../theme/app_theme.dart';
import 'detail_screen.dart';

enum _State { idle, recording, processing, result, error, noMatch }

class RecognizeScreen extends StatefulWidget {
  const RecognizeScreen({super.key});

  @override
  State<RecognizeScreen> createState() => _RecognizeScreenState();
}

class _RecognizeScreenState extends State<RecognizeScreen> {
  final _acr = AcrCloudService();
  final _spotify = SpotifyService();
  final _db = DatabaseHelper();

  _State _state = _State.idle;
  int _countdown = 10;
  Timer? _timer;
  AcrResult? _result;
  Song? _song;
  String _errorMsg = '';

  void _startRecording() async {
    final hasPermission = await _acr.hasPermission();
    if (!hasPermission) {
      setState(() {
        _state = _State.error;
        _errorMsg = '마이크 권한이 필요해요';
      });
      return;
    }
    await _acr.startRecording();
    setState(() {
      _state = _State.recording;
      _countdown = 10;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _stopAndProcess();
      }
    });
  }

  void _stopAndProcess() async {
    _timer?.cancel();
    setState(() => _state = _State.processing);
    try {
      final result = await _acr.stopAndRecognize();
      if (result == null) {
        setState(() => _state = _State.noMatch);
        return;
      }
      // Enrich with Spotify album art
      Song? enriched;
      try {
        final hits = await _spotify.search('${result.title} ${result.artist}');
        if (hits.isNotEmpty) enriched = hits.first;
      } catch (_) {}

      final song = enriched ??
          Song(
            id: 'acr:${DateTime.now().millisecondsSinceEpoch}',
            title: result.title,
            artist: result.artist,
          );

      setState(() {
        _result = result;
        _song = song;
        _state = _State.result;
      });
    } catch (e) {
      setState(() {
        _state = _State.error;
        _errorMsg = '인식 실패: 네트워크를 확인해주세요';
      });
    }
  }

  void _cancel() {
    _timer?.cancel();
    _acr.cancelRecording();
    setState(() => _state = _State.idle);
  }

  void _reset() => setState(() {
        _state = _State.idle;
        _result = null;
        _song = null;
      });

  Future<void> _addToList() async {
    if (_song == null) return;
    await _db.upsert(_song!);
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(song: _song!)),
      );
      _reset();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('인식',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
            ),
            Expanded(child: Center(child: _buildBody())),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _State.idle:
        return _IdleView(onTap: _startRecording);
      case _State.recording:
        return _RecordingView(countdown: _countdown, onCancel: _cancel);
      case _State.processing:
        return const _ProcessingView();
      case _State.result:
        return _ResultView(song: _song!, onAdd: _addToList, onReset: _reset);
      case _State.noMatch:
        return _NoMatchView(onRetry: _reset);
      case _State.error:
        return _ErrorView(message: _errorMsg, onRetry: _reset);
    }
  }
}

class _IdleView extends StatelessWidget {
  final VoidCallback onTap;
  const _IdleView({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
              boxShadow: [
                BoxShadow(
                    color: AppColors.accent.withOpacity(0.4), blurRadius: 48)
              ],
            ),
            child: const Icon(Icons.mic, color: AppColors.bg, size: 60),
          ),
        ),
        const SizedBox(height: 32),
        const Text('탭하여 노래 인식',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('전주가 나올 때 탭하세요',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _RecordingView extends StatelessWidget {
  final int countdown;
  final VoidCallback onCancel;
  const _RecordingView({required this.countdown, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: CircularProgressIndicator(
                value: countdown / 10,
                strokeWidth: 4,
                color: AppColors.accent,
                backgroundColor: AppColors.surface2,
              ),
            ),
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.accent),
              child: Center(
                child: Text('$countdown',
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppColors.bg)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text('듣는 중...',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 24),
        TextButton(
          onPressed: onCancel,
          child: const Text('취소',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppColors.accent),
        SizedBox(height: 24),
        Text('분석 중...',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final Song song;
  final VoidCallback onAdd;
  final VoidCallback onReset;
  const _ResultView(
      {required this.song, required this.onAdd, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12)),
          child: song.albumArt.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(song.albumArt, fit: BoxFit.cover))
              : const Icon(Icons.music_note,
                  color: AppColors.textMuted, size: 40),
        ),
        const SizedBox(height: 20),
        const Icon(Icons.check_circle, color: AppColors.accent, size: 28),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(song.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 6),
        Text(song.artist,
            style:
                const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('내 목록에 추가',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onReset,
          child: const Text('다시 인식',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _NoMatchView extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoMatchView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.music_off, color: AppColors.textMuted, size: 56),
        const SizedBox(height: 20),
        const Text('인식 실패',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('노래를 찾지 못했어요\n전주가 나올 때 다시 시도해보세요',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextButton(
          onPressed: onRetry,
          child: const Text('다시 시도',
              style: TextStyle(color: AppColors.accent, fontSize: 15)),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 56),
        const SizedBox(height: 20),
        Text(message,
            style: const TextStyle(
                fontSize: 15, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextButton(
          onPressed: onRetry,
          child: const Text('다시 시도',
              style: TextStyle(color: AppColors.accent, fontSize: 15)),
        ),
      ],
    );
  }
}
