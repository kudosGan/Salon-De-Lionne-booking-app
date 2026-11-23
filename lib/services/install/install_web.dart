import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Bumps whenever the browser says the app can be (or was) installed.
final ValueNotifier<int> installChanges = ValueNotifier(0);

bool _watching = false;

void startInstallWatcher() {
  if (_watching) return;
  _watching = true;
  web.window.addEventListener(
      'pwa-install-available', ((web.Event _) => installChanges.value++).toJS);
}

JSObject? get _pwa =>
    globalContext.getProperty<JSAny?>('__pwa'.toJS) as JSObject?;

JSObject? get _deferred => _pwa?.getProperty<JSAny?>('deferred'.toJS) as JSObject?;

String get _agent => web.window.navigator.userAgent;

/// Running as the installed app (home-screen icon), not in a browser tab.
bool get isStandalone {
  if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  final nav = web.window.navigator as JSObject;
  return nav.getProperty<JSAny?>('standalone'.toJS) == true.toJS;
}

bool get isIos =>
    RegExp(r'iPhone|iPad|iPod').hasMatch(_agent) ||
    // iPads that pretend to be Macs.
    (web.window.navigator.platform == 'MacIntel' &&
        web.window.navigator.maxTouchPoints > 1);

bool get isMobile => isIos || RegExp(r'Android|Mobile').hasMatch(_agent);

/// Chrome on Android is ready to show its one-tap install box.
bool get canPrompt => _deferred != null;

/// Shows the browser's install box. Returns true if the person accepted.
Future<bool> promptInstall() async {
  final event = _deferred;
  if (event == null) return false;
  event.callMethod<JSAny?>('prompt'.toJS);
  final choice = await event
      .getProperty<JSPromise<JSAny?>>('userChoice'.toJS)
      .toDart as JSObject;
  // The browser only lets the box be shown once per offer.
  _pwa?.setProperty('deferred'.toJS, null);
  installChanges.value++;
  return choice.getProperty<JSString>('outcome'.toJS).toDart == 'accepted';
}

const _key = 'install_prompt_dismissed';

DateTime? readInstallDismissed() {
  final raw = web.window.localStorage.getItem(_key);
  return raw == null ? null : DateTime.tryParse(raw);
}

void writeInstallDismissed(DateTime when) =>
    web.window.localStorage.setItem(_key, when.toIso8601String());

bool get isAndroid => RegExp(r'Android').hasMatch(_agent);

/// Reopens this same page in Chrome (Android only). Used when the page was
/// opened inside another app's browser, which cannot install websites.
void openInChrome() {
  final l = web.window.location;
  web.window.location.href =
      'intent://${l.host}${l.pathname}${l.search}#Intent;scheme=https;package=com.android.chrome;end';
}
