// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS('shaka')
library shaka;

// ignore: depend_on_referenced_packages
import 'package:js/js.dart';

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
