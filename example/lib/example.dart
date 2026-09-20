// Run `dart pub get && dart analyze` in this directory to see the rule fire.
//
// Expected output: exactly one warning per line marked "reported" below.
import 'package:sensitive/sensitive.dart';

class Credentials {
  Credentials(this.token);

  /// The secret that must never be printed.
  @Sensitive('OAuth refresh token')
  final String token;

  /// Only derived, non-secret data is logged, so nothing is reported.
  void describe() => print('token length: ${token.length}');

  void debug() {
    // reported: sensitive_exposure, the token would land in the log.
    print('token: $token');
  }

  void convert() {
    // reported: sensitive_exposure, `toString()` is the same leak in
    // another spelling.
    print(token.toString());
  }

  void concatenate() {
    // reported: sensitive_exposure, `+` builds the same string an
    // interpolation would.
    print('token: ' + token);
  }

  void raise() {
    // reported: sensitive_exposure, an exception message is read by whoever
    // catches it and usually ends up in a log too.
    throw StateError('bad token: $token');
  }

  void suppressed() {
    // Diagnostics are suppressed with the plugin name as a prefix.
    // ignore: sensitive/sensitive_exposure
    print('token: $token');
  }
}

/// The annotation follows a field formal parameter back to its field, so a
/// secret passed through a constructor is still recognised.
class Wrapper {
  Wrapper(this.token);

  @Sensitive()
  final String token;

  void leak() {
    // reported: sensitive_exposure.
    print(token);
  }
}
