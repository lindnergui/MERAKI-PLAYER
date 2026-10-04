part of 'home_screen.dart';

// Desktop (>= 600 dp) interface inspired by a pixel-art turntable layout:
// slim icon rail on the left, the playing record on the home's left column
// and "Próximas músicas" + Meraki Spotlight on the right.

const Set<_HomeDestination> _musicDestinations = <_HomeDestination>{
  _HomeDestination.allSongs,
  _HomeDestination.albums,
  _HomeDestination.artists,
  _HomeDestination.downloads,
};

_HomeDestination _railGroupOf(_HomeDestination destination) {
  return _musicDestinations.contains(destination)
      ? _HomeDestination.allSongs
      : destination;
}

String _formatDeckDuration(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours == 0) return '${duration.inMinutes}:$seconds';
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${duration.inHours}:$minutes:$seconds';
}

String _sourceLabelFor(String? source) {
  return switch (source) {
    'jellyfin' => 'Jellyfin',
    'subsonic' => 'Subsonic',
    _ => 'Local',
  };
}

String _songSourceLabel(SongSource source) {
  return switch (source) {
    SongSource.local => 'Local',
    SongSource.subsonic => 'Subsonic',
    SongSource.jellyfin => 'Jellyfin',
  };
}

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final destination = state._destination;
    final showMiniPlayer =
        destination != _HomeDestination.home &&
        destination != _HomeDestination.nowPlaying;
    return Scaffold(
      backgroundColor: MerakiColors.deepPurple,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.75, -0.95),
            radius: 1.5,
            colors: <Color>[Color(0xFF1F1130), MerakiColors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _DesktopHeader(state: state),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _DesktopRail(state: state),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey<_HomeDestination>(
                            _railGroupOf(destination),
                          ),
                          child: _DesktopPage(state: state),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showMiniPlayer)
                MiniPlayer(
                  controller: state.widget.playerController,
                  onOpenNowPlaying: () =>
                      state.setDestination(_HomeDestination.nowPlaying),
                  desktop: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 28, 14),
      child: Row(
        children: <Widget>[
          const _PixelWordmark(),
          const SizedBox(width: 36),
          Flexible(
            flex: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _PixelSearchField(state: state),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Configurações',
            onPressed: state.openSettings,
            color: MerakiColors.softText,
            icon: Icon(PhosphorIconsRegular.gear, size: 22),
          ),
          const SizedBox(width: 12),
          _ProfileMenu(state: state),
        ],
      ),
    );
  }
}

class _PixelWordmark extends StatelessWidget {
  const _PixelWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/images/meraki_mark.png',
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'MERAKI',
          style: merakiPixelStyle(
            26,
            weight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

class _PixelSearchField extends StatefulWidget {
  const _PixelSearchField({required this.state});

  final _HomeScreenState state;

  @override
  State<_PixelSearchField> createState() => _PixelSearchFieldState();
}

class _PixelSearchFieldState extends State<_PixelSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state._searchQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final state = widget.state;
    state.setSearchQuery(value);
    // Search results live in "Todas as Músicas".
    if (value.trim().isNotEmpty &&
        !_musicDestinations.contains(state._destination)) {
      state.setDestination(_HomeDestination.allSongs);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(99),
      borderSide: BorderSide(
        color: MerakiColors.softText.withValues(alpha: 0.55),
        width: 1.4,
      ),
    );
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        cursorColor: accent,
        style: merakiPixelStyle(15),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: MerakiColors.panel.withValues(alpha: 0.55),
          hintText: 'Pesquisar por música, álbum ou artista',
          hintStyle: merakiPixelStyle(14, color: MerakiColors.softText),
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 18,
            color: MerakiColors.softText,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar pesquisa',
                  iconSize: 16,
                  color: MerakiColors.softText,
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                  icon: Icon(PhosphorIconsRegular.x),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: accent, width: 1.6),
          ),
        ),
      ),
    );
  }
}

enum _ProfileAction { settings, logout }

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.state});

  final _HomeScreenState state;

  String get _initials {
    final parts = state.widget.userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<_ProfileAction>(
      tooltip: 'Perfil',
      color: MerakiColors.panel,
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MerakiColors.divider),
      ),
      onSelected: (action) {
        if (action == _ProfileAction.settings) {
          state.openSettings();
        } else {
          unawaited(state.logout());
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_ProfileAction>>[
        PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.settings,
          child: Row(
            children: <Widget>[
              Icon(PhosphorIconsRegular.gear, size: 18),
              const SizedBox(width: 10),
              Text('Configurações', style: merakiPixelStyle(15)),
            ],
          ),
        ),
        PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.logout,
          child: Row(
            children: <Widget>[
              Icon(PhosphorIconsRegular.signOut, size: 18, color: accent),
              const SizedBox(width: 10),
              Text('Sair', style: merakiPixelStyle(15, color: accent)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[accent, MerakiColors.playerGradientTop],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                _initials,
                style: merakiPixelStyle(15, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                state.widget.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: merakiPixelStyle(15, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretDown,
              size: 14,
              color: MerakiColors.softText,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final group = _railGroupOf(state._destination);
    return SizedBox(
      width: 92,
      child: Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 22),
        child: Column(
          children: <Widget>[
            _RailButton(
              label: 'Home',
              icon: PhosphorIconsFill.house,
              selected: group == _HomeDestination.home,
              onTap: () => state.setDestination(_HomeDestination.home),
            ),
            _RailButton(
              label: 'Favoritas',
              icon: PhosphorIconsFill.heart,
              selected: group == _HomeDestination.favorites,
              onTap: () => state.setDestination(_HomeDestination.favorites),
            ),
            _RailButton(
              label: 'Todas as Músicas',
              icon: PhosphorIconsFill.musicNote,
              selected: group == _HomeDestination.allSongs,
              onTap: () {
                if (!_musicDestinations.contains(state._destination)) {
                  state.setDestination(_HomeDestination.allSongs);
                }
              },
            ),
            ValueListenableBuilder<PlaybackState>(
              valueListenable: state.widget.playerController.playbackState,
              builder: (context, playbackState, _) => _RailButton(
                label: 'Tocando agora',
                icon: PhosphorIconsFill.disc,
                selected: group == _HomeDestination.nowPlaying,
                showIndicator: playbackState.playing,
                onTap: () => state.setDestination(_HomeDestination.nowPlaying),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.showIndicator = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showIndicator;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final selected = widget.selected;
    final color = selected
        ? Colors.white
        : _hovered
        ? MerakiColors.softText
        : MerakiColors.softText.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Tooltip(
        message: widget.label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 250),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : _hovered
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.55)
                      : Colors.transparent,
                ),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: -6,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(widget.icon, size: 26, color: color),
                  if (widget.showIndicator)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.8),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPage extends StatelessWidget {
  const _DesktopPage({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state.widget.libraryController,
      builder: (context, _) {
        final library = state.widget.libraryController;
        if (library.isLoading && library.songs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return switch (state._destination) {
          _HomeDestination.home => _DesktopHomePage(state: state),
          _HomeDestination.favorites => _DesktopFavoritesPage(state: state),
          _HomeDestination.nowPlaying => _DesktopNowPlayingPage(state: state),
          _HomeDestination.allSongs ||
          _HomeDestination.albums ||
          _HomeDestination.artists ||
          _HomeDestination.downloads => _DesktopLibraryPage(state: state),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Player building blocks
// ---------------------------------------------------------------------------

class _PlayerBuilder extends StatelessWidget {
  const _PlayerBuilder({required this.controller, required this.builder});

  final PlayerController controller;
  final Widget Function(BuildContext, MediaItem?, PlaybackState) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MediaItem?>(
      valueListenable: controller.currentItem,
      builder: (context, item, _) => ValueListenableBuilder<PlaybackState>(
        valueListenable: controller.playbackState,
        builder: (context, playbackState, _) =>
            builder(context, item, playbackState),
      ),
    );
  }
}

class _DeckTurntable extends StatelessWidget {
  const _DeckTurntable({
    required this.state,
    required this.item,
    required this.playbackState,
  });

  final _HomeScreenState state;
  final MediaItem? item;
  final PlaybackState playbackState;

  @override
  Widget build(BuildContext context) {
    final controller = state.widget.playerController;
    return ValueListenableBuilder<double>(
      valueListenable: controller.volume,
      builder: (context, volume, _) => MerakiTurntable(
        coverArtUrlOrPath: item?.artUri?.toString(),
        isPlaying: item != null && playbackState.playing,
        hasTrack: item != null,
        onTogglePlay: item == null
            ? () => unawaited(state.playSpotlight())
            : () => unawaited(controller.togglePlayPause()),
        volume: volume,
        onVolumeChanged: (value) => unawaited(controller.setVolume(value)),
      ),
    );
  }
}

class _DeckTitle extends StatelessWidget {
  const _DeckTitle({
    required this.state,
    required this.item,
    required this.size,
    this.maxLines = 1,
  });

  final _HomeScreenState state;
  final MediaItem? item;
  final double size;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final song = state.songForItem(item);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            item?.title ?? 'Nada tocando',
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: merakiPixelStyle(
              size,
              weight: FontWeight.w600,
              height: 1.08,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _FavoriteButton(state: state, song: song, size: size * 0.72),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.state,
    required this.song,
    required this.size,
  });

  final _HomeScreenState state;
  final Song? song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final song = this.song;
    final isFavorite =
        song != null && state.widget.libraryController.isFavorite(song.id);
    return IconButton(
      tooltip: isFavorite ? 'Remover das favoritas' : 'Curtir',
      iconSize: size,
      onPressed: song == null
          ? null
          : () => unawaited(state.toggleFavoriteSong(song)),
      color: isFavorite ? accent : Colors.white,
      disabledColor: Colors.white.withValues(alpha: 0.2),
      icon: Icon(
        isFavorite ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: compact ? accent.withValues(alpha: 0.14) : accent,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 13,
          vertical: compact ? 3 : 4,
        ),
        child: Text(
          label,
          style: merakiPixelStyle(
            compact ? 11 : 14,
            weight: FontWeight.w600,
            color: compact ? accent : MerakiColors.deepPurple,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _DeckMeta extends StatelessWidget {
  const _DeckMeta({required this.item});

  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item == null) {
      return const Text(
        'Escolha uma música na biblioteca para começar a tocar.',
        style: TextStyle(color: MerakiColors.softText, fontSize: 14),
      );
    }
    final parts = <String>[
      item.artist?.trim().isNotEmpty == true
          ? item.artist!.trim()
          : 'Artista desconhecido',
      if (item.album?.trim().isNotEmpty == true) item.album!.trim(),
    ];
    return Row(
      children: <Widget>[
        _SourceChip(
          label: _sourceLabelFor(item.extras?['source'] as String?),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            parts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: MerakiColors.softText, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _DeckProgress extends StatelessWidget {
  const _DeckProgress({required this.controller, required this.item});

  final PlayerController controller;
  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: controller.position,
      builder: (context, position, _) {
        final duration = item?.duration ?? Duration.zero;
        final total = duration.inMilliseconds;
        final progress = total <= 0
            ? 0.0
            : (position.inMilliseconds / total).clamp(0.0, 1.0);
        return Row(
          children: <Widget>[
            SizedBox(
              width: 62,
              child: Text(
                _formatDeckDuration(item == null ? Duration.zero : position),
                style: merakiPixelStyle(18, weight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: _PixelWaveform(
                progress: progress,
                seed: item?.id.hashCode ?? 7,
                onSeek: total <= 0
                    ? null
                    : (fraction) => unawaited(
                        controller.seek(
                          Duration(milliseconds: (total * fraction).round()),
                        ),
                      ),
              ),
            ),
            SizedBox(
              width: 62,
              child: Text(
                _formatDeckDuration(duration),
                textAlign: TextAlign.right,
                style: merakiPixelStyle(18, weight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PixelWaveform extends StatefulWidget {
  const _PixelWaveform({
    required this.progress,
    required this.seed,
    required this.onSeek,
  });

  final double progress;
  final int seed;
  final ValueChanged<double>? onSeek;

  @override
  State<_PixelWaveform> createState() => _PixelWaveformState();
}

class _PixelWaveformState extends State<_PixelWaveform> {
  double? _dragProgress;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    final onSeek = widget.onSeek;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(1.0, constraints.maxWidth);
        double fractionOf(double dx) => (dx / width).clamp(0.0, 1.0);
        return MouseRegion(
          cursor: onSeek == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onSeek == null
                ? null
                : (details) => onSeek(fractionOf(details.localPosition.dx)),
            onHorizontalDragStart: onSeek == null
                ? null
                : (details) => setState(
                    () => _dragProgress = fractionOf(details.localPosition.dx),
                  ),
            onHorizontalDragUpdate: onSeek == null
                ? null
                : (details) => setState(
                    () => _dragProgress = fractionOf(details.localPosition.dx),
                  ),
            onHorizontalDragEnd: onSeek == null
                ? null
                : (_) {
                    final value = _dragProgress;
                    setState(() => _dragProgress = null);
                    if (value != null) onSeek(value);
                  },
            child: RepaintBoundary(
              child: SizedBox(
                height: 44,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PixelWavePainter(
                    progress: _dragProgress ?? widget.progress,
                    seed: widget.seed,
                    playedColor: accent,
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

/// Square-edged bars give the waveform the same pixel feel as the font.
class _PixelWavePainter extends CustomPainter {
  _PixelWavePainter({
    required this.progress,
    required this.seed,
    required this.playedColor,
  });

  final double progress;
  final int seed;
  final Color playedColor;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 3.0;
    final count = math.max(1, ((size.width + gap) / (barWidth + gap)).floor());
    final random = math.Random(seed);
    final played = Paint()..color = playedColor;
    final pending = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final offset = (size.width - (count * (barWidth + gap) - gap)) / 2;
    for (var index = 0; index < count; index++) {
      final normalized = count == 1 ? 0.0 : index / (count - 1);
      final envelope = 0.35 + 0.65 * math.sin(normalized * math.pi).abs();
      final wave = (math.sin(index * 0.55 + seed % 17) * 0.5 + 0.5);
      final amplitude =
          (0.18 + 0.82 * (wave * 0.55 + random.nextDouble() * 0.45)) *
          envelope;
      // Snap heights to 2 px steps for the pixel look.
      final barHeight = math.max(4.0, (size.height * amplitude / 2).floor() * 2.0);
      final x = offset + index * (barWidth + gap);
      canvas.drawRect(
        Rect.fromLTWH(x, (size.height - barHeight) / 2, barWidth, barHeight),
        normalized <= progress ? played : pending,
      );
    }
  }

  @override
  bool shouldRepaint(_PixelWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.seed != seed ||
        oldDelegate.playedColor != playedColor;
  }
}

class _DeckControls extends StatelessWidget {
  const _DeckControls({
    required this.state,
    required this.item,
    required this.playbackState,
    this.playSize = 72,
  });

  final _HomeScreenState state;
  final MediaItem? item;
  final PlaybackState playbackState;
  final double playSize;

  @override
  Widget build(BuildContext context) {
    final controller = state.widget.playerController;
    final enabled = item != null;
    final iconSize = playSize * 0.42;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _DeckIconButton(
          tooltip: 'Repetir',
          size: iconSize * 0.85,
          icon: playbackState.repeatMode == AudioServiceRepeatMode.one
              ? PhosphorIconsRegular.repeatOnce
              : PhosphorIconsRegular.repeat,
          active: playbackState.repeatMode != AudioServiceRepeatMode.none,
          onPressed: enabled ? controller.cycleRepeatMode : null,
        ),
        _DeckIconButton(
          tooltip: 'Anterior',
          size: iconSize,
          icon: PhosphorIconsRegular.skipBack,
          onPressed: enabled ? controller.skipPrevious : null,
        ),
        _BigPlayButton(
          size: playSize,
          playing: enabled && playbackState.playing,
          onPressed: enabled ? controller.togglePlayPause : state.playSpotlight,
        ),
        _DeckIconButton(
          tooltip: 'Próxima',
          size: iconSize,
          icon: PhosphorIconsRegular.skipForward,
          onPressed: enabled ? controller.skipNext : null,
        ),
        _DeckIconButton(
          tooltip: 'Aleatório',
          size: iconSize * 0.85,
          icon: PhosphorIconsRegular.shuffle,
          active: controller.isShuffleEnabled,
          onPressed: enabled ? controller.toggleShuffle : null,
        ),
      ],
    );
  }
}

class _DeckIconButton extends StatelessWidget {
  const _DeckIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.size,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onPressed;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    return IconButton(
      tooltip: tooltip,
      iconSize: size,
      color: active ? Theme.of(context).colorScheme.primary : Colors.white,
      disabledColor: Colors.white.withValues(alpha: 0.22),
      onPressed: onPressed == null ? null : () => unawaited(onPressed()),
      icon: Icon(icon),
    );
  }
}

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({
    required this.size,
    required this.playing,
    required this.onPressed,
  });

  final double size;
  final bool playing;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: playing ? 'Pausar' : 'Tocar',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 28,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => unawaited(onPressed()),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
                size: size * 0.42,
                color: MerakiColors.deepPurple,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class _DesktopHomePage extends StatelessWidget {
  const _DesktopHomePage({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minHeight = 600.0;
        if (constraints.maxWidth < 960) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 28, 28),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _NowPlayingDeck(state: state),
                ),
              ),
              const SizedBox(height: 36),
              _HomeDiscoverColumn(state: state, expandList: false),
            ],
          );
        }

        final height = math.max(constraints.maxHeight, minHeight);
        // Space used below the turntable: title, meta, waveform, controls.
        const deckChrome = 268.0;
        final byWidth = (constraints.maxWidth - 40) * 0.44;
        final byHeight =
            (height - 32 - deckChrome) * MerakiTurntable.aspectRatio;
        final deckWidth = math.min(byWidth, byHeight).clamp(320.0, 640.0);
        final content = SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 32, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: deckWidth, child: _NowPlayingDeck(state: state)),
                const SizedBox(width: 44),
                Expanded(
                  child: _HomeDiscoverColumn(state: state, expandList: true),
                ),
              ],
            ),
          ),
        );
        if (constraints.maxHeight >= minHeight) return content;
        return SingleChildScrollView(child: content);
      },
    );
  }
}

class _NowPlayingDeck extends StatelessWidget {
  const _NowPlayingDeck({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final controller = state.widget.playerController;
    return _PlayerBuilder(
      controller: controller,
      builder: (context, item, playbackState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DeckTurntable(
            state: state,
            item: item,
            playbackState: playbackState,
          ),
          const SizedBox(height: 24),
          _DeckTitle(state: state, item: item, size: 36),
          const SizedBox(height: 8),
          _DeckMeta(item: item),
          const SizedBox(height: 16),
          _DeckProgress(controller: controller, item: item),
          const SizedBox(height: 14),
          _DeckControls(
            state: state,
            item: item,
            playbackState: playbackState,
          ),
        ],
      ),
    );
  }
}

class _HomeDiscoverColumn extends StatelessWidget {
  const _HomeDiscoverColumn({required this.state, required this.expandList});

  final _HomeScreenState state;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final spotlight = state._spotlightSongs;
    final list = _SongRowList(
      state: state,
      songs: spotlight,
      shrinkWrap: !expandList,
      emptyMessage: 'Sua biblioteca ainda está vazia.',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(
                'Próximas\nmúsicas',
                style: merakiPixelStyle(
                  44,
                  weight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ),
            _UnderlinedLink(
              label: 'Ver todas',
              onTap: () => _showQueueDialog(context, state),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(height: 214, child: _UpNextCarousel(state: state)),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                spotlight.isEmpty
                    ? 'Meraki Spotlight'
                    : 'Meraki Spotlight (${spotlight.length})',
                style: merakiPixelStyle(26, weight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Nova seleção',
              color: MerakiColors.softText,
              onPressed: state.reshuffleSpotlight,
              icon: Icon(PhosphorIconsRegular.arrowsClockwise, size: 20),
            ),
          ],
        ),
        const Text(
          'Uma seleção que combina com o seu momento',
          style: TextStyle(color: MerakiColors.softText, fontSize: 13),
        ),
        const SizedBox(height: 10),
        if (expandList) Expanded(child: list) else list,
      ],
    );
  }
}

class _UnderlinedLink extends StatelessWidget {
  const _UnderlinedLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: merakiPixelStyle(
            17,
            weight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _UpNextCarousel extends StatelessWidget {
  const _UpNextCarousel({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final controller = state.widget.playerController;
    return ValueListenableBuilder<List<MediaItem>>(
      valueListenable: controller.upNext,
      builder: (context, upNext, _) {
        if (upNext.isNotEmpty) {
          final items = upNext.take(20).toList(growable: false);
          return _HorizontalCardList(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _MediaCard(
                coverArtUrlOrPath: item.artUri?.toString(),
                title: item.title,
                subtitle: 'por ${item.artist ?? 'Artista desconhecido'}',
                onTap: () => unawaited(controller.skipToItem(item)),
              );
            },
          );
        }

        // Empty queue: suggest a random set that starts a new queue.
        final suggestions = state._suggestedSongs.isNotEmpty
            ? state._suggestedSongs
            : state._spotlightSongs;
        if (suggestions.isEmpty) {
          return Center(
            child: Text(
              'A fila está vazia.',
              style: merakiPixelStyle(16, color: MerakiColors.softText),
            ),
          );
        }
        return _HorizontalCardList(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final song = suggestions[index];
            return _MediaCard(
              coverArtUrlOrPath: song.coverArtUrlOrPath,
              title: song.title,
              subtitle: 'por ${song.artist ?? 'Artista desconhecido'}',
              onTap: () => unawaited(state.playSong(song, suggestions)),
            );
          },
        );
      },
    );
  }
}

class _HorizontalCardList extends StatefulWidget {
  const _HorizontalCardList({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_HorizontalCardList> createState() => _HorizontalCardListState();
}

class _HorizontalCardListState extends State<_HorizontalCardList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Lets a regular (vertical) mouse wheel scroll the horizontal list.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      final delta = scroll.scrollDelta.dy != 0
          ? scroll.scrollDelta.dy
          : scroll.scrollDelta.dx;
      final position = _controller.position;
      _controller.jumpTo(
        (_controller.offset + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
          scrollbars: false,
        ),
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: widget.itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, index) =>
              SizedBox(width: 156, child: widget.itemBuilder(context, index)),
        ),
      ),
    );
  }
}

class _MediaCard extends StatefulWidget {
  const _MediaCard({
    required this.coverArtUrlOrPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.circle = false,
  });

  final String? coverArtUrlOrPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool circle;

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final radius = widget.circle
        ? BorderRadius.circular(999)
        : BorderRadius.circular(16);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedScale(
              scale: _hovered ? 1.04 : 1,
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: _hovered
                          ? accent.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.08),
                      width: 1.4,
                    ),
                    boxShadow: _hovered
                        ? <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 22,
                              spreadRadius: -6,
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CoverArtImage(
                        coverArtUrlOrPath: widget.coverArtUrlOrPath,
                        cacheWidth: 360,
                        cacheHeight: 360,
                        borderRadius: radius,
                      ),
                      AnimatedOpacity(
                        opacity: _hovered ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                PhosphorIconsFill.play,
                                size: 20,
                                color: MerakiColors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: merakiPixelStyle(15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: MerakiColors.softText,
                decoration: TextDecoration.underline,
                decorationColor: MerakiColors.softText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showQueueDialog(BuildContext context, _HomeScreenState state) {
  final controller = state.widget.playerController;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: MerakiColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: MerakiColors.divider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Próximas músicas',
                      style: merakiPixelStyle(28, weight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: Icon(PhosphorIconsRegular.x),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ValueListenableBuilder<List<MediaItem>>(
                  valueListenable: controller.upNext,
                  builder: (context, items, _) {
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'A fila está vazia. Escolha uma música para começar.',
                          style: TextStyle(color: MerakiColors.softText),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: CoverArtImage(
                            coverArtUrlOrPath: item.artUri?.toString(),
                            width: 44,
                            height: 44,
                            cacheWidth: 132,
                            cacheHeight: 132,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10),
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: merakiPixelStyle(16),
                          ),
                          subtitle: Text(
                            item.artist ?? 'Artista desconhecido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MerakiColors.softText,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            item.duration == null
                                ? '--:--'
                                : _formatDeckDuration(item.duration!),
                            style: merakiPixelStyle(
                              14,
                              color: MerakiColors.softText,
                            ),
                          ),
                          onTap: () {
                            unawaited(controller.skipToItem(item));
                            Navigator.of(dialogContext).pop();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Song rows (Spotlight, Favoritas, Todas as Músicas)
// ---------------------------------------------------------------------------

class _SongRowList extends StatelessWidget {
  const _SongRowList({
    required this.state,
    required this.songs,
    this.shrinkWrap = false,
    this.showDetails = false,
    this.indexed = false,
    this.emptyMessage = 'Nenhuma música encontrada.',
  });

  final _HomeScreenState state;
  final List<Song> songs;
  final bool shrinkWrap;
  final bool showDetails;
  final bool indexed;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          emptyMessage,
          style: merakiPixelStyle(16, color: MerakiColors.softText),
        ),
      );
    }
    final controller = state.widget.playerController;
    final library = state.widget.libraryController;
    return _PlayerBuilder(
      controller: controller,
      builder: (context, item, playbackState) => ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final isCurrent = item?.id == song.id;
          return _PixelSongRow(
            song: song,
            index: indexed ? index + 1 : null,
            showDetails: showDetails,
            isCurrent: isCurrent,
            isPlaying: isCurrent && playbackState.playing,
            isFavorite: library.isFavorite(song.id),
            onToggleFavorite: () => unawaited(state.toggleFavoriteSong(song)),
            onPlay: isCurrent
                ? controller.togglePlayPause
                : () => state.playSong(song, songs),
          );
        },
      ),
    );
  }
}

class _PixelSongRow extends StatefulWidget {
  const _PixelSongRow({
    required this.song,
    required this.onPlay,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.index,
    this.showDetails = false,
    this.isCurrent = false,
    this.isPlaying = false,
  });

  final Song song;
  final Future<void> Function() onPlay;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final int? index;
  final bool showDetails;
  final bool isCurrent;
  final bool isPlaying;

  @override
  State<_PixelSongRow> createState() => _PixelSongRowState();
}

class _PixelSongRowState extends State<_PixelSongRow> {
  var _hovered = false;

  String get _subtitle {
    final artist = widget.song.artist?.trim();
    final album = widget.song.album?.trim();
    final parts = <String>[
      if (artist != null && artist.isNotEmpty) artist else 'Artista desconhecido',
      if (widget.showDetails && album != null && album.isNotEmpty) album,
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final song = widget.song;
    final seconds = song.durationSeconds;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.isCurrent
              ? accent.withValues(alpha: 0.12)
              : _hovered
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.transparent,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => unawaited(widget.onPlay()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: <Widget>[
                  if (widget.index != null)
                    SizedBox(
                      width: 38,
                      child: Text(
                        widget.index!.toString().padLeft(2, '0'),
                        style: merakiPixelStyle(
                          14,
                          color: MerakiColors.softText,
                        ),
                      ),
                    ),
                  CoverArtImage(
                    coverArtUrlOrPath: song.coverArtUrlOrPath,
                    width: 58,
                    height: 58,
                    cacheWidth: 174,
                    cacheHeight: 174,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: merakiPixelStyle(
                            19,
                            weight: FontWeight.w600,
                            color: widget.isCurrent
                                ? colors.secondary
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MerakiColors.softText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showDetails) ...<Widget>[
                    const SizedBox(width: 12),
                    _SourceChip(
                      label: _songSourceLabel(song.source),
                      compact: true,
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 52,
                      child: Text(
                        seconds == null || seconds <= 0
                            ? '--:--'
                            : _formatDeckDuration(Duration(seconds: seconds)),
                        textAlign: TextAlign.right,
                        style: merakiPixelStyle(
                          14,
                          color: MerakiColors.softText,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: widget.isFavorite
                        ? 'Remover das favoritas'
                        : 'Curtir',
                    onPressed: widget.onToggleFavorite,
                    iconSize: 20,
                    color: widget.isFavorite
                        ? accent
                        : MerakiColors.softText.withValues(
                            alpha: _hovered ? 0.9 : 0.45,
                          ),
                    icon: Icon(
                      widget.isFavorite
                          ? PhosphorIconsFill.heart
                          : PhosphorIconsRegular.heart,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _OutlinedPlayButton(
                    isPlaying: widget.isPlaying,
                    onTap: widget.onPlay,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedPlayButton extends StatefulWidget {
  const _OutlinedPlayButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final Future<void> Function() onTap;

  @override
  State<_OutlinedPlayButton> createState() => _OutlinedPlayButtonState();
}

class _OutlinedPlayButtonState extends State<_OutlinedPlayButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = _hovered || widget.isPlaying
        ? accent
        : Colors.white.withValues(alpha: 0.85);
    return Tooltip(
      message: widget.isPlaying ? 'Pausar' : 'Tocar',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => unawaited(widget.onTap()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.2),
            ),
            child: Icon(
              widget.isPlaying
                  ? PhosphorIconsFill.pause
                  : PhosphorIconsFill.play,
              size: 19,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: merakiPixelStyle(
                  44,
                  weight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: MerakiColors.softText,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _PixelActionButton extends StatelessWidget {
  const _PixelActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: merakiPixelStyle(15, weight: FontWeight.w600, color: MerakiColors.deepPurple)),
    );
  }
}

class _PixelChip extends StatelessWidget {
  const _PixelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected
            ? accent
            : MerakiColors.softText.withValues(alpha: 0.6),
        width: 1.4,
      ),
    );
    return Material(
      color: selected ? accent : Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            label,
            style: merakiPixelStyle(
              15,
              weight: FontWeight.w600,
              color: selected ? MerakiColors.deepPurple : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Favoritas
// ---------------------------------------------------------------------------

class _DesktopFavoritesPage extends StatelessWidget {
  const _DesktopFavoritesPage({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final songs = state.widget.libraryController.favoriteSongs;
    final plural = songs.length == 1 ? '' : 's';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PageHeader(
            title: 'Favoritas',
            subtitle: songs.isEmpty
                ? 'Toque no coração de uma música para curtir.'
                : '${songs.length} música$plural curtida$plural',
            action: songs.isEmpty
                ? null
                : _PixelActionButton(
                    label: 'Tocar tudo',
                    icon: PhosphorIconsFill.play,
                    onTap: () => unawaited(state.playSong(songs.first, songs)),
                  ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: songs.isEmpty
                ? const _EmptyCatalogHint(
                    title: 'Nenhuma música favorita ainda',
                  )
                : _SongRowList(
                    state: state,
                    songs: songs,
                    showDetails: true,
                    indexed: true,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Todas as Músicas (músicas, álbuns, artistas)
// ---------------------------------------------------------------------------

Map<String, List<Song>> _groupSongs(
  List<Song> songs,
  String? Function(Song song) keyOf,
  String fallback,
) {
  final grouped = <String, List<Song>>{};
  for (final song in songs) {
    final value = keyOf(song)?.trim();
    final key = value == null || value.isEmpty ? fallback : value;
    grouped.putIfAbsent(key, () => <Song>[]).add(song);
  }
  final keys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return <String, List<Song>>{for (final key in keys) key: grouped[key]!};
}

class _DesktopLibraryPage extends StatelessWidget {
  const _DesktopLibraryPage({required this.state});

  final _HomeScreenState state;

  static const List<(_HomeDestination, String)> _tabs =
      <(_HomeDestination, String)>[
        (_HomeDestination.allSongs, 'Todas as Músicas'),
        (_HomeDestination.albums, 'Álbuns'),
        (_HomeDestination.artists, 'Artistas'),
        (_HomeDestination.downloads, 'Músicas baixadas'),
      ];

  @override
  Widget build(BuildContext context) {
    final destination = state._destination;
    final songs = state.filteredSongs;
    final query = state._searchQuery.trim();
    final albums = _groupSongs(songs, (song) => song.album, 'Sem álbum');
    final artists = _groupSongs(
      songs,
      (song) => song.artist,
      'Artista desconhecido',
    );
    final visibleSongs = destination == _HomeDestination.downloads
        ? songs
              .where((song) => song.source == SongSource.local)
              .toList(growable: false)
        : songs;
    final summary =
        '${songs.length} música${songs.length == 1 ? '' : 's'} • '
        '${albums.length} álbu${albums.length == 1 ? 'm' : 'ns'} • '
        '${artists.length} artista${artists.length == 1 ? '' : 's'}';

    final Widget body = switch (destination) {
      _HomeDestination.albums => _CardGrid(
        entries: albums,
        emptyMessage: 'Nenhum álbum encontrado.',
        subtitleOf: (entry) =>
            'por ${entry.value.first.artist ?? 'Artista desconhecido'}',
        onPlay: (entry) =>
            unawaited(state.playSong(entry.value.first, entry.value)),
      ),
      _HomeDestination.artists => _CardGrid(
        entries: artists,
        circle: true,
        emptyMessage: 'Nenhum artista encontrado.',
        subtitleOf: (entry) =>
            '${entry.value.length} faixa${entry.value.length == 1 ? '' : 's'}',
        onPlay: (entry) =>
            unawaited(state.playSong(entry.value.first, entry.value)),
      ),
      _ => _SongRowList(
        state: state,
        songs: visibleSongs,
        showDetails: true,
        emptyMessage: destination == _HomeDestination.downloads
            ? 'Nenhuma música baixada ainda.'
            : 'Nenhuma música encontrada.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PageHeader(
            title: 'Todas as Músicas',
            subtitle: query.isEmpty
                ? summary
                : 'Resultados para "$query" • $summary',
            action: visibleSongs.isEmpty
                ? null
                : _PixelActionButton(
                    label: 'Tocar tudo',
                    icon: PhosphorIconsFill.play,
                    onTap: () => unawaited(
                      state.playSong(visibleSongs.first, visibleSongs),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final (tab, label) in _tabs)
                _PixelChip(
                  label: label,
                  selected: destination == tab,
                  onTap: () => state.setDestination(tab),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.entries,
    required this.emptyMessage,
    required this.subtitleOf,
    required this.onPlay,
    this.circle = false,
  });

  final Map<String, List<Song>> entries;
  final String emptyMessage;
  final String Function(MapEntry<String, List<Song>> entry) subtitleOf;
  final void Function(MapEntry<String, List<Song>> entry) onPlay;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final list = entries.entries.toList(growable: false);
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          emptyMessage,
          style: merakiPixelStyle(16, color: MerakiColors.softText),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 22,
        crossAxisSpacing: 20,
        childAspectRatio: 0.74,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entry = list[index];
        return _MediaCard(
          coverArtUrlOrPath: entry.value
              .map((song) => song.coverArtUrlOrPath)
              .where((cover) => cover != null && cover.isNotEmpty)
              .firstOrNull,
          title: entry.key,
          subtitle: subtitleOf(entry),
          circle: circle,
          onTap: () => onPlay(entry),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tocando agora
// ---------------------------------------------------------------------------

class _DesktopNowPlayingPage extends StatelessWidget {
  const _DesktopNowPlayingPage({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return _PlayerBuilder(
      controller: state.widget.playerController,
      builder: (context, item, playbackState) => LayoutBuilder(
        builder: (context, constraints) {
          final turntable = _DeckTurntable(
            state: state,
            item: item,
            playbackState: playbackState,
          );
          final info = _NowPlayingInfo(
            state: state,
            item: item,
            playbackState: playbackState,
          );
          if (constraints.maxWidth < 900) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 32, 32),
              children: <Widget>[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: turntable,
                  ),
                ),
                const SizedBox(height: 28),
                info,
              ],
            );
          }

          const minHeight = 560.0;
          final height = math.max(constraints.maxHeight, minHeight);
          final turntableWidth = math.min(
            (constraints.maxWidth - 88) * 0.56,
            (height - 60) * MerakiTurntable.aspectRatio,
          );
          final content = SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 40, 32),
              child: Row(
                children: <Widget>[
                  SizedBox(width: turntableWidth, child: turntable),
                  const SizedBox(width: 52),
                  Expanded(child: info),
                ],
              ),
            ),
          );
          if (constraints.maxHeight >= minHeight) return content;
          return SingleChildScrollView(child: content);
        },
      ),
    );
  }
}

class _NowPlayingInfo extends StatelessWidget {
  const _NowPlayingInfo({
    required this.state,
    required this.item,
    required this.playbackState,
  });

  final _HomeScreenState state;
  final MediaItem? item;
  final PlaybackState playbackState;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final item = this.item;
    final album = item?.album?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'TOCANDO AGORA',
          style: merakiPixelStyle(
            14,
            color: accent,
            weight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 14),
        _DeckTitle(state: state, item: item, size: 48, maxLines: 2),
        const SizedBox(height: 12),
        if (item == null)
          const Text(
            'Escolha uma música na biblioteca para começar a tocar.',
            style: TextStyle(color: MerakiColors.softText, fontSize: 16),
          )
        else ...<Widget>[
          Text(
            item.artist ?? 'Artista desconhecido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          if (album != null && album.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              album,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                color: MerakiColors.softText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SourceChip(
            label: _sourceLabelFor(item.extras?['source'] as String?),
          ),
        ],
        const SizedBox(height: 36),
        _DeckProgress(controller: state.widget.playerController, item: item),
        const SizedBox(height: 26),
        _DeckControls(
          state: state,
          item: item,
          playbackState: playbackState,
          playSize: 84,
        ),
      ],
    );
  }
}
