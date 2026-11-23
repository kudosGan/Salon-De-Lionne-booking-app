// One import for "install the app" features. In a browser this talks to the
// browser; everywhere else it does nothing.
export 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';
export 'install_policy.dart';
