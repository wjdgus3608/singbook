import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/song_card.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _db = DatabaseHelper();
  List<Song> _songs = [];
  List<Song> _filtered = [];
  String _searchQuery = '';
  String? _activeTag;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await _db.getAll();
    setState(() {
      _songs = songs;
      _applyFilter();
    });
  }

  void _applyFilter() {
    var list = _songs;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q))
          .toList();
    }
    if (_activeTag != null) {
      list = list.where((s) => s.tags.contains(_activeTag)).toList();
    }
    _filtered = list;
  }

  Set<String> get _allTags {
    final tags = <String>{};
    for (final s in _songs) {
      tags.addAll(s.tags);
    }
    return tags;
  }

  void _openDetail(Song song) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(song: song)),
    );
    _load();
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
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('내 노래책',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: AppColors.textMuted),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                      _load();
                    },
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '내 목록 검색',
                    hintStyle:
                        TextStyle(fontSize: 14, color: AppColors.textMuted),
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v;
                      _applyFilter();
                    });
                  },
                ),
              ),
            ),
            // Tag chips
            if (_allTags.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    _TagChip(
                      label: '전체',
                      active: _activeTag == null,
                      onTap: () => setState(() {
                        _activeTag = null;
                        _applyFilter();
                      }),
                    ),
                    ..._allTags.map((tag) => _TagChip(
                          label: '#$tag',
                          active: _activeTag == tag,
                          onTap: () => setState(() {
                            _activeTag = _activeTag == tag ? null : tag;
                            _applyFilter();
                          }),
                        )),
                  ],
                ),
              ),
            // Song list
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        _songs.isEmpty ? '검색으로 곡을 추가해보세요' : '검색 결과 없음',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => SongCard(
                        song: _filtered[i],
                        onTap: () => _openDetail(_filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TagChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withOpacity(0.16)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: active
              ? null
              : Border.all(color: AppColors.border2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: active ? AppColors.accentLight : AppColors.textDim)),
      ),
    );
  }
}
