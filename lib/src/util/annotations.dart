import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin_toolkit/analyzer_plugin_toolkit.dart';

/// Finds this package's annotation, matching on the declaring package so that
/// a same-named `Sensitive` from somewhere else cannot drive the rule.
///
/// Shared by the whole rule, so that a declaration is inspected once no matter
/// how many references to it the file contains: the finder memoizes per
/// element, and the memo table lives as long as the element does.
final _annotations = AnnotationFinder('sensitive');

/// A `@Sensitive` annotation found on a declaration.
///
/// An absent annotation is represented by `null`, so "not annotated" and
/// "annotated without a reason" stay distinct without a sentinel value.
typedef SensitiveAnnotation = ({String? reason});

/// Returns the `@Sensitive` annotation on [element], or `null` when it is not
/// annotated.
///
/// The returned record's `reason` is the documented reason, and `null` for a
/// plain `@Sensitive()`.
SensitiveAnnotation? sensitiveAnnotation(Element? element) {
  final value = _annotations.valueOf(element, 'Sensitive');
  if (value == null) {
    return null;
  }
  return (reason: value.getField('reason')?.toStringValue());
}
