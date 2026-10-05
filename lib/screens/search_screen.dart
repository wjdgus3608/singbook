import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../services/music_search_service.dart';
import '../theme/app_theme.dart';
import 'detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = DatabaseHelper();
  final _spotify = MusicSearchService();
  final _ctrl = TextEditingController();
  List<Song> _results = [];
  Set<String> _savedIds = {};
  bool _hasQuery = false;
  bool _searching = false;
  String? _error;

  static const _recent = ['아이유', 'aespa', '윤하', 'BTS'];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final songs = await _db.getAll();
    if (mounted) setState(() => _savedIds = songs.map((s) => s.id).toSet());
  }

  Future<void> _onSearch(String q) async {
    setState(() {
      _hasQuery = q.isNotEmpty;
      _error = null;
    });
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _spotify.search(q);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = '검색 실패: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addSong(Song song) async {
    await _db.upsert(song);
    setState(() => _savedIds.add(song.id));
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(song: song)),
      );
      _loadSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _hasQuery
                          ? AppColors.accent
                          : Colors.transparent),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: false,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '곡명 또는 아티스트',
                    hintStyle: const TextStyle(
                        fontSize: 15, color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.search,
                        color: _hasQuery
                            ? AppColors.accent
                            : AppColors.textMuted,
                        size: 20),
                    suffixIcon: _hasQuery
                        ? IconButton(
                            icon: const Icon(Icons.cancel,
                                color: AppColors.textMuted, size: 20),
                            onPressed: () {
                              _ctrl.clear();
                              _onSearch('');
                            })
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onSearch,
                ),
              ),
            ),
            if (!_hasQuery) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('최근 검색',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(
                  spacing: 8,
                  children: _recent
                      .map((r) => GestureDetector(
                            onTap: () {
                              _ctrl.text = r;
                              _onSearch(r);
                            },
                            child: Container(
                              height: 30,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Center(
                                child: Text(r,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textDim)),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
            ],
            Expanded(
              child: _searching
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent))
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 14)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final s = _results[i];
                            final saved = _savedIds.contains(s.id);
                            return _ResultCard(
                              song: s,
                              saved: saved,
                              onAdd: saved ? null : () => _addSong(s),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Song song;
  final bool saved;
  final VoidCallback? onAdd;
  const _ResultCard(
      {required this.song, required this.saved, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: song.albumArt.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                        imageUrl: song.albumArt, fit: BoxFit.cover),
                  )
                : const Icon(Icons.music_note,
                    color: AppColors.textMuted, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(song.artist,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          saved
              ? Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check, color: AppColors.textMuted, size: 16),
                      SizedBox(width: 2),
                      Text('저장됨',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: AppColors.bg, size: 16),
                        SizedBox(width: 2),
                        Text('추가',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.bg)),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
