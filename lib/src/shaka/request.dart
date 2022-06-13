// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS('shaka')
library shaka;

import 'dart:js';

// ignore: depend_on_referenced_packages
import 'package:js/js.dart';

class RequestType {
  static const manifest = 0;
  static const segment = 1;
  static const license = 2;
  static const app = 3;
  static const timing = 4;
  static const serverCertificate = 5;
}

typedef RequestFilter = void Function(int requestType, Request request);

/// https://shaka-player-demo.appspot.com/docs/api/shaka.extern.html#.Request
@JS('extern.Request')
class Request {
  external List<String> uris;
  external String method;
  external JsObject headers;
  external bool allowCrossSiteCredentials;
  external String? licenseRequestType;
  external String? sessionId;
  external String? initDataType;
}
