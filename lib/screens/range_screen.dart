import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../services/pitch_service.dart';
import '../theme/app_theme.dart';
import '../widgets/help_sheet.dart';

enum _MeasurePhase { idle, measuring, result }

class RangeScreen extends StatefulWidget {
  const RangeScreen({super.key});

  @override
  State<RangeScreen> createState() => RangeScreenState();
}

class RangeScreenState extends State<RangeScreen> with WidgetsBindingObserver {
  void reload() => _load();
  final _db = DatabaseHelper();
  final _pitch = PitchService();

  List<Map<String, dynamic>> _records = [];
  String _overallLow = '';
  String _overallHigh = '';
  List<Song> _songs = [];

  _MeasurePhase _phase = _MeasurePhase.idle;
  String _currentNote = '';
  String _sessionLow = '';
  String _sessionHigh = '';
  // result phase에 고정된 값
  String _resultLow = '';
  String _resultHigh = '';
  StreamSubscription<double?>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _phase == _MeasurePhase.measuring) {
      _cancelMeasuring();
    }
  }

  Future<void> _load() async {
    final records = await _db.getUserRangeRecords();
    final songs = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _records = records;
      _songs = songs;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('마이크 권한이 필요해요')));
      }
      return;
    }
    setState(() {
      _phase = _MeasurePhase.measuring;
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

  Future<void> _stopMeasuring() async {
    await _sub?.cancel();
    _sub = null;
    await _pitch.stop();
    if (!mounted) return;
    if (_sessionLow.isEmpty || _sessionHigh.isEmpty) {
      setState(() => _phase = _MeasurePhase.idle);
      return;
    }
    setState(() {
      _resultLow = _sessionLow;
      _resultHigh = _sessionHigh;
      _phase = _MeasurePhase.result;
    });
  }

  Future<void> _saveResult() async {
    await _db.addUserRangeRecord(_resultLow, _resultHigh);
    await _load();
    if (mounted) setState(() => _phase = _MeasurePhase.idle);
  }

  Future<void> _cancelMeasuring() async {
    await _sub?.cancel();
    _sub = null;
    await _pitch.stop();
    if (mounted) setState(() => _phase = _MeasurePhase.idle);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('음역대',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => showHelpSheet(context,
                        title: '음역대 사용법',
                        items: [
                          const HelpItem(Icons.mic_outlined, '내 음역대 측정',
                              '내 목소리 범위가 궁금할 때 측정 시작을 눌러보세요. 낮은 음부터 높은 음까지 쭉 내보내고 완료하면 기록이 쌓입니다.'),
                          const HelpItem(Icons.bar_chart_outlined, '전체 음역대 확인',
                              '측정을 여러 번 반복할수록 정확해져요. 저장된 기록 중 가장 넓은 범위를 자동으로 합산해서 나의 전체 음역대를 보여줍니다.'),
                          const HelpItem(Icons.scatter_plot_outlined, '내 곡 키 위치',
                              '원키를 입력해 둔 곡이 내 음역대 어디쯤에 있는지 점으로 한눈에 볼 수 있어요. 원키는 각 곡 상세 화면에서 설정할 수 있어요.'),
                          const HelpItem(Icons.palette_outlined, '점 색상 의미',
                              '음역대를 측정하면 점 색상으로 부르기 편한 정도를 알 수 있어요. 초록이면 편하게, 노랑이면 아슬아슬하게, 빨강이면 범위를 벗어나요.'),
                        ]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _OverallRangeCard(
                      low: _overallLow,
                      high: _overallHigh,
                      recordCount: _records.length,
                    ),
                    const SizedBox(height: 12),
                    _MeasureSection(
                      phase: _phase,
                      currentNote: _currentNote,
                      sessionLow: _sessionLow,
                      sessionHigh: _sessionHigh,
                      resultLow: _resultLow,
                      resultHigh: _resultHigh,
                      onStart: _startMeasuring,
                      onStop: _stopMeasuring,
                      onCancel: _cancelMeasuring,
                      onSave: _saveResult,
                      onRemeasure: _startMeasuring,
                    ),
                    if (_songs.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SongKeyMap(
                        songs: _songs,
                        myLow: _overallLow,
                        myHigh: _overallHigh,
                      ),
                    ],
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
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_forward,
                          color: AppColors.textMuted, size: 16),
                      const SizedBox(height: 2),
                      Text(PitchService.spanLabel(span),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                          textAlign: TextAlign.center),
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
    final solfege = PitchService.noteToSolfege(note);
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(note, style: AppTheme.mono(18, FontWeight.w800, color)),
          const SizedBox(height: 2),
          Text(solfege,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.75))),
        ],
      ),
    );
  }
}

// 수평 범위 바 (C2~C6 눈금 포함)
class _RangeBar extends StatelessWidget {
  final String low;
  final String high;

  const _RangeBar({required this.low, required this.high});

  static const _vizMin = 36; // C2
  static const _vizMax = 84; // C6
  static const _vizSpan = _vizMax - _vizMin;

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
            height: 44,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                // 4반음마다 짧은 눈금
                for (int m = _vizMin + 4; m < _vizMax; m += 4)
                  if (m % 12 != 0)
                    Positioned(
                      left: _frac(m) * w - 0.5,
                      top: 14,
                      bottom: 14,
                      width: 1,
                      child: Container(
                          color: AppColors.border.withOpacity(0.6)),
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
                // 범위 바
                if (low.isNotEmpty && high.isNotEmpty)
                  Positioned(
                    left: _frac(lMidi) * w,
                    width: max(4.0, _frac(hMidi) * w - _frac(lMidi) * w),
                    top: 6,
                    bottom: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.accent.withOpacity(0.45),
                              blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
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
  final _MeasurePhase phase;
  final String currentNote;
  final String sessionLow;
  final String sessionHigh;
  final String resultLow;
  final String resultHigh;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onRemeasure;

  const _MeasureSection({
    required this.phase,
    required this.currentNote,
    required this.sessionLow,
    required this.sessionHigh,
    required this.resultLow,
    required this.resultHigh,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    required this.onSave,
    required this.onRemeasure,
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
      child: switch (phase) {
        _MeasurePhase.idle => _buildIdle(),
        _MeasurePhase.measuring => _buildMeasuring(),
        _MeasurePhase.result => _buildResult(),
      },
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
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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

  Widget _buildMeasuring() {
    final hasRange = sessionLow.isNotEmpty;
    final pulsing = currentNote.isNotEmpty;
    return Column(
      children: [
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
                  color:
                      pulsing ? AppColors.accent : AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                    style: AppTheme.mono(28, FontWeight.w900,
                        sessionLow.isEmpty
                            ? AppColors.textMuted
                            : const Color(0xFF6BB5FF)),
                  ),
                  if (sessionLow.isNotEmpty)
                    Text(PitchService.noteToSolfege(sessionLow),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
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
                    style: AppTheme.mono(28, FontWeight.w900,
                        sessionHigh.isEmpty
                            ? AppColors.textMuted
                            : AppColors.accent),
                  ),
                  if (sessionHigh.isNotEmpty)
                    Text(PitchService.noteToSolfege(sessionHigh),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  const Text('최고음',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
        if (hasRange) ...[
          const SizedBox(height: 14),
          _RangeBar(low: sessionLow, high: sessionHigh),
          const SizedBox(height: 6),
          Text(
            PitchService.spanLabel(
                PitchService.rangeSpan(sessionLow, sessionHigh)),
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted),
          ),
        ] else
          const SizedBox(height: 14),
        const SizedBox(height: 4),
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

  Widget _buildResult() {
    final span = PitchService.rangeSpan(resultLow, resultHigh);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('측정 결과',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NoteBox(note: resultLow, color: const Color(0xFF6BB5FF)),
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.arrow_forward,
                      color: AppColors.textMuted, size: 16),
                  const SizedBox(height: 2),
                  Text(PitchService.spanLabel(span),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            _NoteBox(note: resultHigh, color: AppColors.accent),
          ],
        ),
        const SizedBox(height: 14),
        _RangeBar(low: resultLow, high: resultHigh),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRemeasure,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('다시 측정',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('저장',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 기록 이력 (월 → 일 2단계 접힘/펼침) ──────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final void Function(int id) onDelete;
  final String Function(int ms) formatTs;

  const _HistoryList({
    required this.records,
    required this.onDelete,
    required this.formatTs,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  // month → day → records (insertion order = DESC by measured_at)
  Map<String, Map<String, List<Map<String, dynamic>>>> get _grouped {
    final map = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final r in records) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r['measured_at'] as int);
      final monthKey =
          '${dt.year}년 ${dt.month.toString().padLeft(2, '0')}월';
      final wd = _weekdays[dt.weekday - 1];
      final dayKey =
          '${dt.month}월 ${dt.day}일 ($wd)';
      map.putIfAbsent(monthKey, () => {}).putIfAbsent(dayKey, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final months = grouped.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('측정 기록',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...months.asMap().entries.map((mEntry) {
          final isFirstMonth = mEntry.key == 0;
          final monthKey = mEntry.value;
          final dayMap = grouped[monthKey]!;
          final totalCount =
              dayMap.values.fold(0, (s, l) => s + l.length);
          return _MonthGroup(
            monthLabel: monthKey,
            totalCount: totalCount,
            dayMap: dayMap,
            initiallyExpanded: isFirstMonth,
            isFirstMonth: isFirstMonth,
            onDelete: onDelete,
            formatTs: formatTs,
          );
        }),
      ],
    );
  }
}

class _MonthGroup extends StatelessWidget {
  final String monthLabel;
  final int totalCount;
  final Map<String, List<Map<String, dynamic>>> dayMap;
  final bool initiallyExpanded;
  final bool isFirstMonth;
  final void Function(int id) onDelete;
  final String Function(int ms) formatTs;

  const _MonthGroup({
    required this.monthLabel,
    required this.totalCount,
    required this.dayMap,
    required this.initiallyExpanded,
    required this.isFirstMonth,
    required this.onDelete,
    required this.formatTs,
  });

  @override
  Widget build(BuildContext context) {
    final days = dayMap.keys.toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Row(
            children: [
              Text(monthLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$totalCount개',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ),
            ],
          ),
          iconColor: AppColors.textMuted,
          collapsedIconColor: AppColors.textMuted,
          children: [
            const Divider(
                color: AppColors.border,
                height: 1,
                indent: 16,
                endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: days.asMap().entries.map((dEntry) {
                  final isFirstDay = dEntry.key == 0;
                  final dayKey = dEntry.value;
                  final dayRecords = dayMap[dayKey]!;
                  return _DayGroup(
                    dayLabel: dayKey,
                    records: dayRecords,
                    initiallyExpanded: isFirstMonth && isFirstDay,
                    onDelete: onDelete,
                    formatTs: formatTs,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final String dayLabel;
  final List<Map<String, dynamic>> records;
  final bool initiallyExpanded;
  final void Function(int id) onDelete;
  final String Function(int ms) formatTs;

  const _DayGroup({
    required this.dayLabel,
    required this.records,
    required this.initiallyExpanded,
    required this.onDelete,
    required this.formatTs,
  });

  static String _timeOnly(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          dense: true,
          title: Row(
            children: [
              Text(dayLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              Text('${records.length}건',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          iconColor: AppColors.textMuted,
          collapsedIconColor: AppColors.textMuted,
          children: records.map((r) {
            final id = r['id'] as int;
            final low = r['low_note'] as String;
            final high = r['high_note'] as String;
            final ts = r['measured_at'] as int;
            final span = PitchService.rangeSpan(low, high);
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Text(_timeOnly(ts),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Text(low,
                            style: AppTheme.mono(13, FontWeight.w700,
                                const Color(0xFF6BB5FF))),
                        const Text('  ~  ',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                        Text(high,
                            style: AppTheme.mono(
                                13, FontWeight.w700, AppColors.accent)),
                        const SizedBox(width: 6),
                        Text('$span반음',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textMuted, size: 16),
                    onPressed: () => onDelete(id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── 곡 키 위치 맵 ─────────────────────────────────────────────────────────────

class _SongKeyMap extends StatefulWidget {
  final List<Song> songs;
  final String myLow;
  final String myHigh;
  const _SongKeyMap(
      {required this.songs, required this.myLow, required this.myHigh});

  @override
  State<_SongKeyMap> createState() => _SongKeyMapState();
}

class _SongKeyMapState extends State<_SongKeyMap> {
  String _brand = 'tj';
  bool _showAll = false;
  static const _pageSize = 5;

  static const _vizMin = 36; // C2
  static const _vizMax = 84; // C6
  static const _vizSpan = _vizMax - _vizMin;
  static const _octaveLabels = ['C2', 'C3', 'C4', 'C5', 'C6'];
  static const _octaveMidi = [36, 48, 60, 72, 84];

  double _frac(int midi) =>
      ((midi - _vizMin) / _vizSpan).clamp(0.0, 1.0);

  Color _dotColor(int midi) {
    if (widget.myLow.isEmpty || widget.myHigh.isEmpty) {
      return AppColors.textMuted;
    }
    final lo = PitchService.noteToMidi(widget.myLow);
    final hi = PitchService.noteToMidi(widget.myHigh);
    if (midi >= lo && midi <= hi) return AppColors.accent;
    if ((midi - lo).abs() <= 3 || (midi - hi).abs() <= 3) {
      return const Color(0xFFFFCC44);
    }
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final withKey = widget.songs
        .where((s) => s.origKey.isNotEmpty)
        .toList();
    final noKey = widget.songs
        .where((s) => s.origKey.isEmpty)
        .toList();

    // 각 곡의 midi + color 미리 계산
    final songData = withKey.map((s) {
      final offset = s.keyOffsetFor(_brand);
      final midi = PitchService.origKeyToMidi(s.origKey, offset);
      final color = _dotColor(midi);
      final label =
          '${s.origKey}${offset == 0 ? '' : (offset > 0 ? '+$offset' : '$offset')}';
      return (song: s, midi: midi, color: color, label: label);
    }).toList();

    // 같은 MIDI 위치에 있는 곡들 그룹핑 (스택용)
    final Map<int, List<Color>> stackMap = {};
    for (final d in songData) {
      final pos = d.midi.clamp(_vizMin, _vizMax);
      stackMap.putIfAbsent(pos, () => []).add(d.color);
    }

    final visible = _showAll
        ? songData
        : songData.take(_pageSize).toList();
    final hiddenCount = songData.length - _pageSize;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 + 브랜드 선택
          Row(
            children: [
              const Text('내 곡 키 위치',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              ...Song.brands.map((b) {
                final selected = _brand == b;
                return GestureDetector(
                  onTap: () => setState(() {
                    _brand = b;
                    _showAll = false;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(Song.brandLabels[b]!,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                selected ? AppColors.bg : AppColors.textMuted)),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          // 오버뷰 축 바 (모든 곡 점 표시 + 스택)
          LayoutBuilder(builder: (_, constraints) {
            final w = constraints.maxWidth;
            // 최대 스택 높이 계산 (최대 3단)
            final maxStack =
                stackMap.values.fold(0, (m, v) => max(m, v.length));
            final barH = max(28.0, 12.0 + min(maxStack, 3) * 12.0);

            return Column(
              children: [
                SizedBox(
                  height: barH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      // 옥타브 경계선
                      for (final m in [48, 60, 72])
                        Positioned(
                          left: _frac(m) * w - 0.5,
                          top: 0,
                          bottom: 0,
                          width: 1,
                          child: Container(color: AppColors.border),
                        ),
                      // 내 음역대 배경
                      if (widget.myLow.isNotEmpty && widget.myHigh.isNotEmpty)
                        Positioned(
                          left: _frac(PitchService.noteToMidi(widget.myLow)
                                  .clamp(_vizMin, _vizMax)) *
                              w,
                          width: max(
                            4.0,
                            (_frac(PitchService.noteToMidi(widget.myHigh)
                                            .clamp(_vizMin, _vizMax)) -
                                        _frac(
                                            PitchService.noteToMidi(widget.myLow)
                                                .clamp(_vizMin, _vizMax))) *
                                    w,
                          ),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      // 곡 점들 (스택)
                      for (final entry in stackMap.entries)
                        ...entry.value
                            .take(3)
                            .toList()
                            .asMap()
                            .entries
                            .map((e) {
                          final stackIdx = e.key;
                          final color = e.value;
                          final dotX = (_frac(entry.key) * w - 5)
                              .clamp(0.0, w - 10);
                          return Positioned(
                            left: dotX,
                            bottom: 4.0 + stackIdx * 12.0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                boxShadow: [
                                  BoxShadow(
                                      color: color.withOpacity(0.6),
                                      blurRadius: 4),
                                ],
                              ),
                            ),
                          );
                        }),
                      // 3개 초과 시 "+N" 뱃지
                      for (final entry
                          in stackMap.entries.where((e) => e.value.length > 3))
                        Positioned(
                          left: (_frac(entry.key) * w + 6)
                              .clamp(0.0, w - 20),
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${entry.value.length - 3}',
                              style: const TextStyle(
                                  fontSize: 8, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(_octaveMidi.length, (i) {
                    return Expanded(
                      flex: i < _octaveMidi.length - 1
                          ? ((_octaveMidi[i + 1] - _octaveMidi[i]) * 100)
                              .round()
                          : 1,
                      child: Align(
                        alignment: i == _octaveMidi.length - 1
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(_octaveLabels[i],
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.textMuted)),
                      ),
                    );
                  }),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          // 곡 없음
          if (withKey.isEmpty && noKey.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text('등록된 곡이 없어요',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ),
            ),
          // 원키 있는 곡 목록 (접기/펼치기)
          if (withKey.isNotEmpty)
            LayoutBuilder(builder: (_, constraints) {
              const nameW = 96.0;
              const labelW = 48.0;
              const gap = 8.0;
              final axisW =
                  constraints.maxWidth - nameW - labelW - gap * 2;
              return Column(
                children: [
                  ...visible.map((d) {
                    final dotX =
                        _frac(d.midi.clamp(_vizMin, _vizMax)) * axisW;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: nameW,
                            child: Text(d.song.title,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(
                            width: axisW,
                            height: 20,
                            child: Stack(
                              children: [
                                const Positioned.fill(child: SizedBox()),
                                Positioned(
                                  left: (dotX - 6).clamp(0.0, axisW - 12),
                                  top: 4,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: d.color,
                                      boxShadow: [
                                        BoxShadow(
                                            color: d.color.withOpacity(0.5),
                                            blurRadius: 6),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(
                            width: labelW,
                            child: Text(d.label,
                                style: AppTheme.mono(
                                    11, FontWeight.w600, d.color),
                                textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    );
                  }),
                  // 더 보기 / 접기 버튼
                  if (songData.length > _pageSize)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showAll = !_showAll),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showAll
                                  ? '접기'
                                  : '더 보기 $hiddenCount개',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted),
                            ),
                            Icon(
                              _showAll
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.textMuted,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          // 원키 미입력 구분선 + 목록
          if (noKey.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Container(
                        height: 1,
                        color: AppColors.border,
                        margin: const EdgeInsets.only(right: 8))),
                const Text('원키 미입력',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                Expanded(
                    child: Container(
                        height: 1,
                        color: AppColors.border,
                        margin: const EdgeInsets.only(left: 8))),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: noKey.map((song) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('◌',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textMuted)),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(song.title,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
