// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS('shaka')
library shaka;

import 'dart:html' as html;
import 'dart:js';

// ignore: depend_on_referenced_packages
import 'package:js/js.dart';

@JS('polyfill.installAll')
external void installPollifills();

@JS()
class Player {
  external Player(html.VideoElement element);

  external static bool isBrowserSupported();

  external Future<void> load(String src);
  external Future<void> destroy();

  external void addEventListener(String event, Function callback);
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
