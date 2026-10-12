import 'dart:async';
import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../services/pitch_service.dart';
import '../theme/app_theme.dart';

class RangeScreen extends StatefulWidget {
  const RangeScreen({super.key});

  @override
  State<RangeScreen> createState() => _RangeScreenState();
}

class _RangeScreenState extends State<RangeScreen> {
  final _db = DatabaseHelper();
  final _pitch = PitchService();

  String _myLow = '';
  String _myHigh = '';
  List<Song> _songs = [];

  bool _measuring = false;
  String _currentNote = '';
  String _sessionLow = '';
  String _sessionHigh = '';
  StreamSubscription<double?>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final range = await _db.getUserRange();
    final songs = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _myLow = range?['low'] ?? '';
      _myHigh = range?['high'] ?? '';
      _songs = songs.where((s) => s.hasRange).toList();
    });
  }

  Future<void> _startMeasuring() async {
    final ok = await _pitch.hasPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크 권한이 필요해요')),
        );
      }
      return;
    }
    setState(() {
      _measuring = true;
      _currentNote = '';
      _sessionLow = '';
      _sessionHigh = '';
    });
    final stream = await _pitch.start();
    _sub = stream.listen((hz) {
      if (hz == null) return;
      final note = PitchService.hzToNote(hz);
      if (note.isEmpty) return;
      final midi = PitchService.noteToMidi(note);
      setState(() {
        _currentNote = note;
        if (_sessionLow.isEmpty ||
            midi < PitchService.noteToMidi(_sessionLow)) {
          _sessionLow = note;
        }
        if (_sessionHigh.isEmpty ||
            midi > PitchService.noteToMidi(_sessionHigh)) {
          _sessionHigh = note;
        }
      });
    });
  }

  Future<void> _stopMeasuring({bool save = true}) async {
    await _sub?.cancel();
    _sub = null;
    await _pitch.stop();
    if (save && _sessionLow.isNotEmpty && _sessionHigh.isNotEmpty) {
      await _db.saveUserRange(_sessionLow, _sessionHigh);
      setState(() {
        _myLow = _sessionLow;
        _myHigh = _sessionHigh;
      });
    }
    if (mounted) setState(() => _measuring = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pitch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text('음역대',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _MyRangeCard(low: _myLow, high: _myHigh),
                    const SizedBox(height: 16),
                    _MeasureSection(
                      measuring: _measuring,
                      currentNote: _currentNote,
                      sessionLow: _sessionLow,
                      sessionHigh: _sessionHigh,
                      onStart: _startMeasuring,
                      onStop: () => _stopMeasuring(save: true),
                      onCancel: () => _stopMeasuring(save: false),
                    ),
                    if (_songs.isNotEmpty && _myLow.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SongCompareList(
                        songs: _songs,
                        myLow: _myLow,
                        myHigh: _myHigh,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 내 음역대 카드 ───────────────────────────────────────────────────────────

class _MyRangeCard extends StatelessWidget {
  final String low;
  final String high;
  const _MyRangeCard({required this.low, required this.high});

  @override
  Widget build(BuildContext context) {
    final hasRange = low.isNotEmpty && high.isNotEmpty;
    final span = PitchService.rangeSpan(low, high);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('내 음역대',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (!hasRange)
            const Text('아직 측정된 음역대가 없어요',
                style: TextStyle(fontSize: 15, color: AppColors.textMuted))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NoteBox(note: low, color: const Color(0xFF6BB5FF)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_forward,
                          color: AppColors.textMuted, size: 18),
                      const SizedBox(height: 2),
                      Text('$span반음',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                _NoteBox(note: high, color: AppColors.accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String note;
  final Color color;
  const _NoteBox({required this.note, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(note,
            style: AppTheme.mono(22, FontWeight.w800, color)),
      ),
    );
  }
}

// ── 측정 섹션 ────────────────────────────────────────────────────────────────

class _MeasureSection extends StatelessWidget {
  final bool measuring;
  final String currentNote;
  final String sessionLow;
  final String sessionHigh;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _MeasureSection({
    required this.measuring,
    required this.currentNote,
    required this.sessionLow,
    required this.sessionHigh,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: measuring ? _buildActive() : _buildIdle(),
    );
  }

  Widget _buildIdle() {
    return Column(
      children: [
        const Icon(Icons.mic_none_outlined,
            color: AppColors.textMuted, size: 36),
        const SizedBox(height: 8),
        const Text('음역대 측정',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('노래를 부르면 최저/최고음을 자동으로 기록해요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          width: 180,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.mic, size: 18),
            label: const Text('측정 시작',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActive() {
    final hasRange = sessionLow.isNotEmpty && sessionHigh.isNotEmpty;
    return Column(
      children: [
        // 현재 음
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withOpacity(0.15),
            border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
          ),
          child: Center(
            child: Text(
              currentNote.isEmpty ? '–' : currentNote,
              style: AppTheme.mono(32, FontWeight.w900, AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 감지된 범위
        if (hasRange)
          Text(
            '$sessionLow  ~  $sessionHigh',
            style: AppTheme.mono(
                16, FontWeight.w700, AppColors.textPrimary),
          )
        else
          const Text('노래를 부르세요...',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: onCancel,
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: hasRange ? onStop : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bg,
                disabledBackgroundColor: AppColors.surface2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              child: const Text('측정 완료',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 곡 비교 리스트 ────────────────────────────────────────────────────────────

class _SongCompareList extends StatelessWidget {
  final List<Song> songs;
  final String myLow;
  final String myHigh;
  const _SongCompareList(
      {required this.songs, required this.myLow, required this.myHigh});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('내 곡 음역 비교',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...songs.map((song) => _SongRangeRow(
              song: song,
              myLow: myLow,
              myHigh: myHigh,
            )),
      ],
    );
  }
}

class _SongRangeRow extends StatelessWidget {
  final Song song;
  final String myLow;
  final String myHigh;
  const _SongRangeRow(
      {required this.song, required this.myLow, required this.myHigh});

  @override
  Widget build(BuildContext context) {
    final status =
        PitchService.fitStatus(song.lowNote, song.highNote, myLow, myHigh);
    final (icon, color, label) = switch (status) {
      'fit' => (Icons.check_circle_outline, AppColors.accent, '내 범위에 맞음'),
      'partial' => (
          Icons.warning_amber_outlined,
          const Color(0xFFFFCC44),
          '일부 범위 초과'
        ),
      _ => (Icons.cancel_outlined, AppColors.danger, '범위 초과'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${song.lowNote} ~ ${song.highNote}',
                    style: AppTheme.mono(
                        12, FontWeight.w500, AppColors.textSecondary)),
                const SizedBox(height: 6),
                _RangeBar(
                  songLow: song.lowNote,
                  songHigh: song.highNote,
                  myLow: myLow,
                  myHigh: myHigh,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 10, color: color),
                  textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );
  }
}

// 시각적 범위 바
class _RangeBar extends StatelessWidget {
  final String songLow;
  final String songHigh;
  final String myLow;
  final String myHigh;
  const _RangeBar(
      {required this.songLow,
      required this.songHigh,
      required this.myLow,
      required this.myHigh});

  @override
  Widget build(BuildContext context) {
    // 전체 시각 범위: C2(36) ~ C6(84) = 48반음
    const vizLow = 36;
    const vizHigh = 84;
    const vizSpan = vizHigh - vizLow;

    final sl = PitchService.noteToMidi(songLow).clamp(vizLow, vizHigh);
    final sh = PitchService.noteToMidi(songHigh).clamp(vizLow, vizHigh);
    final ul = PitchService.noteToMidi(myLow).clamp(vizLow, vizHigh);
    final uh = PitchService.noteToMidi(myHigh).clamp(vizLow, vizHigh);

    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 20,
        child: Stack(
          children: [
            // 배경
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // 내 음역대 (반투명 보라)
            Positioned(
              left: (ul - vizLow) / vizSpan * w,
              width: ((uh - ul) / vizSpan * w).clamp(2.0, w),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // 곡 음역대 (흰색)
            Positioned(
              left: (sl - vizLow) / vizSpan * w,
              width: ((sh - sl) / vizSpan * w).clamp(2.0, w),
              top: 4,
              bottom: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.textDim.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
