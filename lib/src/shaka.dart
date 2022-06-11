// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS('shaka')
library shaka;

import 'dart:html' as html;
import 'dart:js';

import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:js/js.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

bool get isLoaded => context.hasProperty('shaka');
bool get isNotLoaded => !isLoaded;

@JS('polyfill.installAll')
external void installPolyfills();

@JS()
class Player {
  external Player(html.VideoElement element);

  external static bool isBrowserSupported();

  external Future<void> load(String src);
  external Future<void> destroy();

  external bool configure(Object configuration);

  external List<LanguageRole> getAudioLanguagesAndRoles();
  external List<LanguageRole> getTextLanguagesAndRoles();

  external List<Track> getChaptersTracks();
  external List<Track> getImageTracks();
  external List<Track> getTextTracks();
  external List<Track> getVariantTracks();

  external void selectAudioLanguage(String language, [String? role]);
  external void selectTextLanguage(String language, [String? role, bool forced = false]);

  external void addEventListener(String event, Function callback);
}

@JS('extern.LanguageRole')
@anonymous
class LanguageRole {
  external String get language;
  external String get role;
  external String? get label;

  external factory LanguageRole({
    String language,
    String role,
    String? label,
  });
}

extension LanguageRoleExtension on LanguageRole {
  TrackSelection toTrackSelection() {
    return TrackSelection(
      trackId: language,
      trackType: role == 'subtitle' ? TrackSelectionType.text : TrackSelectionType.audio,
      trackName: label ?? language, // TODO
      isSelected: false, // TODO
      label: label,
      language: language,
      role: TrackSelectionRoleType.supplementary,
    );
  }
}

@JS('extern.Track')
@anonymous
class Track {
  external int get id;
  external bool get active;
  external String get type;
  external int get bandwidth;
  external String get language;
  external String? get label;
  external String? get kind;
  external double? get width;
  external double? get height;
  external int? get channelsCount;
  external List<String>? get roles;
  external List<String>? get audioRoles;

  external factory Track({
    int id,
    bool active,
    String type,
    double bandwidth,
    String language,
    String? label,
    String? kind,
    double? width,
    double? height,
    int? channelsCount,
    List<String>? roles,
    List<String>? audioRoles,
  });
}

extension TrackExtension on Track {
  TrackSelection toTrackSelection() {
    return TrackSelection(
      trackId: id.toString(),
      trackType: trackSelectionType,
      trackName: label ?? 'TODO', // TODO
      isSelected: active,
      label: label,
      language: language,
      channel: channelType,
      bitrate: bandwidth,
      size: size,
      role: role,
    );
  }

  TrackSelectionRoleType get role {
    if (roles?.contains('caption') == true) {
      return TrackSelectionRoleType.closedCaptions;
    }

    if (roles?.contains('commentary') == true || audioRoles?.contains('commentary') == true) {
      return TrackSelectionRoleType.commentary;
    }

    return TrackSelectionRoleType.alternate;
  }

  Size? get size {
    if (width != null && height != null) {
      return Size(width!, height!);
    } else if (width != null) {
      return Size.fromWidth(width!);
    } else if (height != null) {
      return Size.fromHeight(height!);
    }

    return null;
  }

  TrackSelectionChannelType get channelType {
    if (channelsCount == null || channelsCount == 2) {
      return TrackSelectionChannelType.stereo;
    } else if (channelsCount == 1) {
      return TrackSelectionChannelType.mono;
    }

    return TrackSelectionChannelType.surround;
  }

  TrackSelectionType get trackSelectionType {
    switch (type) {
      case 'variant':
        return TrackSelectionType.audio;
      case 'text':
        return TrackSelectionType.text;
      case 'image':
        return TrackSelectionType.video;

      default:
        return TrackSelectionType.audio;
    }
  }
}

/// https://shaka-player-demo.appspot.com/docs/api/shaka.util.Error.html
@JS('util.Error')
class Error {
  @JS('Code')
  external static dynamic get codes;

  @JS('Category')
  external static dynamic get categories;

  @JS('Severity')
  external static dynamic get severities;

  external int get code;
  external int get category;
  external int get severity;
}

String errorCodeName(int code) {
  return _findName(context['shaka']['util']['Error']['Code'], code);
}

String errorCategoryName(int category) {
  return _findName(context['shaka']['util']['Error']['Category'], category);
}

String _findName(JsObject object, int value) {
  final List keys = context['Object'].callMethod('keys', [object]);

  try {
    return keys.firstWhere((k) => object[k] == value);
  } catch (_) {
    return '';
  }
}
