import 'package:flutter/foundation.dart';
import 'package:meraki/src/audio/meraki_audio_handler.dart';
import 'package:meraki/src/data/music_repository.dart';
import 'package:meraki/src/data/user_preferences.dart';
import 'package:meraki/src/rust/models/song.dart';

enum LibrarySection { all, local, subsonic, jellyfin, albums }

/// Owns catalog state and serialises catalog-refresh operations.
///
/// All repository methods return FRB futures, so awaiting them here yields the
/// Flutter event loop instead of blocking rendering or gesture handling.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required MusicRepository repository,
    required UserPreferences userPreferences,
    required MerakiAudioHandler audioHandler,
  }) : _repository = repository,
       _userPreferences = userPreferences,
       _audioHandler = audioHandler;

  final MusicRepository _repository;
  final UserPreferences _userPreferences;
  final MerakiAudioHandler _audioHandler;
  List<Song> _songs = const <Song>[];
  Set<String> _favoriteSongIds = <String>{};
  bool _isLoading = false;
  bool _isScanningLocal = false;
  bool _isSyncingServer = false;
  String? _errorMessage;

  List<Song> get songs => List<Song>.unmodifiable(_songs);
  bool get isLoading => _isLoading;
  bool get isScanningLocal => _isScanningLocal;
  bool get isSyncingServer => _isSyncingServer;
  bool get isBusy => _isLoading || _isScanningLocal || _isSyncingServer;
  String? get errorMessage => _errorMessage;
  List<Song> get favoriteSongs => _songs
      .where((song) => _favoriteSongIds.contains(song.id))
      .toList(growable: false);

  bool isFavorite(String songId) => _favoriteSongIds.contains(songId);

  List<Song> songsFor(LibrarySection section) {
    return switch (section) {
      LibrarySection.all || LibrarySection.albums => songs,
      LibrarySection.local =>
        _songs
            .where((song) => song.source == SongSource.local)
            .toList(growable: false),
      LibrarySection.subsonic =>
        _songs
            .where((song) => song.source == SongSource.subsonic)
            .toList(growable: false),
      LibrarySection.jellyfin =>
        _songs
            .where((song) => song.source == SongSource.jellyfin)
            .toList(growable: false),
    };
  }

  Map<String, List<Song>> get albums {
    final grouped = <String, List<Song>>{};
    for (final song in _songs) {
      final album = song.album?.trim();
      final key = album == null || album.isEmpty ? 'Sem álbum' : album;
      grouped.putIfAbsent(key, () => <Song>[]).add(song);
    }
    return grouped;
  }

  Future<void> loadCatalog() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repository.getAllSongs(),
        _userPreferences.readFavoriteSongIds(),
      ]);
      _songs = results[0] as List<Song>;
      _favoriteSongIds = results[1] as Set<String>;
      await _audioHandler.updateMediaLibrary(_songs);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite(Song song) async {
    final next = Set<String>.of(_favoriteSongIds);
    final isNowFavorite = next.add(song.id);
    if (!isNowFavorite) next.remove(song.id);

    await _userPreferences.saveFavoriteSongIds(next);
    _favoriteSongIds = next;
    notifyListeners();
    return isNowFavorite;
  }

  Future<void> scanLocalMusic(String directoryPath) async {
    if (_isScanningLocal) return;
    _isScanningLocal = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.scanLocalMusic(directoryPath);
      _songs = await _repository.getAllSongs();
      await _audioHandler.updateMediaLibrary(_songs);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _isScanningLocal = false;
      notifyListeners();
    }
  }

  Future<void> syncServer({
    required String serverUrl,
    required String username,
    required String password,
    bool jellyfin = false,
  }) async {
    if (_isSyncingServer) return;
    _isSyncingServer = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetch = jellyfin
          ? _repository.fetchJellyfinSongs
          : _repository.fetchSubsonicSongs;
      await fetch(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      _songs = await _repository.getAllSongs();
      await _audioHandler.updateMediaLibrary(_songs);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      _isSyncingServer = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Não foi possível concluir a operação.' : message;
  }
}
