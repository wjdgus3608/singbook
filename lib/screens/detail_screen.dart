import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/key_stepper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailScreen extends StatefulWidget {
  final Song song;
  const DetailScreen({super.key, required this.song});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _db = DatabaseHelper();
  late int _keyOffset;
  late List<String> _tags;
  late TextEditingController _memoCtrl;
  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _keyOffset = widget.song.keyOffset;
    _tags = List.from(widget.song.tags);
    _memoCtrl = TextEditingController(text: widget.song.memo);
    _loadAvailableTags();
  }

  Future<void> _loadAvailableTags() async {
    final tags = await _db.getAllTags();
    if (mounted) setState(() => _availableTags = tags.keys.toList());
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  String get _origNote {
    // Spotify key field (0-11) would go here; using stored or default
    return 'F#';
  }

  Future<void> _save() async {
    final updated = widget.song.copyWith(
      keyOffset: _keyOffset,
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
            // Header
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
                          Text('원키 $_origNote 장조',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    // Key stepper
                    KeyStepper(
                      keyOffset: _keyOffset,
                      origNote: _origNote,
                      onChanged: (v) => setState(() => _keyOffset = v),
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
                            children: [
                              ..._availableTags.map((tag) {
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
                                          : Border.all(
                                              color: AppColors.border2),
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
                              }),
                            ],
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
            // Save button
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
