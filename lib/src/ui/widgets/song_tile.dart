import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meraki/src/rust/models/song.dart';
import 'package:meraki/src/ui/meraki_theme.dart';
import 'package:meraki/src/ui/widgets/cover_art_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

enum _SongMenuAction { play }

class SongTile extends StatefulWidget {
  const SongTile({required this.song, required this.onPlay, super.key});

  final Song song;
  final Future<void> Function() onPlay;

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: _hovered ? accent.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
          leading: CoverArtImage(
            coverArtUrlOrPath: widget.song.coverArtUrlOrPath,
            width: 48,
            height: 48,
            cacheWidth: 144,
            cacheHeight: 144,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          title: Text(
            widget.song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: MerakiColors.softText),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SourcePill(source: widget.song.source),
              const SizedBox(width: 8),
              Text(
                _formatDuration(widget.song.durationSeconds),
                style: const TextStyle(
                  fontSize: 12,
                  color: MerakiColors.softText,
                ),
              ),
              PopupMenuButton<_SongMenuAction>(
                tooltip: 'Opções da música',
                icon: Icon(PhosphorIconsRegular.dotsThreeVertical, size: 20),
                onSelected: (action) {
                  if (action == _SongMenuAction.play) {
                    unawaited(widget.onPlay());
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<_SongMenuAction>>[
                  PopupMenuItem<_SongMenuAction>(
                    value: _SongMenuAction.play,
                    child: Row(
                      children: <Widget>[
                        Icon(PhosphorIconsRegular.play),
                        const SizedBox(width: 10),
                        const Text('Tocar agora'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () => unawaited(widget.onPlay()),
        ),
      ),
    );
  }

  String get _subtitle {
    final artist = widget.song.artist?.trim();
    final album = widget.song.album?.trim();
    final parts = <String>[
      if (artist != null && artist.isNotEmpty) artist,
      if (album != null && album.isNotEmpty) album,
    ];
    return parts.isEmpty ? 'Artista desconhecido' : parts.join(' • ');
  }

  static String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds <= 0) return '--:--';
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours == 0) return '$minutes:$seconds';
    return '${duration.inHours}:$minutes:$seconds';
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.source});

  final SongSource source;

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      SongSource.local => 'Local',
      SongSource.subsonic => 'Subsonic',
      SongSource.jellyfin => 'Jellyfin',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
