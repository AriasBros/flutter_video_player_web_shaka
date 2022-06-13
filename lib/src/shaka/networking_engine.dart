// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS('shaka')
library shaka;

// ignore: depend_on_referenced_packages
import 'package:js/js.dart';

@JS('net.NetworkingEngine')
class NetworkingEngine {
  external void registerRequestFilter(filter);
}

/*
extension NetworkingEngineExt on NetworkingEngine {
  void registerRequestFilter(RequestFilter filter) {
    privateRegisterRequestFilter(allowInterop(filter));
  }
}
*/
