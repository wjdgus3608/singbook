import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper();
  Map<String, int> _tags = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await _db.getAllTags();
    setState(() {
      _tags = tags;
      _loading = false;
    });
  }

  Future<void> _addTag() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('새 태그', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: '태그 이름',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border2)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent)),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('추가', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && !_tags.containsKey(name)) {
      setState(() => _tags[name] = 0);
    }
  }

  Future<void> _deleteTag(String tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('태그 삭제', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"$tag" 태그를 모든 곡에서 제거할까요?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteTag(tag);
      setState(() => _tags.remove(tag));
    }
  }

  Future<void> _exportJson() async {
    final json = await _db.exportJson();
    await Share.share(json, subject: '내 노래책 백업.json');
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('전체 삭제', style: TextStyle(color: AppColors.danger)),
        content: const Text(
          '저장된 모든 곡이 삭제됩니다.\n이 작업은 되돌릴 수 없어요.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('전체 삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteAll();
      setState(() => _tags = {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전체 삭제 완료'),
            backgroundColor: AppColors.surface2,
          ),
        );
      }
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
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('설정',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tag section
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text('태그 관리',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ),
                          _Card(children: [
                            ..._tags.entries.map((e) => _TagRow(
                                  tag: e.key,
                                  count: e.value,
                                  onDelete: () => _deleteTag(e.key),
                                )),
                            _AddTagRow(onTap: _addTag),
                          ]),
                          // Data section
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                            child: Text('데이터',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ),
                          _Card(children: [
                            _ActionRow(
                              leading: const Icon(Icons.download_outlined,
                                  color: AppColors.textSecondary, size: 22),
                              label: '데이터 내보내기',
                              trailing: const Text('JSON',
                                  style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                              onTap: _exportJson,
                            ),
                            _ActionRow(
                              leading: const Icon(Icons.delete_forever_outlined,
                                  color: AppColors.danger, size: 22),
                              label: '전체 삭제',
                              labelColor: AppColors.danger,
                              onTap: _deleteAll,
                            ),
                          ]),
                          const SizedBox(height: 32),
                          // Version
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('앱 버전',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted)),
                                Text('1.0.0',
                                    style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 13,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
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

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _TagRow extends StatelessWidget {
  final String tag;
  final int count;
  final VoidCallback onDelete;
  const _TagRow({required this.tag, required this.count, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1C1C25)))),
      child: Row(
        children: [
          Expanded(
            child: Text(tag,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
          ),
          Text('$count곡',
              style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: AppColors.textMuted)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}

class _AddTagRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTagRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        height: 52,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.add, color: AppColors.accentLight, size: 20),
              SizedBox(width: 8),
              Text('새 태그',
                  style: TextStyle(fontSize: 15, color: AppColors.accentLight)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Widget leading;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionRow({
    required this.leading,
    required this.label,
    this.labelColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1C1C25)))),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      color: labelColor ?? AppColors.textPrimary)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
