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
import 'package:video_player_web/src/shaka/shaka.dart' as shaka;
import 'package:video_player_web/src/utils.dart';
import 'package:video_player_web/src/video_element_player.dart';

const String _kMuxScriptUrl = 'https://cdnjs.cloudflare.com/ajax/libs/mux.js/5.10.0/mux.min.js';
const String _kShakaScriptUrl = kReleaseMode
    ? 'https://cdnjs.cloudflare.com/ajax/libs/shaka-player/4.1.0/shaka-player.compiled.min.js'
    : 'https://cdnjs.cloudflare.com/ajax/libs/shaka-player/4.1.0/shaka-player.compiled.debug.js';

class ShakaVideoPlayer extends VideoElementPlayer {
  ShakaVideoPlayer({
    required String src,
    String? drmType,
    String? drmUriLicense,
    Map<String, String>? drmHttpHeaders,
    bool withCredentials = false,
    @visibleForTesting StreamController<VideoEvent>? eventController,
  })  : _drmType = drmType,
        _drmUriLicense = drmUriLicense,
        _drmHttpHeaders = drmHttpHeaders,
        _withCredentials = withCredentials,
        super(src: src, eventController: eventController);

  late shaka.Player _player;

  final String? _drmType;
  final String? _drmUriLicense;
  final Map<String, String>? _drmHttpHeaders;
  final bool _withCredentials;

  bool get _hasDrm => _drmType != null && _drmUriLicense != null;

  String get _drmServer {
    if (_drmType == VideoDrmType.widevine) {
      return 'com.widevine.alpha';
    }

    return _drmType!;
  }

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
        message: 'Error loading Shaka Player: $_kShakaScriptUrl',
      ));
    }
  }

  Future<dynamic> _loadScript() async {
    if (shaka.isNotLoaded) {
      await loadScript('muxjs', _kMuxScriptUrl);
      await loadScript('shaka', _kShakaScriptUrl);
    }
  }

  Future<void> _afterLoadScript() async {
    videoElement
      // Set autoplay to false since most browsers won't autoplay a video unless it is muted
      ..autoplay = false
      ..controls = false;

    // Allows Safari iOS to play the video inline
    videoElement.setAttribute('playsinline', 'true');

    shaka.installPolyfills();

    if (shaka.Player.isBrowserSupported()) {
      _player = shaka.Player(videoElement);

      setupListeners();

      try {
        if (_hasDrm) {
          _player.configure(
            jsify({
              "drm": {
                "servers": {_drmServer: _drmUriLicense!}
              }
            }),
          );
        }

        _player.getNetworkingEngine().registerRequestFilter(allowInterop((type, request) {
          request.allowCrossSiteCredentials = _withCredentials;

          if (type == shaka.RequestType.license && _hasDrm && _drmHttpHeaders?.isNotEmpty == true) {
            request.headers = jsify(_drmHttpHeaders!);
          }
        }));

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
  @protected
  void setupListeners() {
    super.setupListeners();

    // Listen for error events.
    _player.addEventListener(
      'error',
      allowInterop((event) => _onShakaPlayerError(event.detail)),
    );
  }

  @override
  void dispose() {
    _player.destroy();
    super.dispose();
  }
}
