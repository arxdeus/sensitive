import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin_toolkit/analyzer_plugin_toolkit.dart';
import 'package:sensitive/src/util/annotations.dart';

/// Method names that are treated as logging sinks when called on any target.
///
/// Deliberately name-based: loggers live in other packages (`logging`,
/// `logger`, `talker`, a hand-rolled `Log` class), and a secret reaching any
/// of them is a leak regardless of which one it is.
const loggingMethodNames = {
  'print',
  'debugPrint',
  'log',
  'logs',
  'trace',
  'verbose',
  'debug',
  'info',
  'config',
  'fine',
  'finer',
  'finest',
  'warn',
  'warning',
  'error',
  'severe',
  'shout',
  'fatal',
  'wtf',
  'write',
  'writeln',
  'writeAll',
  'addError',
};

/// Memoizes whether a class is an `Exception` or an `Error`.
final _throwableCache = ElementCache<InterfaceElement, bool>('throwable');

/// Reports references to `@Sensitive` declarations that would expose the value
/// in a string, a `toString()`, a log call or an exception message.
final class SensitiveExposureRule extends AnalysisRule {
  /// Creates the rule.
  SensitiveExposureRule()
    : super(
        name: 'sensitive_exposure',
        description:
            'Values annotated with @Sensitive should not be interpolated, '
            'stringified, logged or put into exception messages.',
      );

  /// The diagnostic reported by this rule.
  ///
  /// Declared as a single `static const` so that the analysis server can match
  /// the code, which is what makes `// ignore: sensitive/sensitive_exposure`
  /// work.
  static const LintCode code = LintCode(
    'sensitive_exposure',
    "'{0}' is annotated with '@Sensitive'{1}, so it must not be {2}.",
    correctionMessage:
        'Try redacting the value first, for example by logging only its '
        'length or a masked prefix.',
    uniqueName: 'LintCode.sensitive_exposure',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addInterpolationExpression(this, visitor)
      ..addBinaryExpression(this, visitor)
      ..addMethodInvocation(this, visitor)
      ..addInstanceCreationExpression(this, visitor);
  }
}

/// How a sensitive value escapes, as it appears in the diagnostic message.
enum _Exposure {
  interpolation('interpolated into a string'),
  concatenation('concatenated into a string'),
  toStringCall("converted with 'toString()'"),
  logging('passed to a logging sink'),
  thrown('put into an exception message');

  const _Exposure(this.description);

  /// The phrase used in the message.
  final String description;
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  /// One alias resolver per enclosing function body, so that a body is walked
  /// once no matter how many exposures it contains.
  final Map<AstNode, AliasResolver> _resolvers = {};

  @override
  void visitInterpolationExpression(InterpolationExpression node) =>
      _check(node.expression, _Exposure.interpolation);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    // `'token: ' + token` builds the same string an interpolation would, so
    // it has to be caught too. Only `+` on strings is a concatenation; `a + b`
    // on numbers cannot leak the value into text.
    if (node.operator.lexeme != '+' ||
        !(node.staticType?.isDartCoreString ?? false)) {
      return;
    }
    _check(node.leftOperand, _Exposure.concatenation);
    _check(node.rightOperand, _Exposure.concatenation);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'toString') {
      _check(node.realTarget, _Exposure.toStringCall);
      return;
    }
    if (!loggingMethodNames.contains(node.methodName.name)) {
      return;
    }
    for (final argument in node.argumentList.arguments) {
      _check(argument.argumentExpression, _Exposure.logging);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!_isThrowable(node.constructorName.type.type)) {
      return;
    }
    for (final argument in node.argumentList.arguments) {
      _check(argument.argumentExpression, _Exposure.thrown);
    }
  }

  /// Whether [type] is an `Exception` or an `Error`.
  ///
  /// Both are checked structurally, so user-defined types that `implements
  /// Exception` are covered, which is the common Dart idiom.
  ///
  /// Memoized per class: this runs on every `new` in the program, and whether
  /// a class is throwable is a fact about the class.
  bool _isThrowable(DartType? type) {
    if (type is! InterfaceType) {
      return false;
    }
    return _throwableCache.of(type.element, () {
      final InterfaceElement element = type.element;
      if (_isCoreThrowable(element)) {
        return true;
      }
      for (final InterfaceType supertype in element.allSupertypes) {
        if (_isCoreThrowable(supertype.element)) {
          return true;
        }
      }
      return false;
    });
  }

  /// Whether [element] is `dart:core`'s own `Exception` or `Error`.
  bool _isCoreThrowable(InterfaceElement element) {
    final name = element.name;
    if (name != 'Exception' && name != 'Error') {
      return false;
    }
    return element.library.isDartCore;
  }

  /// Reports [expression] when it may refer to a `@Sensitive` declaration.
  void _check(Expression? expression, _Exposure exposure) {
    if (expression == null) {
      return;
    }
    for (final element in _resolve(expression)) {
      final annotation =
          sensitiveAnnotation(element) ??
          sensitiveAnnotation(_backingField(element)) ??
          sensitiveAnnotation(_backingGetter(element));
      if (annotation == null) {
        continue;
      }
      final reason = annotation.reason;
      rule.reportAtNode(
        expression,
        arguments: [
          element.name ?? expression.toString(),
          if (reason == null) '' else ' ($reason)',
          exposure.description,
        ],
      );
      // One diagnostic per expression: a conditional that yields two secrets
      // is still a single leak to fix.
      return;
    }
  }

  /// Returns the field behind a field formal parameter (`this.token`), so that
  /// the annotation on the field also covers the constructor parameter.
  Element? _backingField(Element element) =>
      element is FieldFormalParameterElement ? element.field : null;

  /// Returns the getter behind [element], so that `@Sensitive` written on an
  /// explicit `get token` is found.
  ///
  /// Reading a property always resolves to its accessor, which
  /// [normalizeElement] maps back onto the variable. For a field that variable
  /// carries the annotation, but for an explicit getter the variable is
  /// synthetic and the annotation stays on the accessor.
  Element? _backingGetter(Element element) =>
      element is PropertyInducingElement ? element.getter : null;

  /// Returns every declaration [expression] may refer to, following local
  /// aliases inside the enclosing function body.
  Set<Element> _resolve(Expression expression) {
    final body = expression.thisOrAncestorOfType<FunctionBody>();
    if (body == null) {
      final element = referencedElement(expression, anyTarget: true);
      return element == null ? const {} : {element};
    }
    final resolver = _resolvers.putIfAbsent(
      body,
      () => AliasResolver.forBody(body, anyTarget: true),
    );
    final resolved = resolver.resolve(expression);
    if (resolved.isNotEmpty) {
      return resolved;
    }
    // A local that is reassigned resolves to nothing; fall back to the direct
    // reference so that an annotated local is still reported.
    final element = referencedElement(expression, anyTarget: true);
    return element == null ? const {} : {element};
  }
}
