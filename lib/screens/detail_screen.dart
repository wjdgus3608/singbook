import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
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
  late List<String> _tags;
  late TextEditingController _memoCtrl;
  List<String> _availableTags = [];
  String _selectedBrand = 'tj';

  static const _noteNames = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];

  String _transposedKeyLabel(int offset) {
    if (_origKey.isEmpty) return '';
    final idx = _noteNames.indexOf(_origKey);
    if (idx < 0) return '';
    final newIdx = ((idx + offset) % 12 + 12) % 12;
    return '${_noteNames[newIdx]} 장조';
  }

  @override
  void initState() {
    super.initState();
    _keyOffsets = Map.from(widget.song.keyOffsets);
    _origKey = widget.song.origKey;
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
                    // Key panel
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: "내 키" + brand tabs
                            Row(
                              children: [
                                const Text('내 키',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                                const Spacer(),
                                ...Song.brands.map((b) {
                                  final selected = _selectedBrand == b;
                                  final hasValue = (_keyOffsets[b] ?? 0) != 0;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedBrand = b),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.accent
                                            : AppColors.surface2,
                                        borderRadius: BorderRadius.circular(8),
                                        border: hasValue && !selected
                                            ? Border.all(
                                                color: AppColors.accent.withOpacity(0.4))
                                            : null,
                                      ),
                                      child: Text(Song.brandLabels[b]!,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: selected
                                                  ? AppColors.bg
                                                  : hasValue
                                                      ? AppColors.accentLight
                                                      : AppColors.textMuted)),
                                    ),
                                  );
                                }),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Stepper
                            Builder(builder: (_) {
                              final val = _keyOffsets[_selectedBrand] ?? 0;
                              final isZero = val == 0;
                              final valStr = val > 0 ? '+$val' : '$val';
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Minus button
                                  GestureDetector(
                                    onTap: val > -7
                                        ? () => setState(
                                            () => _keyOffsets[_selectedBrand] = val - 1)
                                        : null,
                                    child: Container(
                                      width: 52, height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: val > -7
                                            ? AppColors.surface3
                                            : AppColors.surface3.withOpacity(0.4),
                                      ),
                                      child: Icon(Icons.remove,
                                          color: val > -7
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                          size: 28),
                                    ),
                                  ),
                                  // Center: offset number + transposed key
                                  Column(
                                    children: [
                                      Text(valStr,
                                          style: AppTheme.mono(
                                              52, FontWeight.w800,
                                              isZero
                                                  ? AppColors.textMuted
                                                  : AppColors.accent)
                                              .copyWith(
                                            shadows: isZero
                                                ? null
                                                : [
                                                    Shadow(
                                                      color: AppColors.accent
                                                          .withOpacity(0.5),
                                                      blurRadius: 24,
                                                      offset: Offset.zero,
                                                    ),
                                                  ],
                                          )),
                                      if (_origKey.isNotEmpty)
                                        Text(
                                          isZero
                                              ? '원키'
                                              : _transposedKeyLabel(val),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary),
                                        ),
                                    ],
                                  ),
                                  // Plus button
                                  GestureDetector(
                                    onTap: val < 7
                                        ? () => setState(
                                            () => _keyOffsets[_selectedBrand] = val + 1)
                                        : null,
                                    child: Container(
                                      width: 52, height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: val < 7
                                            ? AppColors.surface3
                                            : AppColors.surface3.withOpacity(0.4),
                                      ),
                                      child: Icon(Icons.add,
                                          color: val < 7
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                          size: 28),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            const SizedBox(height: 16),
                            // Slider
                            _KeySlider(
                              value: _keyOffsets[_selectedBrand] ?? 0,
                              onChanged: (v) =>
                                  setState(() => _keyOffsets[_selectedBrand] = v),
                            ),
                            const SizedBox(height: 6),
                            // Tick labels
                            Row(
                              children: [
                                Text('-7',
                                    style: AppTheme.mono(
                                        11, FontWeight.normal, AppColors.textLabel)),
                                const Spacer(),
                                Text('0',
                                    style: AppTheme.mono(
                                        11, FontWeight.normal, AppColors.textLabel)),
                                const Spacer(),
                                Text('+7',
                                    style: AppTheme.mono(
                                        11, FontWeight.normal, AppColors.textLabel)),
                              ],
                            ),
                          ],
                        ),
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

class _KeySlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _KeySlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      const pad = 13.0;
      final w = constraints.maxWidth - pad * 2;
      final step = w / 14.0;
      final thumbCx = (value + 7) * step + pad;
      final zeroCx = 7 * step + pad;

      void _updateValue(double dx) {
        final pos = (dx - pad).clamp(0.0, w);
        final v = ((pos / w * 14) - 7).round().clamp(-7, 7);
        onChanged(v);
      }

      return GestureDetector(
        onHorizontalDragUpdate: (d) => _updateValue(d.localPosition.dx),
        onTapUp: (d) => _updateValue(d.localPosition.dx),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track background
              Positioned(
                left: pad, right: pad, top: 12, height: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF24242E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Accent fill from 0 to current
              if (value != 0)
                Positioned(
                  left: value > 0 ? zeroCx : thumbCx,
                  width: (thumbCx - zeroCx).abs(),
                  top: 12, height: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Zero position marker
              Positioned(
                left: zeroCx - 1,
                top: 6, width: 2, height: 16,
                child: Container(color: AppColors.textLabel),
              ),
              // Thumb (18px white circle + 4px accent ring = 26px total)
              Positioned(
                left: thumbCx - 13,
                top: 1,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textPrimary,
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.35),
                      width: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
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

