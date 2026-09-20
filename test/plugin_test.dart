import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/error/error.dart';
import 'package:sensitive_exposure_lint/main.dart' as entry_point;
import 'package:sensitive_exposure_lint/src/plugin.dart';
import 'package:sensitive_exposure_lint/src/rules/sensitive_exposure.dart';
import 'package:test/test.dart';

void main() {
  group('SensitiveExposurePlugin', () {
    test('exposes a plugin instance from the generated entry point', () {
      // The analysis server generates code that imports `lib/main.dart` and
      // reads this top-level variable, so its name and type are part of the
      // contract with the server.
      expect(entry_point.plugin, isA<SensitiveExposurePlugin>());
      expect(entry_point.plugin.name, 'sensitive_exposure_lint');
    });

    test('registers exactly the one rule, as a warning', () {
      final registry = _RecordingRegistry();
      SensitiveExposurePlugin().register(registry);

      // Exact equality, not `containsAll`: registering an extra or duplicate
      // rule is a defect this test must catch.
      expect(registry.warningRuleNames, ['sensitive_exposure']);

      // Warning rules are on as soon as the plugin is enabled; lint rules
      // would silently require opt-in from every consumer.
      expect(registry.lintRuleNames, isEmpty);
    });

    test('registers no quick fix', () {
      // The rule deliberately offers none: redacting a secret is a judgement
      // about what may safely be shown, which no mechanical rewrite can make.
      final registry = _RecordingRegistry();
      SensitiveExposurePlugin().register(registry);

      expect(registry.fixes, isEmpty);
    });

    test('declares one diagnostic code, matching the rule name', () {
      // The code's name is what appears in
      // `// ignore: sensitive_exposure_lint/<name>` and in the `diagnostics:`
      // section, so it must track the rule name.
      final rule = SensitiveExposureRule();
      expect(rule.diagnosticCodes, hasLength(1));
      final code = rule.diagnosticCodes.single;
      expect(code.lowerCaseName, rule.name);
      expect(code.severity, DiagnosticSeverity.WARNING);
    });

    test('reuses one diagnostic code instance', () {
      // The analysis server matches diagnostics by code identity. Handing out
      // a fresh instance per call breaks `// ignore:` suppression, which no
      // rule-behaviour test would notice.
      expect(
        identical(
          SensitiveExposureRule().diagnosticCode,
          SensitiveExposureRule().diagnosticCode,
        ),
        isTrue,
      );
    });
  });
}

/// A [PluginRegistry] that records what a plugin registers, in order.
///
/// Used instead of the real registry so that the assertions cannot be
/// satisfied by rules some other test already registered globally.
final class _RecordingRegistry implements PluginRegistry {
  final List<String> warningRuleNames = [];
  final List<String> lintRuleNames = [];

  /// Each registered fix, as the diagnostic's name paired with the generator
  /// the plugin supplied for it.
  final List<(String, Object?)> fixes = [];

  @override
  void registerWarningRule(AbstractAnalysisRule rule) =>
      warningRuleNames.add(rule.name);

  @override
  void registerLintRule(AbstractAnalysisRule rule) =>
      lintRuleNames.add(rule.name);

  @override
  void registerFixForRule(DiagnosticCode code, Object? generator) =>
      fixes.add((code.lowerCaseName, generator));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected ${invocation.memberName}');
}
