// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:video_player_platform_interface/video_player_platform_interface.dart';

abstract class VideoPlayer {
  const VideoPlayer();

  String get src;
  Stream<VideoEvent> get events;

  void registerElement(int textureId);

  Future<void> initialize();

  Future<void> play();

  void pause();

  void setLooping(bool value);

  void setVolume(double volume);

  void setPlaybackSpeed(double speed);

  void seekTo(Duration position);

  Duration getPosition();

  Future<List<TrackSelection>> getTrackSelections({
    TrackSelectionNameResource? trackSelectionNameResource,
  });

  Future<void> setTrackSelection(TrackSelection trackSelection);

  void dispose();
}
