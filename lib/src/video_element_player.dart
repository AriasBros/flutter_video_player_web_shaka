// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_web/src/video_player.dart';

import '../src/shims/dart_ui.dart' as ui;

// An error code value to error name Map.
// See: https://developer.mozilla.org/en-US/docs/Web/API/MediaError/code
const Map<int, String> _kErrorValueToErrorName = <int, String>{
  1: 'MEDIA_ERR_ABORTED',
  2: 'MEDIA_ERR_NETWORK',
  3: 'MEDIA_ERR_DECODE',
  4: 'MEDIA_ERR_SRC_NOT_SUPPORTED',
};

// An error code value to description Map.
// See: https://developer.mozilla.org/en-US/docs/Web/API/MediaError/code
const Map<int, String> _kErrorValueToErrorDescription = <int, String>{
  1: 'The user canceled the fetching of the video.',
  2: 'A network error occurred while fetching the video, despite having previously been available.',
  3: 'An error occurred while trying to decode the video, despite having previously been determined to be usable.',
  4: 'The video has been found to be unsuitable (missing or in a format not supported by your browser).',
};

// The default error message, when the error is an empty string
// See: https://developer.mozilla.org/en-US/docs/Web/API/MediaError/message
const String _kDefaultErrorMessage = 'No further diagnostic information can be determined or provided.';

abstract class VideoElementPlayer implements VideoPlayer {
  /// Create a [VideoElementPlayer] from a [html.VideoElement] instance.
  VideoElementPlayer({
    required String src,
    StreamController<VideoEvent>? eventController,
  })  : _src = src,
        _eventController = eventController ?? StreamController<VideoEvent>();

  final String _src;
  final StreamController<VideoEvent> _eventController;
  late html.VideoElement _videoElement;
  bool _isBuffering = false;
  bool _isInitialized = false;

  @protected
  bool get isInitialized => _isInitialized;

  @override
  String get src => _src;

  StreamController<VideoEvent> get eventController => _eventController;
  html.VideoElement get videoElement => _videoElement;

  /// Returns the [Stream] of [VideoEvent]s.
  @override
  Stream<VideoEvent> get events => _eventController.stream;

  /// Creates the [html.VideoElement].
  html.VideoElement createElement(int textureId);

  /// Registers the [html.VideoElement].
  @override
  void registerElement(int textureId) {
    _videoElement = createElement(textureId);

    // TODO(hterkelsen): Use initialization parameters once they are available
    ui.platformViewRegistry.registerViewFactory(_videoElement.id, (int viewId) => _videoElement);
  }

  @protected
  void setupListeners() {
    videoElement.onCanPlay.listen((dynamic _) => markAsInitializedIfNeeded());

    videoElement.onCanPlayThrough.listen((dynamic _) {
      setBuffering(false);
    });

    videoElement.onPlaying.listen((dynamic _) {
      setBuffering(false);
    });

    videoElement.onWaiting.listen((dynamic _) {
      setBuffering(true);
      _sendBufferingRangesUpdate();
    });

    // The error event fires when some form of error occurs while attempting to load or perform the media.
    videoElement.onError.listen((html.Event _) {
      setBuffering(false);
      // The Event itself (_) doesn't contain info about the actual error.
      // We need to look at the HTMLMediaElement.error.
      // See: https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/error
      final html.MediaError error = videoElement.error!;

      eventController.addError(PlatformException(
        code: _kErrorValueToErrorName[error.code]!,
        message: error.message != '' ? error.message : _kDefaultErrorMessage,
        details: _kErrorValueToErrorDescription[error.code],
      ));
    });

    videoElement.onEnded.listen((dynamic _) {
      setBuffering(false);
      eventController.add(VideoEvent(eventType: VideoEventType.completed));
    });
  }

  /// Attempts to play the video.
  ///
  /// If this method is called programmatically (without user interaction), it
  /// might fail unless the video is completely muted (or it has no Audio tracks).
  ///
  /// When called from some user interaction (a tap on a button), the above
  /// limitation should disappear.
  @override
  Future<void> play() {
    return videoElement.play().catchError((Object e) {
      // play() attempts to begin playback of the media. It returns
      // a Promise which can get rejected in case of failure to begin
      // playback for any reason, such as permission issues.
      // The rejection handler is called with a DomException.
      // See: https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/play
      final html.DomException exception = e as html.DomException;
      _eventController.addError(PlatformException(
        code: exception.name,
        message: exception.message,
      ));
    }, test: (Object e) => e is html.DomException);
  }

  /// Pauses the video in the current position.
  @override
  void pause() {
    videoElement.pause();
  }

  /// Controls whether the video should start again after it finishes.
  @override
  void setLooping(bool value) {
    videoElement.loop = value;
  }

  /// Sets the volume at which the media will be played.
  ///
  /// Values must fall between 0 and 1, where 0 is muted and 1 is the loudest.
  ///
  /// When volume is set to 0, the `muted` property is also applied to the
  /// [html.VideoElement]. This is required for auto-play on the web.
  @override
  void setVolume(double volume) {
    assert(volume >= 0 && volume <= 1);

    // TODO(ditman): Do we need to expose a "muted" API?
    // https://github.com/flutter/flutter/issues/60721
    videoElement.muted = !(volume > 0.0);
    videoElement.volume = volume;
  }

  /// Sets the playback `speed`.
  ///
  /// A `speed` of 1.0 is "normal speed," values lower than 1.0 make the media
  /// play slower than normal, higher values make it play faster.
  ///
  /// `speed` cannot be negative.
  ///
  /// The audio is muted when the fast forward or slow motion is outside a useful
  /// range (for example, Gecko mutes the sound outside the range 0.25 to 4.0).
  ///
  /// The pitch of the audio is corrected by default.
  @override
  void setPlaybackSpeed(double speed) {
    assert(speed > 0);

    _videoElement.playbackRate = speed;
  }

  /// Moves the playback head to a new `position`.
  ///
  /// `position` cannot be negative.
  @override
  void seekTo(Duration position) {
    assert(!position.isNegative);

    videoElement.currentTime = position.inMilliseconds.toDouble() / 1000;
  }

  /// Returns the current playback head position as a [Duration].
  @override
  Duration getPosition() {
    _sendBufferingRangesUpdate();
    return Duration(milliseconds: (videoElement.currentTime * 1000).round());
  }

  /// Disposes of the current [html.VideoElement].
  @override
  void dispose() {
    _videoElement.removeAttribute('src');
    _videoElement.load();
  }

  // Sends an [VideoEventType.initialized] [VideoEvent] with info about the wrapped video.
  @protected
  void markAsInitializedIfNeeded() {
    if (!_isInitialized) {
      _isInitialized = true;
      _sendInitialized();
    }
  }

  void _sendInitialized() {
    final Duration? duration = !_videoElement.duration.isNaN
        ? Duration(
            milliseconds: (_videoElement.duration * 1000).round(),
          )
        : null;

    final Size? size = !_videoElement.videoHeight.isNaN
        ? Size(
            _videoElement.videoWidth.toDouble(),
            _videoElement.videoHeight.toDouble(),
          )
        : null;

    _eventController.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: size,
      ),
    );
  }

  /// Caches the current "buffering" state of the video.
  ///
  /// If the current buffering state is different from the previous one
  /// ([_isBuffering]), this dispatches a [VideoEvent].
  @protected
  @visibleForTesting
  void setBuffering(bool buffering) {
    if (_isBuffering != buffering) {
      _isBuffering = buffering;
      _eventController.add(VideoEvent(
        eventType: _isBuffering ? VideoEventType.bufferingStart : VideoEventType.bufferingEnd,
      ));
    }
  }

  // Broadcasts the [html.VideoElement.buffered] status through the [events] stream.
  void _sendBufferingRangesUpdate() {
    _eventController.add(VideoEvent(
      buffered: _toDurationRange(_videoElement.buffered),
      eventType: VideoEventType.bufferingUpdate,
    ));
  }

  // Converts from [html.TimeRanges] to our own List<DurationRange>.
  List<DurationRange> _toDurationRange(html.TimeRanges buffered) {
    final List<DurationRange> durationRange = <DurationRange>[];
    for (int i = 0; i < buffered.length; i++) {
      durationRange.add(DurationRange(
        Duration(milliseconds: (buffered.start(i) * 1000).round()),
        Duration(milliseconds: (buffered.end(i) * 1000).round()),
      ));
    }
    return durationRange;
  }
}
