import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';

class SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const SongCard({super.key, required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            _AlbumArt(url: song.albumArt),
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
                  if (song.tags.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(song.tags.map((t) => '#$t').join(' '),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.accentLight)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _KeyBadge(keyOffset: song.keyOffset),
          ],
        ),
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String url;
  const _AlbumArt({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
        image: url.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(url), fit: BoxFit.cover)
            : null,
      ),
      child: url.isEmpty
          ? const Icon(Icons.music_note, color: AppColors.textMuted, size: 24)
          : null,
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final int keyOffset;
  const _KeyBadge({required this.keyOffset});

  @override
  Widget build(BuildContext context) {
    final hasKey = keyOffset != 0;
    final label = keyOffset > 0 ? '+$keyOffset' : '$keyOffset';
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: hasKey
            ? AppColors.accent.withOpacity(0.14)
            : const Color(0xFF1A1A22),
        border: hasKey
            ? Border.all(color: AppColors.accent.withOpacity(0.4))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: AppTheme.mono(
                  19,
                  FontWeight.w800,
                  hasKey ? AppColors.accent : AppColors.textMuted)),
          const SizedBox(height: 3),
          Text(hasKey ? _calcNote() : '원키',
              style: AppTheme.mono(
                  10,
                  FontWeight.normal,
                  hasKey ? AppColors.accentLight : AppColors.textMuted)),
        ],
      ),
    );
  }

  String _calcNote() {
    const notes = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
    return notes[((keyOffset % 12) + 12) % 12];
  }
}
