import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:meraki/src/audio/meraki_audio_handler.dart';
import 'package:meraki/src/rust/models/song.dart';
import 'package:permission_handler/permission_handler.dart';

/// Reactive projection of the handler's MediaItem and PlaybackState streams.
///
/// Position ticks are derived from [PlaybackState.position], not read from the
/// internal just_audio player, keeping the app, notification and MPRIS in sync.
class PlayerController extends ChangeNotifier {
  PlayerController({required MerakiAudioHandler audioHandler})
    : _audioHandler = audioHandler {
    _mediaItemSubscription = _audioHandler.mediaItem.listen((item) {
      currentItem.value = item;
      _updateProjectedPosition();
      notifyListeners();
    });
    _playbackStateSubscription = _audioHandler.playbackState.listen((state) {
      playbackState.value = state;
      _updateProjectedPosition();
      notifyListeners();
    });
    _volumeSubscription = _audioHandler.volumeStream.listen((value) {
      volume.value = value;
    });
    _upNextSubscription = _audioHandler.upNextStream.listen((items) {
      upNext.value = items;
    });
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _updateProjectedPosition(),
    );
  }

  final MerakiAudioHandler _audioHandler;
  final ValueNotifier<MediaItem?> currentItem = ValueNotifier<MediaItem?>(null);
  final ValueNotifier<PlaybackState> playbackState =
      ValueNotifier<PlaybackState>(PlaybackState());
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );

  /// Tracks queued after the current one, in play order.
  final ValueNotifier<List<MediaItem>> upNext =
      ValueNotifier<List<MediaItem>>(const <MediaItem>[]);
  late final ValueNotifier<double> volume = ValueNotifier<double>(
    _audioHandler.volume,
  );
  late final StreamSubscription<MediaItem?> _mediaItemSubscription;
  late final StreamSubscription<PlaybackState> _playbackStateSubscription;
  late final StreamSubscription<double> _volumeSubscription;
  late final StreamSubscription<List<MediaItem>> _upNextSubscription;
  late final Timer _positionTimer;

  bool get isPlaying => playbackState.value.playing;
  bool get hasActiveItem => currentItem.value != null;
  bool get isShuffleEnabled =>
      playbackState.value.shuffleMode != AudioServiceShuffleMode.none;
  AudioServiceRepeatMode get repeatMode => playbackState.value.repeatMode;

  Future<void> playFromCatalog(Song song, List<Song> queue) async {
    await _ensureAndroidNotificationPermission();
    final index = queue.indexWhere((entry) => entry.id == song.id);
    await _audioHandler.playQueue(queue, initialIndex: index < 0 ? 0 : index);
  }

  /// Android 13+ keeps media notifications behind POST_NOTIFICATIONS.
  /// Request it only while it is still requestable; playback remains usable
  /// when the user has permanently declined the permission.
  Future<void> _ensureAndroidNotificationPermission() async {
    if (!Platform.isAndroid) return;

    final status = await Permission.notification.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> togglePlayPause() {
    return isPlaying ? _audioHandler.pause() : _audioHandler.play();
  }

  Future<void> seek(Duration value) => _audioHandler.seek(value);
  Future<void> setVolume(double value) => _audioHandler.setVolume(value);
  Future<void> skipNext() => _audioHandler.skipToNext();
  Future<void> skipPrevious() => _audioHandler.skipToPrevious();

  /// Jumps straight to [item] when it is part of the active queue.
  Future<void> skipToItem(MediaItem item) async {
    final index = _audioHandler.queue.value.indexWhere(
      (entry) => entry.id == item.id,
    );
    if (index >= 0) await _audioHandler.skipToQueueItem(index);
  }

  Future<void> toggleShuffle() {
    return _audioHandler.setShuffleMode(
      isShuffleEnabled
          ? AudioServiceShuffleMode.none
          : AudioServiceShuffleMode.all,
    );
  }

  Future<void> cycleRepeatMode() {
    final next = switch (repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
    };
    return _audioHandler.setRepeatMode(next);
  }

  void _updateProjectedPosition() {
    final item = currentItem.value;
    var projected = playbackState.value.position;
    final duration = item?.duration;
    if (duration != null && projected > duration) {
      projected = duration;
    }
    if (position.value != projected) {
      position.value = projected;
    }
  }

  @override
  void dispose() {
    _positionTimer.cancel();
    _mediaItemSubscription.cancel();
    _playbackStateSubscription.cancel();
    _volumeSubscription.cancel();
    _upNextSubscription.cancel();
    currentItem.dispose();
    playbackState.dispose();
    position.dispose();
    volume.dispose();
    upNext.dispose();
    super.dispose();
  }
}
