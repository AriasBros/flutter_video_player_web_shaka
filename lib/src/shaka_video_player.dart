// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:js';
import 'dart:js_util';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_web/src/shaka.dart' as shaka;
import 'package:video_player_web/src/utils.dart';
import 'package:video_player_web/src/video_element_player.dart';

const String _kPackageName = 'shaka';
const String _kScriptUrl = 'https://cdnjs.cloudflare.com/ajax/libs/shaka-player/4.1.0/shaka-player.compiled.min.js';

class ShakaVideoPlayer extends VideoElementPlayer {
  ShakaVideoPlayer({
    required String src,
    @visibleForTesting StreamController<VideoEvent>? eventController,
  }) : super(src: src, eventController: eventController);

  late shaka.Player _player;

  @override
  html.VideoElement createElement(int textureId) {
    return html.VideoElement()
      ..id = 'videoPlayer-$textureId'
      ..style.border = 'none'
      ..style.height = '100%'
      ..style.width = '100%';
  }

  @override
  Future<void> initialize() async {
    try {
      await _loadScript();
      await _afterLoadScript();
    } on html.Event catch (ex) {
      eventController.addError(PlatformException(
        code: ex.type,
        message: 'Error loading Shaka Player: $_kScriptUrl',
      ));
    }
  }

  Future<dynamic> _loadScript() async {
    if (shaka.isNotLoaded) {
      if (context['define']['amd'] != null) {
        return loadScriptUsingRequireJS(_kPackageName, _kScriptUrl);
      } else {
        return loadScriptUsingScriptTag(_kScriptUrl);
      }
    }
  }

  Future<void> _afterLoadScript() async {
    videoElement
      ..autoplay = false
      ..controls = false;

    // Allows Safari iOS to play the video inline
    videoElement.setAttribute('playsinline', 'true');

    // Set autoplay to false since most browsers won't autoplay a video unless it is muted
    videoElement.setAttribute('autoplay', 'false');

    setupElementListeners();
    shaka.installPolyfills();

    if (shaka.Player.isBrowserSupported()) {
      _player = shaka.Player(videoElement);

      // Listen for error events.
      _player.addEventListener(
        'error',
        allowInterop((event) => _onShakaPlayerError(event.detail)),
      );

      try {
        await promiseToFuture(_player.load(src));
      } on shaka.Error catch (ex) {
        _onShakaPlayerError(ex);
      }
    } else {
      throw UnsupportedError('web implementation of video_player does not support your browser');
    }
  }

  void _onShakaPlayerError(shaka.Error error) {
    eventController.addError(PlatformException(
      code: shaka.errorCodeName(error.code),
      message: shaka.errorCategoryName(error.category),
      details: error,
    ));
  }

  @override
  void dispose() {
    _player.destroy();
    super.dispose();
  }
}
