import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meraki/src/data/music_repository.dart';
import 'package:meraki/src/rust/models/song.dart';
import 'package:rxdart/rxdart.dart';

/// Connects just_audio to Android MediaSession/background controls through
/// audio_service. Linux playback uses just_audio_media_kit, initialized in main.
abstract interface class SongPlayer {
  Future<void> playSong(Song song);
}

class MerakiAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements SongPlayer {
  MerakiAudioHandler({required MusicRepository repository})
    : _repository = repository {
    _playbackSubscription = _player.playbackEventStream.listen((event) {
      playbackState.add(_toPlaybackState(event));
    });
    _indexSubscription = _player.currentIndexStream.listen(_publishCurrentItem);
    _sequenceSubscription = _player.sequenceStateStream.listen(
      _publishUpNext,
    );
  }

  final AudioPlayer _player = AudioPlayer();
  final MusicRepository _repository;
  final List<MediaItem> _mediaItems = <MediaItem>[];
  final Map<String, BehaviorSubject<Map<String, dynamic>>>
  _libraryChangeStreams = <String, BehaviorSubject<Map<String, dynamic>>>{};
  final BehaviorSubject<List<MediaItem>> _upNext =
      BehaviorSubject<List<MediaItem>>.seeded(const <MediaItem>[]);

  List<Song> _librarySongs = const <Song>[];
  Map<String, Song> _librarySongsById = const <String, Song>{};
  late final StreamSubscription<PlaybackEvent> _playbackSubscription;
  late final StreamSubscription<int?> _indexSubscription;
  late final StreamSubscription<SequenceState?> _sequenceSubscription;

  /// Tracks that will play after the current one, in effective play order
  /// (shuffle aware). Used by the desktop "Próximas músicas" section.
  ValueStream<List<MediaItem>> get upNextStream => _upNext.stream;

  static const String _allSongsId = 'meraki:all-songs';
  static const String _localSongsId = 'meraki:local-songs';
  static const String _subsonicSongsId = 'meraki:subsonic-songs';
  static const String _jellyfinSongsId = 'meraki:jellyfin-songs';

  /// Reads the persisted Rust catalog before Android Auto requests it.
  ///
  /// This is deliberately asynchronous: database access happens through FRB
  /// and never blocks Flutter's main isolate or Android Auto's media controls.
  Future<void> refreshMediaLibrary() async {
    await updateMediaLibrary(await _repository.getAllSongs());
  }

  /// Replaces Android Auto's in-memory browse index after a local scan or a
  /// Subsonic sync. Playback itself still reads the original [Song] data.
  Future<void> updateMediaLibrary(List<Song> songs) async {
    _librarySongs = List<Song>.unmodifiable(songs);
    _librarySongsById = <String, Song>{
      for (final song in _librarySongs) song.id: song,
    };

    for (final stream in _libraryChangeStreams.values) {
      if (!stream.isClosed) {
        stream.add(const <String, dynamic>{});
      }
    }
  }

  @override
  Future<void> playSong(Song song) => playQueue(<Song>[song]);

  /// Supplies the browsable catalog used by Android Auto. `audio_service`
  /// forwards this contract through the manifest's MediaBrowserService.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return _libraryRoots;
      case AudioService.recentRootId:
        final currentItem = mediaItem.valueOrNull;
        return currentItem == null
            ? const <MediaItem>[]
            : <MediaItem>[currentItem];
      case _allSongsId:
        return _librarySongs.map(_mediaItemForSong).toList(growable: false);
      case _localSongsId:
        return _mediaItemsForSource(SongSource.local);
      case _subsonicSongsId:
        return _mediaItemsForSource(SongSource.subsonic);
      case _jellyfinSongsId:
        return _mediaItemsForSource(SongSource.jellyfin);
      default:
        return const <MediaItem>[];
    }
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    return _libraryChangeStreams
        .putIfAbsent(
          parentMediaId,
          () => BehaviorSubject<Map<String, dynamic>>.seeded(
            const <String, dynamic>{},
          ),
        )
        .stream;
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final song = _librarySongsById[mediaId];
    return song == null ? null : _mediaItemForSong(song);
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <MediaItem>[];
    }

    return _librarySongs
        .where(
          (song) => <String?>[song.title, song.artist, song.album].any(
            (value) => value?.toLowerCase().contains(normalizedQuery) ?? false,
          ),
        )
        .map(_mediaItemForSong)
        .toList(growable: false);
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final selectedSong = _librarySongsById[mediaId];
    if (selectedSong == null) return;

    final selectedIndex = _librarySongs.indexWhere(
      (song) => song.id == selectedSong.id,
    );
    if (selectedIndex >= 0) {
      await playQueue(_librarySongs, initialIndex: selectedIndex);
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) {
    return playFromMediaId(mediaItem.id);
  }

  /// Replaces the playable queue and starts the selected song. The UI sends a
  /// filtered catalog here so Next/Previous operate within the active section.
  Future<void> playQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) {
      return;
    }

    final safeInitialIndex = initialIndex.clamp(0, songs.length - 1);
    _mediaItems
      ..clear()
      ..addAll(songs.map(_mediaItemForSong));
    queue.add(List<MediaItem>.unmodifiable(_mediaItems));

    // Android needs the active MediaItem before the foreground playback state
    // is emitted. Publishing it first guarantees that the notification and
    // lock-screen session have artwork and metadata on the first play event.
    mediaItem.add(_mediaItems[safeInitialIndex]);

    await _player.setAudioSources(
      songs.map(_audioSourceForSong).toList(growable: false),
      initialIndex: safeInitialIndex,
    );
    _publishCurrentItem(safeInitialIndex);
    await play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) await play();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    if (enabled) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) {
    return _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => LoopMode.all,
    });
  }

  @override
  Future<void> stop() => _player.stop();

  double get volume => _player.volume;
  Stream<double> get volumeStream => _player.volumeStream;

  Future<void> setVolume(double volume) {
    return _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> dispose() async {
    await _playbackSubscription.cancel();
    await _indexSubscription.cancel();
    await _sequenceSubscription.cancel();
    await _upNext.close();
    await Future.wait<void>(
      _libraryChangeStreams.values.map((stream) => stream.close()),
    );
    await _player.dispose();
  }

  List<MediaItem> get _libraryRoots => const <MediaItem>[
    MediaItem(id: _allSongsId, title: 'Todas as músicas', playable: false),
    MediaItem(id: _localSongsId, title: 'Músicas locais', playable: false),
    MediaItem(
      id: _subsonicSongsId,
      title: 'Músicas do Subsonic',
      playable: false,
    ),
    MediaItem(
      id: _jellyfinSongsId,
      title: 'Músicas do Jellyfin',
      playable: false,
    ),
  ];

  List<MediaItem> _mediaItemsForSource(SongSource source) {
    return _librarySongs
        .where((song) => song.source == source)
        .map(_mediaItemForSong)
        .toList(growable: false);
  }

  AudioSource _audioSourceForSong(Song song) {
    return AudioSource.uri(_uriForSong(song), tag: _mediaItemForSong(song));
  }

  MediaItem _mediaItemForSong(Song song) {
    final uri = _uriForSong(song);
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.durationSeconds == null
          ? null
          : Duration(seconds: song.durationSeconds!),
      artUri: _artUri(song.coverArtUrlOrPath, song.source),
      extras: <String, Object?>{
        'playbackUri': uri.toString(),
        'source': song.source.name,
      },
    );
  }

  Uri _uriForSong(Song song) {
    return song.source == SongSource.local
        ? Uri.file(song.streamUrlOrFilePath)
        : Uri.parse(song.streamUrlOrFilePath);
  }

  void _publishCurrentItem(int? index) {
    if (index == null || index < 0 || index >= _mediaItems.length) {
      return;
    }
    mediaItem.add(_mediaItems[index]);
  }

  void _publishUpNext(SequenceState? state) {
    if (_upNext.isClosed) return;
    if (state == null) {
      _upNext.add(const <MediaItem>[]);
      return;
    }
    final effective = state.effectiveSequence;
    final current = state.currentSource;
    final position = current == null ? -1 : effective.indexOf(current);
    final upcoming = <MediaItem>[
      for (final source in effective.skip(position + 1))
        if (source.tag case final MediaItem item) item,
    ];
    _upNext.add(List<MediaItem>.unmodifiable(upcoming));
  }

  Uri? _artUri(String? value, SongSource source) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (source == SongSource.local) {
      return File(value).absolute.uri;
    }
    return Uri.tryParse(value);
  }

  PlaybackState _toPlaybackState(PlaybackEvent event) {
    final controls = <MediaControl>[
      if (_player.hasPrevious) MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      if (_player.hasNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    return PlaybackState(
      controls: controls,
      systemActions: const <MediaAction>{MediaAction.seek},
      androidCompactActionIndices: List<int>.generate(
        math.min(3, controls.length),
        (index) => index,
      ),
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      repeatMode: switch (_player.loopMode) {
        LoopMode.off => AudioServiceRepeatMode.none,
        LoopMode.one => AudioServiceRepeatMode.one,
        LoopMode.all => AudioServiceRepeatMode.all,
      },
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }
}
