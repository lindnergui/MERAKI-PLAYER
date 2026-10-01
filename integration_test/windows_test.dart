import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meraki/main.dart' as app;
import 'package:meraki/src/app.dart';
import 'package:meraki/src/rust/api/music.dart' as rust_music;
import 'package:meraki/src/ui/screens/welcome_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows inicia a interface, indexa e carrega áudio local', (
    tester,
  ) async {
    await app.main();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MerakiApp), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    final meraki = tester.widget<MerakiApp>(find.byType(MerakiApp));
    final directory = await Directory.systemTemp.createTemp('meraki_windows_');
    final player = AudioPlayer();
    try {
      // Áudio sintético: nenhuma música ou credencial real entra nos testes.
      final audio = File('${directory.path}/Áudio de teste.wav');
      await audio.writeAsBytes(_silentWav());
      await rust_music.initDb(databasePath: '${directory.path}/catalog.sqlite3');
      final songs = await rust_music.scanLocalMusic(path: directory.path);
      expect(songs, hasLength(1));
      expect(songs.single.title, 'Áudio de teste');
      expect(await rust_music.getAllSongs(), hasLength(1));

      final duration = await player
          .setFilePath(songs.single.streamUrlOrFilePath)
          .timeout(const Duration(seconds: 30));
      expect(duration, isNotNull);
      expect(duration!.inSeconds, 2);
      await player.seek(const Duration(milliseconds: 500));
      expect(player.processingState, ProcessingState.ready);
      await meraki.audioHandler.updateMediaLibrary(songs);
      expect(tester.takeException(), isNull);
    } finally {
      await player.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await meraki.audioHandler.dispose();
      await meraki.repository.initialize();
      await directory.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}

Uint8List _silentWav() {
  const sampleRate = 44100;
  const dataSize = sampleRate * 2 * 2;
  final bytes = Uint8List(44 + dataSize);
  final header = ByteData.sublistView(bytes);
  void text(int offset, String value) => bytes.setRange(
    offset,
    offset + value.length,
    value.codeUnits,
  );
  text(0, 'RIFF');
  header.setUint32(4, 36 + dataSize, Endian.little);
  text(8, 'WAVEfmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  text(36, 'data');
  header.setUint32(40, dataSize, Endian.little);
  return bytes;
}
