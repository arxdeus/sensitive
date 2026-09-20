/// The entry point of the `sensitive_exposure_lint` analyzer plugin.
///
/// The analysis server generates code that imports this library and reads the
/// top-level [plugin] variable, so neither the path of this file nor the name
/// of that variable may change.
library;

import 'package:sensitive_exposure_lint/src/plugin.dart';

/// The plugin instance loaded by the analysis server.
final plugin = SensitiveExposurePlugin();
