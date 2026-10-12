import 'dart:async';
import 'dart:math';
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

class _RangeScreenState extends State<RangeScreen> with WidgetsBindingObserver {
  final _db = DatabaseHelper();
  final _pitch = PitchService();

  List<Map<String, dynamic>> _records = [];
  String _overallLow = '';
  String _overallHigh = '';
  List<Song> _songsWithRange = [];

  bool _measuring = false;
  String _currentNote = '';
  String _sessionLow = '';
  String _sessionHigh = '';
  StreamSubscription<double?>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _measuring) {
      _cancelMeasuring();
    }
  }

  Future<void> _load() async {
    final records = await _db.getUserRangeRecords();
    final songs = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _records = records;
      _songsWithRange = songs.where((s) => s.hasRange).toList();
      _computeOverall();
    });
  }

  void _computeOverall() {
    if (_records.isEmpty) {
      _overallLow = '';
      _overallHigh = '';
      return;
    }
    int minMidi = 999, maxMidi = -1;
    for (final r in _records) {
      final l = PitchService.noteToMidi(r['low_note'] as String);
      final h = PitchService.noteToMidi(r['high_note'] as String);
      if (l >= 0 && l < minMidi) minMidi = l;
      if (h >= 0 && h > maxMidi) maxMidi = h;
    }
    _overallLow = minMidi < 999 ? PitchService.midiToNote(minMidi) : '';
    _overallHigh = maxMidi >= 0 ? PitchService.midiToNote(maxMidi) : '';
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
        if (_sessionLow.isEmpty || midi < PitchService.noteToMidi(_sessionLow)) {
          _sessionLow = note;
        }
        if (_sessionHigh.isEmpty || midi > PitchService.noteToMidi(_sessionHigh)) {
          _sessionHigh = note;
        }
      });
    });
  }

  Future<void> _stopMeasuring() async {
    await _sub?.cancel();
    _sub = null;
    await _pitch.stop();

    if (_sessionLow.isEmpty || _sessionHigh.isEmpty) {
      if (mounted) setState(() => _measuring = false);
      return;
    }

    if (!mounted) return;
    final low = _sessionLow;
    final high = _sessionHigh;
    final now = _formatNow();

    final save = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('이 결과를 저장할까요?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$low ~ $high',
                style:
                    AppTheme.mono(20, FontWeight.w800, AppColors.accent)),
            const SizedBox(height: 6),
            Text(now,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('버리기',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('저장',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (save == true) {
      await _db.addUserRangeRecord(low, high);
      await _load();
    }
    if (mounted) setState(() => _measuring = false);
  }

  Future<void> _cancelMeasuring() async {
    await _sub?.cancel();
    _sub = null;
    await _pitch.stop();
    if (mounted) setState(() => _measuring = false);
  }

  Future<void> _deleteRecord(int id) async {
    await _db.deleteUserRangeRecord(id);
    await _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _pitch.stop();
    super.dispose();
  }

  static String _formatNow() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}'
        ' ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  static String _formatTs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                    // 전체 음역대 카드
                    _OverallRangeCard(
                      low: _overallLow,
                      high: _overallHigh,
                      recordCount: _records.length,
                    ),
                    const SizedBox(height: 12),
                    // 측정 섹션
                    _MeasureSection(
                      measuring: _measuring,
                      currentNote: _currentNote,
                      sessionLow: _sessionLow,
                      sessionHigh: _sessionHigh,
                      onStart: _startMeasuring,
                      onStop: _stopMeasuring,
                      onCancel: _cancelMeasuring,
                    ),
                    // 곡 음역 비교
                    if (_songsWithRange.isNotEmpty &&
                        _overallLow.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SongCompareList(
                        songs: _songsWithRange,
                        myLow: _overallLow,
                        myHigh: _overallHigh,
                      ),
                    ],
                    // 기록 이력
                    if (_records.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _HistoryList(
                        records: _records,
                        onDelete: _deleteRecord,
                        formatTs: _formatTs,
                      ),
                    ],
                    const SizedBox(height: 16),
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

// ── 전체 음역대 카드 ──────────────────────────────────────────────────────────

class _OverallRangeCard extends StatelessWidget {
  final String low;
  final String high;
  final int recordCount;
  const _OverallRangeCard(
      {required this.low, required this.high, required this.recordCount});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('전체 음역대',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              if (recordCount > 0)
                Text('$recordCount개 기록',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasRange)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('아직 측정된 음역대가 없어요',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textMuted)),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NoteBox(note: low, color: const Color(0xFF6BB5FF)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      const Text('──────',
                          style: TextStyle(color: AppColors.textMuted)),
                      Text('$span반음',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                _NoteBox(note: high, color: AppColors.accent),
              ],
            ),
            const SizedBox(height: 16),
            _RangeBar(low: low, high: high),
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
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Center(
          child: Text(note, style: AppTheme.mono(20, FontWeight.w800, color))),
    );
  }
}

// 수평 범위 바 (C2~C6 눈금 포함)
class _RangeBar extends StatelessWidget {
  final String low;
  final String high;
  const _RangeBar({
    required this.low,
    required this.high,
  });

  static const _vizMin = 36; // C2
  static const _vizMax = 84; // C6
  static const _vizSpan = _vizMax - _vizMin; // 48

  // C2~C6 옥타브 마커: MIDI 36,48,60,72,84
  static const _octaveLabels = ['C2', 'C3', 'C4', 'C5', 'C6'];
  static const _octaveMidi = [36, 48, 60, 72, 84];

  double _frac(int midi) =>
      ((midi - _vizMin) / _vizSpan).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final lMidi = PitchService.noteToMidi(low).clamp(_vizMin, _vizMax);
    final hMidi = PitchService.noteToMidi(high).clamp(_vizMin, _vizMax);

    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;

      return Column(
        children: [
          SizedBox(
            height: 32,
            child: Stack(
              children: [
                // 배경
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // 옥타브 경계선 (C3, C4, C5)
                for (final midi in [48, 60, 72])
                  Positioned(
                    left: _frac(midi) * w - 0.5,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: Container(color: AppColors.border),
                  ),
                // 전체 범위 바
                if (low.isNotEmpty && high.isNotEmpty)
                  Positioned(
                    left: _frac(lMidi) * w,
                    width: max(4.0, _frac(hMidi) * w - _frac(lMidi) * w),
                    top: 4,
                    bottom: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.accent.withOpacity(0.4),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 옥타브 라벨
          Row(
            children: List.generate(_octaveMidi.length, (i) {
              return Expanded(
                flex: i < _octaveMidi.length - 1
                    ? ((_octaveMidi[i + 1] - _octaveMidi[i]) * 100).round()
                    : 1,
                child: Align(
                  alignment: i == _octaveMidi.length - 1
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(_octaveLabels[i],
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ),
              );
            }),
          ),
        ],
      );
    });
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
            color: AppColors.textMuted, size: 32),
        const SizedBox(height: 6),
        const Text('새 음역대 측정',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('노래를 부르면 최저/최고음을 자동으로 기록해요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        SizedBox(
          width: 160,
          height: 42,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.mic, size: 16),
            label: const Text('측정 시작',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
    final hasRange = sessionLow.isNotEmpty;
    final pulsing = currentNote.isNotEmpty;

    return Column(
      children: [
        // 감지 인디케이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pulsing ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              pulsing ? currentNote : '감지 중...',
              style: TextStyle(
                  fontSize: 13,
                  color: pulsing ? AppColors.accent : AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 최저~최고
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: [
                  Text(
                    sessionLow.isEmpty ? '–' : sessionLow,
                    style: AppTheme.mono(
                        28,
                        FontWeight.w900,
                        sessionLow.isEmpty
                            ? AppColors.textMuted
                            : const Color(0xFF6BB5FF)),
                  ),
                  const Text('최저음',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('~',
                    style: TextStyle(
                        fontSize: 22, color: AppColors.textMuted)),
              ),
              Column(
                children: [
                  Text(
                    sessionHigh.isEmpty ? '–' : sessionHigh,
                    style: AppTheme.mono(
                        28,
                        FontWeight.w900,
                        sessionHigh.isEmpty
                            ? AppColors.textMuted
                            : AppColors.accent),
                  ),
                  const Text('최고음',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              child: const Text('완료',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 기록 이력 ─────────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final void Function(int id) onDelete;
  final String Function(int ms) formatTs;

  const _HistoryList({
    required this.records,
    required this.onDelete,
    required this.formatTs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('측정 기록',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...records.map((r) {
          final id = r['id'] as int;
          final low = r['low_note'] as String;
          final high = r['high_note'] as String;
          final ts = r['measured_at'] as int;
          final span = PitchService.rangeSpan(low, high);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Row(
                        children: [
                          Text(low,
                              style: AppTheme.mono(
                                  15,
                                  FontWeight.w700,
                                  const Color(0xFF6BB5FF))),
                          const Text('  ~  ',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted)),
                          Text(high,
                              style: AppTheme.mono(
                                  15, FontWeight.w700, AppColors.accent)),
                          const SizedBox(width: 8),
                          Text('$span반음',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(formatTs(ts),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => onDelete(id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── 곡 음역 비교 ──────────────────────────────────────────────────────────────

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
      'fit' => (Icons.check_circle_outline, AppColors.accent, '맞음'),
      'partial' => (
          Icons.warning_amber_outlined,
          const Color(0xFFFFCC44),
          '일부 초과'
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
                const SizedBox(height: 4),
                Text('${song.lowNote} ~ ${song.highNote}',
                    style: AppTheme.mono(
                        11, FontWeight.w500, AppColors.textSecondary)),
                const SizedBox(height: 6),
                _SongCompareBar(
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
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SongCompareBar extends StatelessWidget {
  final String songLow;
  final String songHigh;
  final String myLow;
  final String myHigh;
  const _SongCompareBar(
      {required this.songLow,
      required this.songHigh,
      required this.myLow,
      required this.myHigh});

  static const _vizMin = 36;
  static const _vizMax = 84;
  static const _vizSpan = _vizMax - _vizMin;

  double _f(int midi) => ((midi - _vizMin) / _vizSpan).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final sl = PitchService.noteToMidi(songLow).clamp(_vizMin, _vizMax);
    final sh = PitchService.noteToMidi(songHigh).clamp(_vizMin, _vizMax);
    final ul = PitchService.noteToMidi(myLow).clamp(_vizMin, _vizMax);
    final uh = PitchService.noteToMidi(myHigh).clamp(_vizMin, _vizMax);

    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 16,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // 내 음역
            Positioned(
              left: _f(ul) * w,
              width: max(2.0, _f(uh) * w - _f(ul) * w),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // 곡 음역
            Positioned(
              left: _f(sl) * w,
              width: max(2.0, _f(sh) * w - _f(sl) * w),
              top: 3,
              bottom: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.textDim.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
