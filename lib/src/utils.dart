import 'dart:async';
import 'dart:html' as html;
import 'dart:js';

Future<dynamic> loadScript(String packageName, String url) async {
  if (context['define']['amd'] != null) {
    return loadScriptUsingRequireJS(packageName, url);
  } else {
    return loadScriptUsingScriptTag(url);
  }
}

Future<dynamic> loadScriptUsingScriptTag(String url) async {
  html.ScriptElement script = html.ScriptElement()
    ..type = 'text/javascript'
    ..src = url
    ..async = true
    ..defer = false;

  html.document.head!.append(script);

  return script.onLoad.first;
}

Future<dynamic> loadScriptUsingRequireJS(String packageName, String url) async {
  final Completer completer = Completer();
  final String eventName = '_${packageName}Loaded';

  context.callMethod('addEventListener', [eventName, allowInterop((_) => completer.complete())]);

  html.ScriptElement script = html.ScriptElement()
    ..type = 'text/javascript'
    ..async = false
    ..defer = false
    ..text = ''
        'require(["$url"], (package) => {'
        'window.$packageName = package;'
        'const event = new Event("$eventName");'
        'dispatchEvent(event);'
        '})'
        '';

  html.document.head!.append(script);

  return completer.future;
}
