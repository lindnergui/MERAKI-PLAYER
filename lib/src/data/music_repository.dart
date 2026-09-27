import 'dart:io';

import 'package:meraki/src/rust/api/music.dart' as rust_music;
import 'package:meraki/src/rust/models/song.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The only Dart layer allowed to call the generated Rust catalog API directly.
///
/// Keeping bridge calls behind this boundary makes widgets independent from FRB
/// and gives us one place to add retries, telemetry, and credential storage later.
class MusicRepository {
  /// Shared repository used by the application composition root.
  ///
  /// Controllers still receive this instance through their constructors, which
  /// keeps them easy to test and prevents widgets from calling FFI directly.
  static final MusicRepository instance = MusicRepository();

  Future<void> initialize() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, 'database'),
    );
    await databaseDirectory.create(recursive: true);

    await rust_music.initDb(
      databasePath: p.join(databaseDirectory.path, 'meraki.sqlite3'),
    );
  }

  Future<List<Song>> scanLocalMusic(String directoryPath) {
    return rust_music.scanLocalMusic(path: directoryPath);
  }

  Future<List<Song>> fetchSubsonicSongs({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    return rust_music.fetchSubsonicSongs(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }

  Future<List<Song>> getAllSongs() => rust_music.getAllSongs();

  Future<List<Song>> fetchJellyfinSongs({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    return rust_music.fetchJellyfinSongs(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }
}
