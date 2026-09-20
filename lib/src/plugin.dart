import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:sensitive/src/rules/sensitive_exposure.dart';

/// The `sensitive` analyzer plugin.
///
/// The rule is registered as a warning rule, so it is enabled as soon as the
/// plugin is. It can be turned off from analysis options:
///
/// ```yaml
/// plugins:
///   sensitive:
///     diagnostics:
///       sensitive_exposure: false
/// ```
final class SensitiveExposurePlugin extends Plugin {
  @override
  String get name => 'sensitive';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(SensitiveExposureRule());
  }
}
