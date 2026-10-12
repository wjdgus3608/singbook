import 'dart:async';
import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../services/pitch_service.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailScreen extends StatefulWidget {
  final Song song;
  const DetailScreen({super.key, required this.song});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _db = DatabaseHelper();
  late Map<String, int> _keyOffsets;
  late String _origKey;
  late String _lowNote;
  late String _highNote;
  late List<String> _tags;
  late TextEditingController _memoCtrl;
  List<String> _availableTags = [];

  static const _noteNames = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];

  @override
  void initState() {
    super.initState();
    _keyOffsets = Map.from(widget.song.keyOffsets);
    _origKey = widget.song.origKey;
    _lowNote = widget.song.lowNote;
    _highNote = widget.song.highNote;
    _tags = List.from(widget.song.tags);
    _memoCtrl = TextEditingController(text: widget.song.memo);
    _loadAvailableTags();
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTags() async {
    final tags = await _db.getAllTags();
    if (mounted) setState(() => _availableTags = tags.keys.toList());
  }

  Future<void> _pickOrigKey() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('원키 선택',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _NoteChip(
                    label: '미설정',
                    selected: _origKey.isEmpty,
                    onTap: () => Navigator.pop(context, '')),
                ..._noteNames.map((n) => _NoteChip(
                      label: n,
                      selected: _origKey == n,
                      onTap: () => Navigator.pop(context, n),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _origKey = picked);
  }

  Future<void> _save() async {
    final updated = widget.song.copyWith(
      keyOffsets: _keyOffsets,
      origKey: _origKey,
      lowNote: _lowNote,
      highNote: _highNote,
      memo: _memoCtrl.text,
      tags: _tags,
    );
    await _db.upsert(updated);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('삭제', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('${widget.song.title}을 삭제할까요?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await _db.delete(widget.song.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _delete,
                    child: const Text('삭제',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: widget.song.albumArt.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                        imageUrl: widget.song.albumArt,
                                        fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.music_note,
                                    color: AppColors.textMuted, size: 48),
                          ),
                          const SizedBox(height: 14),
                          Text(widget.song.title,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(widget.song.artist,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickOrigKey,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _origKey.isEmpty
                                      ? '원키 선택'
                                      : '원키 $_origKey 장조',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_outlined,
                                    size: 12, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Per-brand key rows
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('내 키',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            ...Song.brands.map((brand) => _BrandRow(
                                  label: Song.brandLabels[brand]!,
                                  value: _keyOffsets[brand] ?? 0,
                                  onChanged: (v) =>
                                      setState(() => _keyOffsets[brand] = v),
                                )),
                          ],
                        ),
                      ),
                    ),
                    // Song range
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _SongRangeSection(
                        lowNote: _lowNote,
                        highNote: _highNote,
                        onMeasured: (low, high) =>
                            setState(() {
                              _lowNote = low;
                              _highNote = high;
                            }),
                      ),
                    ),
                    // Tags
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('태그',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableTags.map((tag) {
                              final on = _tags.contains(tag);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  on ? _tags.remove(tag) : _tags.add(tag);
                                }),
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: on
                                        ? AppColors.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: on
                                        ? null
                                        : Border.all(color: AppColors.border2),
                                  ),
                                  child: Center(
                                    child: Text(tag,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: on
                                                ? FontWeight.w700
                                                : FontWeight.normal,
                                            color: on
                                                ? AppColors.bg
                                                : AppColors.textDim)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    // Memo
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('메모',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _memoCtrl,
                              maxLines: 3,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.textDim),
                              decoration: const InputDecoration(
                                hintText: '기억해둘 내용을 입력하세요...',
                                hintStyle: TextStyle(
                                    color: Color(0xFF3A3A46), fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('저장',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _BrandRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final active = value != 0;
    final valueStr = value > 0 ? '+$value' : '$value';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
          const Spacer(),
          _Btn(
            icon: Icons.remove,
            enabled: value > -7,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 64,
            child: Center(
              child: Text(valueStr,
                  style: AppTheme.mono(
                      24,
                      FontWeight.w800,
                      active ? AppColors.accent : AppColors.textMuted)),
            ),
          ),
          _Btn(
            icon: Icons.add,
            enabled: value < 7,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? const Color(0xFF1F1F28)
              : const Color(0xFF1F1F28).withOpacity(0.4),
        ),
        child: Icon(icon,
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            size: 22),
      ),
    );
  }
}

class _NoteChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NoteChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.bg : AppColors.textPrimary)),
        ),
      ),
    );
  }
}

// ── 곡 음역대 섹션 ────────────────────────────────────────────────────────────

class _SongRangeSection extends StatefulWidget {
  final String lowNote;
  final String highNote;
  final void Function(String low, String high) onMeasured;
  const _SongRangeSection({
    required this.lowNote,
    required this.highNote,
    required this.onMeasured,
  });

  @override
  State<_SongRangeSection> createState() => _SongRangeSectionState();
}

class _SongRangeSectionState extends State<_SongRangeSection>
    with WidgetsBindingObserver {
  final _pitch = PitchService();
  bool _measuring = false;
  String _currentNote = '';
  String _sessionLow = '';
  String _sessionHigh = '';
  StreamSubscription<double?>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _measuring) {
      _stop(save: false);
    }
  }

  Future<void> _start() async {
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
            midi < PitchService.noteToMidi(_sessionLow)) _sessionLow = note;
        if (_sessionHigh.isEmpty ||
            midi > PitchService.noteToMidi(_sessionHigh)) _sessionHigh = note;
      });
    });
  }

  Future<void> _stop({bool save = true}) async {
    await _sub?.cancel();
    _sub = null;
    await _pitch.stop();
    if (save && _sessionLow.isNotEmpty && _sessionHigh.isNotEmpty) {
      widget.onMeasured(_sessionLow, _sessionHigh);
    }
    if (mounted) setState(() => _measuring = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _pitch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRange =
        widget.lowNote.isNotEmpty && widget.highNote.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('곡 음역대',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              if (hasRange && !_measuring)
                Text('${widget.lowNote} ~ ${widget.highNote}',
                    style: AppTheme.mono(
                        13, FontWeight.w600, AppColors.accent)),
            ],
          ),
          const SizedBox(height: 12),
          if (_measuring) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withOpacity(0.12),
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _currentNote.isEmpty ? '–' : _currentNote,
                      style: AppTheme.mono(
                          24, FontWeight.w900, AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sessionLow.isEmpty ? '–' : _sessionLow,
                      style: AppTheme.mono(
                          14,
                          FontWeight.w600,
                          const Color(0xFF6BB5FF)),
                    ),
                    const Text('최저음',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Text(
                      _sessionHigh.isEmpty ? '–' : _sessionHigh,
                      style: AppTheme.mono(
                          14, FontWeight.w600, AppColors.accent),
                    ),
                    const Text('최고음',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _stop(save: false),
                  child: const Text('취소',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_sessionLow.isNotEmpty)
                      ? () => _stop(save: true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    disabledBackgroundColor: AppColors.surface2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text('완료',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.mic_outlined, size: 16),
                label: Text(hasRange ? '다시 측정' : '이 곡 음역대 측정'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
