import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meraki/src/audio/meraki_audio_handler.dart';
import 'package:meraki/src/data/music_repository.dart';
import 'package:meraki/src/data/user_preferences.dart';
import 'package:meraki/src/rust/models/song.dart';
import 'package:meraki/src/ui/controllers/library_controller.dart';
import 'package:meraki/src/ui/screens/settings_screen.dart';

class _Repository extends MusicRepository {
  String? protocol;
  String? password;

  @override
  Future<List<Song>> fetchJellyfinSongs({required String serverUrl, required String username, required String password}) async {
    protocol = 'Jellyfin';
    this.password = password;
    return [];
  }

  @override
  Future<List<Song>> fetchSubsonicSongs({required String serverUrl, required String username, required String password}) async {
    protocol = 'Subsonic';
    this.password = password;
    return [];
  }

  @override
  Future<List<Song>> getAllSongs() async => [];
}

class _AudioHandler implements MerakiAudioHandler {
  @override
  Future<void> updateMediaLibrary(List<Song> songs) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences implements UserPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final protocol in ['Subsonic', 'Jellyfin']) {
    testWidgets('sincroniza $protocol e preserva a senha', (tester) async {
      final repository = _Repository();
      final controller = LibraryController(
        repository: repository,
        userPreferences: _Preferences(),
        audioHandler: _AudioHandler(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(libraryController: controller)));
      if (protocol == 'Jellyfin') {
        await tester.tap(find.byType(DropdownButtonFormField<bool>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jellyfin').last);
        await tester.pumpAndSettle();
      }
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'http://servidor.test:8096');
      await tester.enterText(fields.at(1), 'alice');
      await tester.enterText(fields.at(2), '  senha &#+%  ');
      final sync = find.text('Testar conexão e sincronizar');
      await tester.ensureVisible(sync);
      await tester.tap(sync);
      await tester.pumpAndSettle();
      expect(repository.protocol, protocol);
      expect(repository.password, '  senha &#+%  ');
      expect(find.text('Conexão validada e catálogo sincronizado.'), findsOneWidget);
    });
  }
}
