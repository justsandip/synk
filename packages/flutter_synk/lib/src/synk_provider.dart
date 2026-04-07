import 'package:flutter/widgets.dart';
import 'package:synk/synk.dart';

/// {@template synk_provider}
/// An [InheritedWidget] that makes a [SynkDoc] available to all widgets
/// in its subtree.
///
/// Place [SynkProvider] near the root of your widget tree, then access
/// the document anywhere below it using [SynkProvider.docOf].
///
/// ```dart
/// SynkProvider(
///   doc: SynkDoc(),
///   child: MyApp(),
/// )
/// ```
/// {@endtemplate}
class SynkProvider extends InheritedWidget {
  /// {@macro synk_provider}
  const SynkProvider({required this.doc, required super.child, super.key});

  /// The [SynkDoc] made available to the subtree.
  final SynkDoc doc;

  /// Returns the nearest [SynkProvider] ancestor in the widget tree.
  ///
  /// Registers a dependency so the calling widget rebuilds when the
  /// [SynkProvider] instance itself changes (e.g. the [doc] is swapped out).
  ///
  /// Throws a [FlutterError] if no [SynkProvider] is found.
  static SynkProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SynkProvider>();
    if (provider == null) {
      throw FlutterError(
        'SynkProvider.of() was called with a context that does not contain '
        'a SynkProvider widget.\n'
        'Make sure to place a SynkProvider above the widget that calls '
        'SynkProvider.of().',
      );
    }
    return provider;
  }

  /// Directly returns the [SynkDoc] from the nearest [SynkProvider] ancestor.
  ///
  /// This is a convenience shorthand for `SynkProvider.of(context).doc`.
  static SynkDoc docOf(BuildContext context) => of(context).doc;

  @override
  bool updateShouldNotify(SynkProvider oldWidget) => doc != oldWidget.doc;
}
