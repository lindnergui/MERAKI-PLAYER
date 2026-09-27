import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:meraki/src/rust/models/song.dart';
import 'package:meraki/src/ui/controllers/library_controller.dart';
import 'package:meraki/src/ui/controllers/player_controller.dart';
import 'package:meraki/src/ui/meraki_theme.dart';
import 'package:meraki/src/ui/screens/now_playing_screen.dart';
import 'package:meraki/src/ui/screens/settings_screen.dart';
import 'package:meraki/src/ui/widgets/cover_art_image.dart';
import 'package:meraki/src/ui/widgets/cover_flow_spotlight.dart';
import 'package:meraki/src/ui/widgets/glass_panel.dart';
import 'package:meraki/src/ui/widgets/mini_player.dart';
import 'package:meraki/src/ui/widgets/song_tile.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

enum _HomeDestination { home, allSongs, favorites, downloads, albums, artists }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.userName,
    required this.libraryController,
    required this.playerController,
    required this.onLogout,
    super.key,
  });

  final String userName;
  final LibraryController libraryController;
  final PlayerController playerController;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeDestination _destination = _HomeDestination.home;
  String _searchQuery = '';
  Song? _selectedSpotlightSong;
  List<Song> _spotlightSongs = const <Song>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalog());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones use touch-first navigation. At 600dp and above we retain the
        // desktop shell, which is also the layout used by Linux.
        final isDesktop = constraints.maxWidth >= 600;
        if (isDesktop) {
          return _DesktopShell(state: this);
        }
        return _MobileShell(state: this);
      },
    );
  }

  List<Song> get filteredSongs {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.libraryController.songs;
    return widget.libraryController.songs
        .where((song) {
          return <String?>[song.title, song.artist, song.album]
              .whereType<String>()
              .any((part) => part.toLowerCase().contains(query));
        })
        .toList(growable: false);
  }

  Future<void> _loadCatalog() async {
    try {
      await widget.libraryController.loadCatalog();
      if (mounted) setState(_refreshSpotlightSongs);
    } catch (_) {
      if (mounted) _showError(widget.libraryController.errorMessage);
    }
  }

  void setDestination(_HomeDestination destination) {
    final shouldRefreshSpotlight =
        destination == _HomeDestination.home &&
        _destination != _HomeDestination.home;
    setState(() {
      _destination = destination;
      if (shouldRefreshSpotlight) _refreshSpotlightSongs();
    });
  }

  void _refreshSpotlightSongs() {
    final selection = List<Song>.of(widget.libraryController.songs)
      ..shuffle(math.Random());
    _spotlightSongs = List<Song>.unmodifiable(
      selection.take(math.min(selection.length, 12)),
    );
    _selectedSpotlightSong = _spotlightSongs.isEmpty
        ? null
        : _spotlightSongs.first;
  }

  void setSearchQuery(String value) => setState(() => _searchQuery = value);

  void openNowPlaying() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            NowPlayingScreen(controller: widget.playerController),
      ),
    );
  }

  void openMobileNowPlayingSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MobileNowPlayingSheet(controller: widget.playerController),
    );
  }

  void openMobileCatalogSheet(_HomeDestination destination) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MobileCatalogSheet(destination: destination, state: this),
    );
  }

  void openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            SettingsScreen(libraryController: widget.libraryController),
      ),
    );
  }

  Future<void> logout() async {
    try {
      await widget.onLogout();
    } catch (_) {
      if (mounted) _showError('Não foi possível sair. Tente novamente.');
    }
  }

  void setSelectedSpotlightSong(Song? song) {
    if (_selectedSpotlightSong?.id == song?.id) return;
    setState(() => _selectedSpotlightSong = song);
  }

  Future<void> toggleSelectedSpotlightFavorite() async {
    final song = _selectedSpotlightSong;
    if (song == null) {
      _showError('Selecione uma música no Meraki Spotlight primeiro.');
      return;
    }

    try {
      final isNowFavorite = await widget.libraryController.toggleFavorite(song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNowFavorite
                  ? '${song.title} foi adicionada às favoritas.'
                  : '${song.title} foi removida das favoritas.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) _showError('Não foi possível atualizar as favoritas.');
    }
  }

  Future<void> playSong(Song song, List<Song> queue) async {
    try {
      await widget.playerController.playFromCatalog(song, queue);
    } catch (error) {
      if (mounted) _showError('Não foi possível iniciar a reprodução: $error');
    }
  }

  void _showError(String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Não foi possível atualizar o catálogo.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: MerakiColors.deepPurple),
        child: SafeArea(
          child: Row(
            children: <Widget>[
              _MerakiSidebar(state: state),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _TopBar(state: state),
                    Expanded(child: _DesktopContent(state: state)),
                    MiniPlayer(
                      controller: state.widget.playerController,
                      onOpenNowPlaying: state.openNowPlaying,
                      desktop: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: MerakiColors.deepPurple,
        title: const _MerakiWordmark(compact: true),
        actions: <Widget>[
          IconButton(
            tooltip: 'Configurações',
            onPressed: state.openSettings,
            icon: Icon(PhosphorIconsRegular.gear),
          ),
        ],
      ),
      body: _MobileBrowse(state: state),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MiniPlayer(
            controller: state.widget.playerController,
            onOpenNowPlaying: state.openMobileNowPlayingSheet,
          ),
          _MobileFloatingNavigation(state: state),
        ],
      ),
    );
  }
}

/// Mobile navigation keeps the catalog actions one thumb-reach away without
/// reproducing desktop-only shortcut cards in the page content.
class _MobileFloatingNavigation extends StatelessWidget {
  const _MobileFloatingNavigation({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Material(
          color: MerakiColors.panel,
          elevation: 14,
          shadowColor: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.9),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _MobileNavigationIcon(
                    tooltip: 'Todas as músicas',
                    icon: PhosphorIconsRegular.musicNotes,
                    onTap: () =>
                        state.openMobileCatalogSheet(_HomeDestination.allSongs),
                  ),
                ),
                Expanded(
                  child: _MobileNavigationIcon(
                    tooltip: 'Álbuns',
                    icon: PhosphorIconsRegular.disc,
                    onTap: () =>
                        state.openMobileCatalogSheet(_HomeDestination.albums),
                  ),
                ),
                _MobileNowPlayingNavigation(state: state),
                Expanded(
                  child: _MobileNavigationIcon(
                    tooltip: 'Artistas',
                    icon: PhosphorIconsRegular.usersThree,
                    onTap: () =>
                        state.openMobileCatalogSheet(_HomeDestination.artists),
                  ),
                ),
                Expanded(
                  child: _MobileNavigationIcon(
                    tooltip: 'Músicas baixadas',
                    icon: PhosphorIconsRegular.downloadSimple,
                    onTap: () => state.openMobileCatalogSheet(
                      _HomeDestination.downloads,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationIcon extends StatelessWidget {
  const _MobileNavigationIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: MerakiColors.softText),
      ),
    );
  }
}

class _MobileNowPlayingNavigation extends StatelessWidget {
  const _MobileNowPlayingNavigation({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MediaItem?>(
      valueListenable: state.widget.playerController.currentItem,
      builder: (context, item, _) {
        final accent = Theme.of(context).colorScheme.primary;
        return Transform.translate(
          offset: const Offset(0, -13),
          child: Tooltip(
            message: 'Tocando agora',
            child: Material(
              color: item == null ? Colors.transparent : accent,
              elevation: item == null ? 0 : 10,
              shadowColor: accent.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: state.openMobileNowPlayingSheet,
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: item == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MerakiColors.softText.withValues(
                                alpha: 0.8,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            PhosphorIconsRegular.playCircle,
                            color: MerakiColors.softText,
                            size: 30,
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            CoverArtImage(
                              coverArtUrlOrPath: item.artUri?.toString(),
                              cacheWidth: 180,
                              cacheHeight: 180,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(99),
                              ),
                            ),
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ],
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

class _MobileNowPlayingSheet extends StatelessWidget {
  const _MobileNowPlayingSheet({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.56,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) => Material(
        color: MerakiColors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: CustomScrollView(
          controller: scrollController,
          slivers: <Widget>[
            const SliverToBoxAdapter(child: _SheetHandle()),
            SliverFillRemaining(
              hasScrollBody: false,
              child: NowPlayingScreen(controller: controller, embedded: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCatalogSheet extends StatefulWidget {
  const _MobileCatalogSheet({required this.destination, required this.state});

  final _HomeDestination destination;
  final _HomeScreenState state;

  @override
  State<_MobileCatalogSheet> createState() => _MobileCatalogSheetState();
}

class _MobileCatalogSheetState extends State<_MobileCatalogSheet> {
  String _query = '';

  String get _title => switch (widget.destination) {
    _HomeDestination.allSongs => 'Todas as músicas',
    _HomeDestination.albums => 'Álbuns',
    _HomeDestination.artists => 'Artistas',
    _HomeDestination.downloads => 'Músicas baixadas',
    _HomeDestination.home || _HomeDestination.favorites => 'Biblioteca',
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Material(
        color: MerakiColors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Text(
                _title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.destination == _HomeDestination.allSongs)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar música, álbum ou artista',
                    prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                  ),
                ),
              ),
            Expanded(child: _buildContent(scrollController)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    return switch (widget.destination) {
      _HomeDestination.allSongs ||
      _HomeDestination.downloads => _SongCatalogList(
        controller: scrollController,
        songs: _songsForDestination,
        state: widget.state,
      ),
      _HomeDestination.albums => _AlbumCatalogGrid(
        controller: scrollController,
        state: widget.state,
      ),
      _HomeDestination.artists => _ArtistCatalogList(
        controller: scrollController,
        state: widget.state,
      ),
      _HomeDestination.home || _HomeDestination.favorites => const SizedBox(),
    };
  }

  List<Song> get _songsForDestination {
    Iterable<Song> songs = widget.state.widget.libraryController.songs;
    if (widget.destination == _HomeDestination.downloads) {
      songs = songs.where((song) => song.source == SongSource.local);
    }

    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      songs = songs.where(
        (song) => <String?>[song.title, song.artist, song.album]
            .whereType<String>()
            .any((value) => value.toLowerCase().contains(query)),
      );
    }
    return songs.toList(growable: false);
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: MerakiColors.softText.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _SongCatalogList extends StatelessWidget {
  const _SongCatalogList({
    required this.controller,
    required this.songs,
    required this.state,
  });

  final ScrollController controller;
  final List<Song> songs;
  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const _EmptyCatalogHint(title: 'Nenhuma música encontrada.');
    }
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongTile(song: song, onPlay: () => state.playSong(song, songs));
      },
    );
  }
}

class _AlbumCatalogGrid extends StatelessWidget {
  const _AlbumCatalogGrid({required this.controller, required this.state});

  final ScrollController controller;
  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final albums = state.widget.libraryController.albums.entries.toList();
    if (albums.isEmpty) {
      return const _EmptyCatalogHint(title: 'Nenhum álbum encontrado.');
    }
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final entry = albums[index];
        final first = entry.value.first;
        return _PopularSongCard(
          song: first,
          onTap: () => state.playSong(first, entry.value),
          enableHover: false,
        );
      },
    );
  }
}

class _ArtistCatalogList extends StatelessWidget {
  const _ArtistCatalogList({required this.controller, required this.state});

  final ScrollController controller;
  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final artists = <String, List<Song>>{};
    for (final song in state.widget.libraryController.songs) {
      final value = song.artist?.trim();
      final name = value == null || value.isEmpty
          ? 'Artista desconhecido'
          : value;
      artists.putIfAbsent(name, () => <Song>[]).add(song);
    }
    final entries = artists.entries.toList()
      ..sort((first, second) => first.key.compareTo(second.key));
    if (entries.isEmpty) {
      return const _EmptyCatalogHint(title: 'Nenhum artista encontrado.');
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: MerakiColors.deepPurple.withValues(alpha: 0.5),
          leading: CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            child: Icon(PhosphorIconsRegular.userCircle),
          ),
          title: Text(entry.key),
          subtitle: Text(
            '${entry.value.length} faixa${entry.value.length == 1 ? '' : 's'}',
          ),
          trailing: Icon(PhosphorIconsRegular.play),
          onTap: () => state.playSong(entry.value.first, entry.value),
        );
      },
    );
  }
}

class _MerakiSidebar extends StatelessWidget {
  const _MerakiSidebar({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: GlassPanel(
          enableBlur: false,
          padding: const EdgeInsets.all(14),
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 28),
                child: _MerakiWordmark(),
              ),
              _SidebarDestination(
                label: 'Home',
                icon: PhosphorIconsRegular.house,
                selected: state._destination == _HomeDestination.home,
                onTap: () => state.setDestination(_HomeDestination.home),
              ),
              _SidebarDestination(
                label: 'Todas as Músicas',
                icon: PhosphorIconsRegular.musicNotes,
                selected: state._destination == _HomeDestination.allSongs,
                onTap: () => state.setDestination(_HomeDestination.allSongs),
              ),
              _SidebarDestination(
                label: 'Favoritas',
                icon: PhosphorIconsRegular.heart,
                selected: state._destination == _HomeDestination.favorites,
                onTap: () => state.setDestination(_HomeDestination.favorites),
              ),
              _SidebarDestination(
                label: 'Músicas baixadas',
                icon: PhosphorIconsRegular.downloadSimple,
                selected: state._destination == _HomeDestination.downloads,
                onTap: () => state.setDestination(_HomeDestination.downloads),
              ),
              _SidebarDestination(
                label: 'Álbuns',
                icon: PhosphorIconsRegular.disc,
                selected: state._destination == _HomeDestination.albums,
                onTap: () => state.setDestination(_HomeDestination.albums),
              ),
              _SidebarDestination(
                label: 'Artistas',
                icon: PhosphorIconsRegular.usersThree,
                selected: state._destination == _HomeDestination.artists,
                onTap: () => state.setDestination(_HomeDestination.artists),
              ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: 12),
              _ProfileCard(userName: state.widget.userName),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: state.logout,
                icon: Icon(PhosphorIconsRegular.signOut, size: 18),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: selected ? accent : null),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : MerakiColors.softText,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state.widget.libraryController,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(34, 28, 34, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  onChanged: state.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar por música, álbum ou artista',
                    prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              tooltip: 'Favoritos',
              onPressed: state._selectedSpotlightSong == null
                  ? null
                  : state.toggleSelectedSpotlightFavorite,
              color:
                  state._selectedSpotlightSong != null &&
                      state.widget.libraryController.isFavorite(
                        state._selectedSpotlightSong!.id,
                      )
                  ? Theme.of(context).colorScheme.primary
                  : null,
              icon: Icon(
                state._selectedSpotlightSong != null &&
                        state.widget.libraryController.isFavorite(
                          state._selectedSpotlightSong!.id,
                        )
                    ? PhosphorIconsFill.heart
                    : PhosphorIconsRegular.heart,
              ),
            ),
            IconButton(
              tooltip: 'Configurações',
              onPressed: state.openSettings,
              icon: Icon(PhosphorIconsRegular.gear),
            ),
            const SizedBox(width: 10),
            _ProfileHeader(userName: state.widget.userName),
          ],
        ),
      ),
    );
  }
}

class _DesktopContent extends StatelessWidget {
  const _DesktopContent({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state.widget.libraryController,
      builder: (context, _) {
        if (state.widget.libraryController.isLoading &&
            state.widget.libraryController.songs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _ContentForDestination(state: state, desktop: true);
      },
    );
  }
}

class _MobileBrowse extends StatelessWidget {
  const _MobileBrowse({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state.widget.libraryController,
      builder: (context, _) {
        if (state.widget.libraryController.isLoading &&
            state.widget.libraryController.songs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _ContentForDestination(state: state, desktop: false);
      },
    );
  }
}

class _ContentForDestination extends StatelessWidget {
  const _ContentForDestination({required this.state, required this.desktop});

  final _HomeScreenState state;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return switch (state._destination) {
      _HomeDestination.home => _HomeDashboard(state: state, desktop: desktop),
      _HomeDestination.allSongs => _SongsPage(
        title: 'Todas as músicas',
        songs: state.filteredSongs,
        state: state,
        desktop: desktop,
        showSearch: !desktop,
      ),
      _HomeDestination.favorites => _SongsPage(
        title: 'Favoritas',
        songs: state.widget.libraryController.favoriteSongs,
        state: state,
        desktop: desktop,
        emptyTitle: 'Nenhuma música favorita ainda',
      ),
      _HomeDestination.downloads => _SongsPage(
        title: 'Músicas baixadas',
        songs: state.filteredSongs
            .where((song) => song.source == SongSource.local)
            .toList(growable: false),
        state: state,
        desktop: desktop,
        emptyTitle: 'Nenhuma música baixada ainda',
      ),
      _HomeDestination.albums => _AlbumsPage(state: state),
      _HomeDestination.artists => _ArtistsPage(state: state),
    };
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.state, required this.desktop});

  final _HomeScreenState state;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final songs = state.filteredSongs;
    final spotlightSongs = state._spotlightSongs;
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 34 : 20,
            12,
            desktop ? 34 : 20,
            28,
          ),
          sliver: SliverMainAxisGroup(
            slivers: <Widget>[
              if (desktop)
                SliverToBoxAdapter(
                  child: _DashboardGreeting(userName: state.widget.userName),
                ),
              if (desktop)
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Meraki Spotlight',
                  subtitle: 'Uma seleção que combina com o seu momento',
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: CoverFlowSpotlight(
                  songs: spotlightSongs,
                  onPlay: (song) => state.playSong(song, songs),
                  desktop: desktop,
                  onSelectionChanged: state.setSelectedSpotlightSong,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              SliverToBoxAdapter(child: _SectionHeader(title: 'Mais ouvidas')),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              _PopularGrid(songs: songs, state: state, desktop: desktop),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardGreeting extends StatelessWidget {
  const _DashboardGreeting({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Olá, $userName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Seu som, com a sua identidade.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: MerakiColors.softText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    this.subtitle,
    required this.title,
  });

  final String title;
  final String? subtitle;

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(color: MerakiColors.softText),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SpotlightCarousel extends StatefulWidget {
  const _SpotlightCarousel({
    required this.songs,
    required this.onPlay,
    required this.desktop,
  });

  final List<Song> songs;
  final ValueChanged<Song> onPlay;
  final bool desktop;

  @override
  State<_SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<_SpotlightCarousel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.songs.take(7).toList(growable: false);
    final cardWidth = widget.desktop ? 330.0 : 270.0;
    return SizedBox(
      height: widget.desktop ? 260 : 230,
      child: Stack(
        children: <Widget>[
          ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 56),
            itemCount: math.max(cards.length, 4),
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final song = index < cards.length ? cards[index] : null;
              return SizedBox(
                width: cardWidth,
                child: _SpotlightCard(
                  song: song,
                  index: index,
                  onPlay: song == null ? null : () => widget.onPlay(song),
                  desktop: widget.desktop,
                ),
              );
            },
          ),
          if (widget.desktop)
            Positioned(
              right: 0,
              top: 98,
              child: _CarouselArrow(
                icon: PhosphorIconsRegular.caretRight,
                onTap: () => _scrollBy(260),
              ),
            ),
          if (widget.desktop)
            Positioned(
              left: 0,
              top: 98,
              child: _CarouselArrow(
                icon: PhosphorIconsRegular.caretLeft,
                onTap: () => _scrollBy(-260),
              ),
            ),
        ],
      ),
    );
  }

  void _scrollBy(double delta) {
    final target = (_scrollController.offset + delta).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    required this.song,
    required this.index,
    required this.onPlay,
    required this.desktop,
  });

  final Song? song;
  final int index;
  final VoidCallback? onPlay;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final title = song?.title ?? 'Seu próximo som';
    final artist = song?.artist ?? 'Meraki Radio';
    return Transform.rotate(
      angle: desktop ? (index.isEven ? -0.018 : 0.018) : 0,
      child: RepaintBoundary(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPlay,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.70),
                  MerakiColors.panel,
                  MerakiColors.sidebar,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.24),
                  blurRadius: 28,
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (song != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Opacity(
                      opacity: 0.72,
                      child: CoverArtImage(
                        coverArtUrlOrPath: song!.coverArtUrlOrPath,
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        MerakiColors.deepPurple.withValues(alpha: 0.94),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              artist,
                              style: const TextStyle(
                                color: MerakiColors.softText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: onPlay,
                          color: MerakiColors.deepPurple,
                          icon: Icon(PhosphorIconsFill.play),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: MerakiColors.deepPurple),
      ),
    );
  }
}

class _CategoryChips extends StatefulWidget {
  const _CategoryChips();

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  static const _categories = <String>[
    'All',
    'Relax',
    'Sad',
    'Party',
    'Romance',
    'Energetic',
    'Jazz',
    'Alternative',
  ];
  var _selected = 'All';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return ChoiceChip(
            label: Text(category),
            selected: _selected == category,
            onSelected: (_) => setState(() => _selected = category),
          );
        },
      ),
    );
  }
}

class _PopularGrid extends StatefulWidget {
  const _PopularGrid({
    required this.songs,
    required this.state,
    required this.desktop,
  });

  final List<Song> songs;
  final _HomeScreenState state;
  final bool desktop;

  @override
  State<_PopularGrid> createState() => _PopularGridState();
}

class _PopularGridState extends State<_PopularGrid> {
  List<Song> _items = const <Song>[];
  String _catalogSignature = '';

  @override
  void initState() {
    super.initState();
    _refreshSelection();
  }

  @override
  void didUpdateWidget(covariant _PopularGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshSelection();
  }

  void _refreshSelection() {
    final signature = widget.songs.map((song) => song.id).join('|');
    if (signature == _catalogSignature) return;

    final selection = List<Song>.of(widget.songs)
      ..shuffle(math.Random(signature.hashCode));
    _catalogSignature = signature;
    _items = selection.take(widget.desktop ? 12 : 8).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyCatalogHint());
    }
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.desktop ? 6 : 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: widget.desktop ? 0.78 : 0.82,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) => _PopularSongCard(
        song: _items[index],
        onTap: () => widget.state.playSong(_items[index], widget.songs),
        enableHover: widget.desktop,
      ),
    );
  }
}

class _PopularSongCard extends StatefulWidget {
  const _PopularSongCard({
    required this.song,
    required this.onTap,
    this.enableHover = true,
  });

  final Song song;
  final VoidCallback onTap;
  final bool enableHover;

  @override
  State<_PopularSongCard> createState() => _PopularSongCardState();
}

class _PopularSongCardState extends State<_PopularSongCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: widget.enableHover
          ? (_) => setState(() => _hovered = true)
          : null,
      onExit: widget.enableHover
          ? (_) => setState(() => _hovered = false)
          : null,
      child: AnimatedScale(
        scale: _hovered ? 1.045 : 1,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: _hovered
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.42),
                      blurRadius: 24,
                      spreadRadius: -6,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Material(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CoverArtImage(
                              coverArtUrlOrPath: widget.song.coverArtUrlOrPath,
                              cacheWidth: 420,
                              cacheHeight: 420,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: _hovered ? 1 : 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    PhosphorIconsFill.play,
                                    size: 17,
                                    color: MerakiColors.deepPurple,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.song.artist ?? 'Artista desconhecido',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MerakiColors.softText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongsPage extends StatelessWidget {
  const _SongsPage({
    required this.title,
    required this.songs,
    required this.state,
    required this.desktop,
    this.showSearch = false,
    this.emptyTitle,
  });

  final String title;
  final List<Song> songs;
  final _HomeScreenState state;
  final bool desktop;
  final bool showSearch;
  final String? emptyTitle;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty && !showSearch) {
      return _EmptyCatalogHint(title: emptyTitle);
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        desktop ? 24 : 16,
        20,
        desktop ? 24 : 16,
        28,
      ),
      itemCount: songs.isEmpty ? 2 : songs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (showSearch) ...<Widget>[
                  const SizedBox(height: 14),
                  TextField(
                    autofocus: false,
                    onChanged: state.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar música, álbum ou artista',
                      prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        if (songs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'Nenhuma música encontrada.',
                style: const TextStyle(color: MerakiColors.softText),
              ),
            ),
          );
        }
        final song = songs[index - 1];
        return SongTile(song: song, onPlay: () => state.playSong(song, songs));
      },
    );
  }
}

class _AlbumsPage extends StatelessWidget {
  const _AlbumsPage({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final albums = state.widget.libraryController.albums.entries.toList();
    if (albums.isEmpty) return const _EmptyCatalogHint();
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.86,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final entry = albums[index];
        final first = entry.value.first;
        return _PopularSongCard(
          song: first,
          onTap: () => state.playSong(first, entry.value),
        );
      },
    );
  }
}

class _ArtistsPage extends StatelessWidget {
  const _ArtistsPage({required this.state});

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final artists = <String, List<Song>>{};
    for (final song in state.filteredSongs) {
      final artist = song.artist?.trim();
      final key = artist == null || artist.isEmpty
          ? 'Artista desconhecido'
          : artist;
      artists.putIfAbsent(key, () => <Song>[]).add(song);
    }
    final entries = artists.entries.toList();
    if (entries.isEmpty) return const _EmptyCatalogHint();
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Artistas',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          );
        }
        final entry = entries[index - 1];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            child: Icon(PhosphorIconsRegular.userCircle),
          ),
          title: Text(entry.key),
          subtitle: Text(
            '${entry.value.length} faixa${entry.value.length == 1 ? '' : 's'}',
          ),
          trailing: Icon(PhosphorIconsRegular.caretRight),
          onTap: () => state.playSong(entry.value.first, entry.value),
        );
      },
    );
  }
}

class _EmptyCatalogHint extends StatelessWidget {
  const _EmptyCatalogHint({this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassPanel(
          enableBlur: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                PhosphorIconsRegular.musicNotes,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title ?? 'Sua biblioteca ainda está vazia',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Conecte seu Jellyfin ou Subsonic, ou selecione uma pasta de músicas para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MerakiColors.softText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerakiWordmark extends StatelessWidget {
  const _MerakiWordmark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 34.0 : 40.0;
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(iconSize * 0.23),
          child: Image.asset(
            'assets/images/meraki_mark.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'MERAKI',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircleAvatar(
          radius: 19,
          backgroundColor: MerakiColors.panel,
          child: Icon(Icons.person_rounded, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Text(userName, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const CircleAvatar(
          backgroundColor: MerakiColors.panel,
          child: Icon(Icons.person_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            userName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
