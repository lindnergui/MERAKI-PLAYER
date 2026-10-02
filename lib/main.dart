import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'package:meraki/src/app.dart';
import 'package:meraki/src/audio/meraki_audio_handler.dart';
import 'package:meraki/src/data/music_repository.dart';
import 'package:meraki/src/data/user_preferences.dart';
import 'package:meraki/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required by the looping video on WelcomeScreen. The initialization is
  // idempotent, so just_audio_media_kit can safely initialize afterwards.
  MediaKit.ensureInitialized();

  final userPreferences = UserPreferences();
  final initialUserName = await userPreferences.readUserName();

  // Keep artwork decoding bounded on phones with large libraries. ImageProvider
  // still reuses Flutter's built-in cache; this only limits its memory budget.
  PaintingBinding.instance.imageCache
    ..maximumSize = 120
    ..maximumSizeBytes = 32 << 20;

  // Compartilha o backend nativo de áudio entre Linux e Windows.
  // O Android continua usando seu backend existente.
  if (Platform.isLinux || Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized();
  }

  await RustLib.init();

  final repository = MusicRepository.instance;
  await repository.initialize();

  final audioHandler = await AudioService.init<MerakiAudioHandler>(
    builder: () => MerakiAudioHandler(repository: repository),
    config: const AudioServiceConfig(
      // On Linux, audio_service_mpris derives the MPRIS D-Bus name from this
      // identifier. Keep it aligned with the Flatpak application ID so the
      // filtered session bus can publish the MediaSession/MPRIS service.
      androidNotificationChannelId: 'com.github.lindnergui.meraki',
      androidNotificationChannelName: 'Reprodução do Meraki',
      androidNotificationChannelDescription:
          'Controles de reprodução de música do Meraki.',
      androidNotificationIcon: 'drawable/ic_stat_meraki',
      notificationColor: Color(0xFFA855F7),
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  await audioHandler.refreshMediaLibrary();

  runApp(
    MerakiApp(
      repository: repository,
      audioHandler: audioHandler,
      userPreferences: userPreferences,
      initialUserName: initialUserName,
    ),
  );
}
