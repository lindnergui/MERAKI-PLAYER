import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:meraki/src/ui/controllers/player_controller.dart';
import 'package:meraki/src/ui/meraki_theme.dart';
import 'package:meraki/src/ui/widgets/audio_waveform.dart';
import 'package:meraki/src/ui/widgets/cover_art_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({
    required this.controller,
    this.embedded = false,
    super.key,
  });

  final PlayerController controller;
  final bool embedded;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _dragPositionMilliseconds;

  @override
  Widget build(BuildContext context) {
    final body = ValueListenableBuilder<MediaItem?>(
      valueListenable: widget.controller.currentItem,
      builder: (context, item, _) {
        if (item == null) return const _EmptyNowPlaying();
        return ValueListenableBuilder<PlaybackState>(
          valueListenable: widget.controller.playbackState,
          builder: (context, playbackState, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: widget.controller.position,
              builder: (context, position, _) {
                return _NowPlayingBody(
                  item: item,
                  state: playbackState,
                  position: position,
                  controller: widget.controller,
                  dragPositionMilliseconds: _dragPositionMilliseconds,
                  onDragChanged: (value) {
                    setState(() => _dragPositionMilliseconds = value);
                  },
                  onDragEnded: (value) {
                    setState(() => _dragPositionMilliseconds = null);
                    unawaited(
                      widget.controller.seek(
                        Duration(milliseconds: value.round()),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Tocando agora')),
      body: body,
    );
  }
}

class _NowPlayingBody extends StatelessWidget {
  const _NowPlayingBody({
    required this.item,
    required this.state,
    required this.position,
    required this.controller,
    required this.dragPositionMilliseconds,
    required this.onDragChanged,
    required this.onDragEnded,
  });

  final MediaItem item;
  final PlaybackState state;
  final Duration position;
  final PlayerController controller;
  final double? dragPositionMilliseconds;
  final ValueChanged<double> onDragChanged;
  final ValueChanged<double> onDragEnded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final artwork = _Artwork(item: item, desktop: isDesktop);
        final controls = _PlaybackControls(
          item: item,
          state: state,
          position: position,
          controller: controller,
          dragPositionMilliseconds: dragPositionMilliseconds,
          onDragChanged: onDragChanged,
          onDragEnded: onDragEnded,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                MerakiColors.playerGradientTop,
                MerakiColors.deepPurple,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 40 : 24),
                  child: isDesktop
                      ? Row(
                          children: <Widget>[
                            Expanded(child: artwork),
                            const SizedBox(width: 64),
                            Expanded(child: controls),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              artwork,
                              const SizedBox(height: 30),
                              controls,
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.item, required this.desktop});

  final MediaItem item;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: desktop ? 470 : 520),
        child: AspectRatio(
          aspectRatio: 1,
          child: Hero(
            tag: 'cover-art-${item.id}',
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 48,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: CoverArtImage(
                coverArtUrlOrPath: item.artUri?.toString(),
                cacheWidth: 1200,
                cacheHeight: 1200,
                borderRadius: const BorderRadius.all(Radius.circular(30)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.item,
    required this.state,
    required this.position,
    required this.controller,
    required this.dragPositionMilliseconds,
    required this.onDragChanged,
    required this.onDragEnded,
  });

  final MediaItem item;
  final PlaybackState state;
  final Duration position;
  final PlayerController controller;
  final double? dragPositionMilliseconds;
  final ValueChanged<double> onDragChanged;
  final ValueChanged<double> onDragEnded;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final duration = item.duration ?? Duration.zero;
    final maximum = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final displayedPosition =
        dragPositionMilliseconds ??
        position.inMilliseconds.toDouble().clamp(0.0, maximum);
    final waveformProgress = duration == Duration.zero
        ? 0.0
        : (displayedPosition / maximum).clamp(0.0, 1.0);
    final source = item.extras?['source'] as String?;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.artist ?? 'Artista desconhecido',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: MerakiColors.softText),
        ),
        if (item.album != null && item.album!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            item.album!,
            style: const TextStyle(color: MerakiColors.softText),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: _SourceTag(source: source),
        ),
        const SizedBox(height: 26),
        AudioWaveform(progress: waveformProgress, color: accent),
        Slider(
          value: displayedPosition,
          max: maximum,
          onChanged: duration == Duration.zero ? null : onDragChanged,
          onChangeEnd: duration == Duration.zero ? null : onDragEnded,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              _formatDuration(
                Duration(milliseconds: displayedPosition.round()),
              ),
            ),
            Text(_formatDuration(duration)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _ControlButton(
              tooltip: 'Aleatório',
              icon: PhosphorIconsRegular.shuffle,
              active: controller.isShuffleEnabled,
              onPressed: controller.toggleShuffle,
            ),
            _ControlButton(
              tooltip: 'Anterior',
              icon: PhosphorIconsRegular.skipBack,
              large: true,
              onPressed: controller.skipPrevious,
            ),
            Material(
              color: accent,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: state.playing ? 'Pausar' : 'Tocar',
                onPressed: () => unawaited(controller.togglePlayPause()),
                color: MerakiColors.deepPurple,
                iconSize: 42,
                padding: const EdgeInsets.all(18),
                icon: Icon(
                  state.playing
                      ? PhosphorIconsFill.pause
                      : PhosphorIconsFill.play,
                ),
              ),
            ),
            _ControlButton(
              tooltip: 'Próxima',
              icon: PhosphorIconsRegular.skipForward,
              large: true,
              onPressed: controller.skipNext,
            ),
            _ControlButton(
              tooltip: 'Repetir',
              icon: state.repeatMode == AudioServiceRepeatMode.one
                  ? PhosphorIconsRegular.repeatOnce
                  : PhosphorIconsRegular.repeat,
              active: state.repeatMode != AudioServiceRepeatMode.none,
              onPressed: controller.cycleRepeatMode,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours == 0) return '$minutes:$seconds';
    return '${duration.inHours}:$minutes:$seconds';
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.large = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool active;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => unawaited(onPressed()),
      color: active ? Theme.of(context).colorScheme.primary : Colors.white,
      iconSize: large ? 35 : 24,
      icon: Icon(icon),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    final isRemote = source == 'subsonic' || source == 'jellyfin';
    final label = source == 'jellyfin' ? 'Jellyfin' : source == 'subsonic' ? 'Subsonic' : 'Local';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isRemote
                  ? PhosphorIconsRegular.cloud
                  : PhosphorIconsRegular.folder,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNowPlaying extends StatelessWidget {
  const _EmptyNowPlaying();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Escolha uma música na biblioteca para começar a tocar.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
