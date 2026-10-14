import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../services/pitch_service.dart';
import '../services/preferences_service.dart';
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
  String _preferredBrand = 'tj';

  _MeasurePhase _phase = _MeasurePhase.idle;
  String _currentNote = '';
  String _sessionLow = '';
  String _sessionHigh = '';
  DateTime _lastNoteDisplay = DateTime(0);
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
    final results = await Future.wait([
      _db.getUserRangeRecords(),
      _db.getAll(),
      PreferencesService.getPreferredBrand(),
    ]);
    if (!mounted) return;
    setState(() {
      _records = results[0] as List<Map<String, dynamic>>;
      _songs = results[1] as List<Song>;
      _preferredBrand = results[2] as String;
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
      final now = DateTime.now();
      final showNote = now.difference(_lastNoteDisplay).inMilliseconds >= 1000;
      if (showNote) _lastNoteDisplay = now;
      setState(() {
        if (showNote) _currentNote = note;
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
                        preferredBrand: _preferredBrand,
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

class _MeasureSection extends StatefulWidget {
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
  State<_MeasureSection> createState() => _MeasureSectionState();
}

class _MeasureSectionState extends State<_MeasureSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: switch (widget.phase) {
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
            onPressed: widget.onStart,
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
    final hasRange = widget.sessionLow.isNotEmpty;
    final detected = widget.currentNote.isNotEmpty;
    return Column(
      children: [
        // 녹음 중 표시 (펄스 + 현재 음)
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '녹음 중',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
              if (detected) ...[
                const Text('  •  ',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                Text(
                  widget.currentNote,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent),
                ),
              ],
            ],
          ),
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
                    widget.sessionLow.isEmpty ? '–' : widget.sessionLow,
                    style: AppTheme.mono(28, FontWeight.w900,
                        widget.sessionLow.isEmpty
                            ? AppColors.textMuted
                            : const Color(0xFF6BB5FF)),
                  ),
                  if (widget.sessionLow.isNotEmpty)
                    Text(PitchService.noteToSolfege(widget.sessionLow),
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
                    widget.sessionHigh.isEmpty ? '–' : widget.sessionHigh,
                    style: AppTheme.mono(28, FontWeight.w900,
                        widget.sessionHigh.isEmpty
                            ? AppColors.textMuted
                            : AppColors.accent),
                  ),
                  if (widget.sessionHigh.isNotEmpty)
                    Text(PitchService.noteToSolfege(widget.sessionHigh),
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
          _RangeBar(low: widget.sessionLow, high: widget.sessionHigh),
          const SizedBox(height: 6),
          Text(
            PitchService.spanLabel(
                PitchService.rangeSpan(widget.sessionLow, widget.sessionHigh)),
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
              onPressed: widget.onCancel,
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: hasRange ? widget.onStop : null,
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
    final span = PitchService.rangeSpan(widget.resultLow, widget.resultHigh);
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
            _NoteBox(note: widget.resultLow, color: const Color(0xFF6BB5FF)),
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
            _NoteBox(note: widget.resultHigh, color: AppColors.accent),
          ],
        ),
        const SizedBox(height: 14),
        _RangeBar(low: widget.resultLow, high: widget.resultHigh),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onRemeasure,
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
                onPressed: widget.onSave,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                        const SizedBox(height: 6),
                        _MiniRangeBar(low: low, high: high),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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

// ── 기록 행 미니 범위 바 ────────────────────────────────────────────────────────

class _MiniRangeBar extends StatelessWidget {
  final String low;
  final String high;
  const _MiniRangeBar({required this.low, required this.high});

  static const _vizMin = 36;
  static const _vizMax = 84;
  static const _vizSpan = _vizMax - _vizMin;

  double _frac(int midi) => ((midi - _vizMin) / _vizSpan).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final lMidi = PitchService.noteToMidi(low).clamp(_vizMin, _vizMax);
    final hMidi = PitchService.noteToMidi(high).clamp(_vizMin, _vizMax);
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 6,
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
            Positioned(
              left: _frac(lMidi) * w,
              width: max(4.0, (_frac(hMidi) - _frac(lMidi)) * w),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6BB5FF), AppColors.accent],
                  ),
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

// ── 곡 키 위치 맵 ─────────────────────────────────────────────────────────────

class _SongKeyMap extends StatefulWidget {
  final List<Song> songs;
  final String myLow;
  final String myHigh;
  final String preferredBrand;
  const _SongKeyMap({
    required this.songs,
    required this.myLow,
    required this.myHigh,
    required this.preferredBrand,
  });

  @override
  State<_SongKeyMap> createState() => _SongKeyMapState();
}

class _SongKeyMapState extends State<_SongKeyMap> {
  static const _vizMin = 36; // C2
  static const _vizMax = 84; // C6
  static const _vizSpan = _vizMax - _vizMin;
  static const _octaveLabels = ['C2', 'C3', 'C4', 'C5', 'C6'];
  static const _octaveMidi = [36, 48, 60, 72, 84];
  static const _rowH = 28.0;
  static const _nameW = 80.0;
  static const _pageSize = 6;

  bool _showAll = false;
  Song? _selected;

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
    final withKey = widget.songs.where((s) => s.origKey.isNotEmpty).toList();
    final noKey = widget.songs.where((s) => s.origKey.isEmpty).toList();

    final allData = withKey.map((s) {
      final offset = s.keyOffsetFor(widget.preferredBrand);
      final origMidi = PitchService.origKeyToMidi(s.origKey, 0);
      final midi = PitchService.origKeyToMidi(s.origKey, offset);
      final color = _dotColor(midi);
      final label =
          '${s.origKey}${offset == 0 ? '' : (offset > 0 ? '+$offset' : '$offset')}';
      return (song: s, origMidi: origMidi, midi: midi, color: color, label: label, hasOffset: offset != 0, offset: offset);
    }).toList();

    final visible = _showAll ? allData : allData.take(_pageSize).toList();
    final hiddenCount = allData.length - _pageSize;

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
          // 헤더
          Row(
            children: [
              const Text('내 곡 키 위치',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Text(Song.brandLabels[widget.preferredBrand]!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),

          if (withKey.isEmpty && noKey.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text('등록된 곡이 없어요',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ),
            ),

          if (withKey.isNotEmpty)
            LayoutBuilder(builder: (_, constraints) {
              final plotW = constraints.maxWidth - _nameW - 8;
              final lMidi = widget.myLow.isNotEmpty
                  ? PitchService.noteToMidi(widget.myLow).clamp(_vizMin, _vizMax)
                  : -1;
              final hMidi = widget.myHigh.isNotEmpty
                  ? PitchService.noteToMidi(widget.myHigh).clamp(_vizMin, _vizMax)
                  : -1;

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Y축 레이블 (곡명)
                      SizedBox(
                        width: _nameW,
                        child: Column(
                          children: [
                            // 상단 여백 (X축 상단 여백 맞춤)
                            const SizedBox(height: 8),
                            ...visible.map((d) {
                              final isSelected = _selected?.id == d.song.id;
                              return GestureDetector(
                                onTap: () => setState(() =>
                                    _selected = isSelected ? null : d.song),
                                child: SizedBox(
                                  height: _rowH,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      d.song.title,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? AppColors.accent
                                              : AppColors.textSecondary,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.normal),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 플롯 영역
                      Expanded(
                        child: Stack(
                          children: [
                            const Positioned.fill(child: SizedBox()),
                            // X축 전체 배경 및 그리드
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              height: visible.length * _rowH,
                              child: Stack(
                                children: [
                                  // 내 음역대 배경 밴드
                                  if (lMidi >= 0 && hMidi >= 0)
                                    Positioned(
                                      left: _frac(lMidi) * plotW,
                                      width: max(4.0, (_frac(hMidi) - _frac(lMidi)) * plotW),
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  // 옥타브 경계선 (C3, C4, C5)
                                  for (final m in [48, 60, 72])
                                    Positioned(
                                      left: _frac(m) * plotW - 0.5,
                                      top: 0,
                                      bottom: 0,
                                      width: 1,
                                      child: Container(color: AppColors.border),
                                    ),
                                ],
                              ),
                            ),
                            // 곡별 행
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: Column(
                                children: visible.map((d) {
                                  final origDotX = _frac(d.origMidi.clamp(_vizMin, _vizMax)) * plotW;
                                  final dotX = _frac(d.midi.clamp(_vizMin, _vizMax)) * plotW;
                                  final isSelected = _selected?.id == d.song.id;
                                  return GestureDetector(
                                    onTap: () => setState(() =>
                                        _selected = isSelected ? null : d.song),
                                    child: SizedBox(
                                      height: _rowH,
                                      child: Stack(
                                        children: [
                                          const Positioned.fill(child: SizedBox()),
                                          // 트랙 선
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            top: _rowH / 2 - 0.5,
                                            height: 1,
                                            child: Container(
                                              color: AppColors.border.withOpacity(0.5),
                                            ),
                                          ),
                                          // 원키 hollow (오프셋 있을 때)
                                          if (d.hasOffset)
                                            Positioned(
                                              left: (origDotX - 4).clamp(0.0, plotW - 8),
                                              top: _rowH / 2 - 4,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: AppColors.textMuted.withOpacity(0.4),
                                                      width: 1.5),
                                                ),
                                              ),
                                            ),
                                          // 조절키 filled
                                          Positioned(
                                            left: (dotX - 5).clamp(0.0, plotW - 10),
                                            top: _rowH / 2 - 5,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? AppColors.accent
                                                    : d.color,
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: d.color.withOpacity(0.5),
                                                      blurRadius: isSelected ? 8 : 4),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            // X축 레이블
                            Positioned(
                              top: 8 + visible.length * _rowH + 4,
                              left: 0,
                              right: 0,
                              child: Row(
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
                                              fontSize: 9, color: AppColors.textMuted)),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Stack 높이 확보 (곡 행 + X축 레이블)
                  SizedBox(height: visible.length * _rowH + 8 + 16),
                  // 더 보기 / 접기
                  if (allData.length > _pageSize)
                    GestureDetector(
                      onTap: () => setState(() => _showAll = !_showAll),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showAll ? '접기' : '더 보기 $hiddenCount개',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                            Icon(
                              _showAll ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.textMuted,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 선택된 곡 정보 패널
                  const Divider(color: AppColors.border, height: 20),
                  Builder(builder: (_) {
                    if (_selected == null) {
                      return const Center(
                        child: Text('곡을 탭하면 상세 정보를 볼 수 있어요',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      );
                    }
                    final s = _selected!;
                    final offset = s.keyOffsetFor(widget.preferredBrand);
                    final adjustedLabel =
                        '${s.origKey}${offset == 0 ? '' : (offset > 0 ? ' +$offset' : ' $offset')}';
                    final dt = DateTime.fromMillisecondsSinceEpoch(s.updatedAt);
                    final dateStr =
                        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(s.artist,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (s.origKey.isNotEmpty) ...[
                              _InfoChip(label: '원키', value: s.origKey),
                              const SizedBox(width: 8),
                              _InfoChip(
                                  label: '${Song.brandLabels[widget.preferredBrand]}키',
                                  value: adjustedLabel),
                              const SizedBox(width: 8),
                            ],
                            _InfoChip(label: '추가', value: dateStr),
                          ],
                        ),
                      ],
                    );
                  }),
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
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label  ',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
