import 'package:flutter/foundation.dart';

// Used outside the browser (phone app, tests): there is nothing to install.

final ValueNotifier<int> installChanges = ValueNotifier(0);

void startInstallWatcher() {}

bool get isStandalone => false;
bool get isMobile => false;
bool get isIos => false;
bool get canPrompt => false;

Future<bool> promptInstall() async => false;

DateTime? _dismissed;
DateTime? readInstallDismissed() => _dismissed;
void writeInstallDismissed(DateTime when) => _dismissed = when;

bool get isAndroid => false;
void openInChrome() {}
