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
            _KeyOffsets(song: song),
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

class _KeyOffsets extends StatelessWidget {
  final Song song;
  const _KeyOffsets({required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: Song.brands.map((brand) {
        final offset = song.keyOffsetFor(brand);
        final label = Song.brandLabels[brand]!;
        final offsetStr = offset > 0 ? '+$offset' : '$offset';
        final active = offset != 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(width: 5),
              SizedBox(
                width: 28,
                child: Text(offsetStr,
                    textAlign: TextAlign.right,
                    style: AppTheme.mono(
                        12,
                        FontWeight.w700,
                        active
                            ? AppColors.accent
                            : AppColors.textMuted)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
