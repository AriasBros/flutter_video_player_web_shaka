// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS('shaka')
library shaka;

import 'dart:html' as html;

// ignore: depend_on_referenced_packages
import 'package:js/js.dart';
import 'package:video_player_web/src/shaka/networking_engine.dart';

@JS()
class Player {
  external Player(html.VideoElement element);

  external static bool isBrowserSupported();

  external bool configure(Object config);
  external Future<void> load(String src);
  external Future<void> destroy();

  external NetworkingEngine getNetworkingEngine();

  external void addEventListener(String event, Function callback);
}
