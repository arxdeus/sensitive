// The annotation consumed by the `sensitive` analyzer plugin.
//
// The rule identifies this annotation by its class name *and* by the fact that
// it is declared in the `sensitive` package, so renaming the
// class or its field is a breaking change for `lib/src/util/annotations.dart`.

/// Marks a declaration as holding a secret that must never reach a log, a
/// console, a string interpolation or an exception message.
///
/// The `sensitive_exposure` rule reports a reference to an annotated field,
/// getter, parameter, local variable or top-level variable when it is built
/// into a string, converted with `toString()`, passed to a logging sink such
/// as `print`, or put into an exception message.
///
/// ```dart
/// class Session {
///   @Sensitive()
///   final String token;
///
///   // Reported: the token would end up in the log.
///   void debug() => print('token: $token');
/// }
/// ```
///
/// Redact the value explicitly instead, for example by logging only its
/// length or a masked prefix.
final class Sensitive {
  /// Creates a [Sensitive] annotation.
  ///
  /// [reason] optionally documents why the value is secret, for example
  /// `@Sensitive('OAuth refresh token')`. It is shown in the diagnostic.
  const Sensitive([this.reason]);

  /// Why the value is secret, or `null` when no reason was given.
  final String? reason;
}
