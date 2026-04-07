import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:synk/synk.dart';

/// Signature for the builder callback used by [SynkBuilder].
typedef SynkWidgetBuilder<T> = Widget Function(BuildContext context, T data);

/// {@template synk_builder}
/// A generic widget that rebuilds its subtree in response to changes emitted
/// by any Synk type's [Stream].
///
/// [SynkBuilder] wraps a typed [Stream<T>] (for example, from [SynkMap.stream],
/// [SynkValue.stream], [SynkList.stream], etc.) and calls [builder] exactly
/// once per completed transaction that modifies the underlying data — never
/// more, regardless of how many operations the transaction contained.
///
/// An [initialData] value is required to guarantee a synchronous first frame
/// with no loading spinner. Because Synk types always hold a current resolved
/// value, you can simply pass the type's `.value` (or `.toMap()`, `.toString()`
/// etc.) at construction time.
///
/// Example:
/// ```dart
/// final title = SynkValue<String>(doc, 'title');
///
/// SynkBuilder<String?>(
///   stream: title.stream,
///   initialData: title.value,
///   builder: (context, value) {
///     return Text(value ?? 'Untitled');
///   },
/// )
/// ```
/// {@endtemplate}
class SynkBuilder<T> extends StatefulWidget {
  /// {@macro synk_builder}
  const SynkBuilder({
    required this.stream,
    required this.initialData,
    required this.builder,
    super.key,
  });

  /// The stream of values to listen to, typically sourced from a Synk type
  /// (e.g. [SynkValue.stream], [SynkMap.stream], [SynkList.stream]).
  final Stream<T> stream;

  /// The initial data to render on the first frame before any stream events
  /// have been emitted.
  ///
  /// Always pass the synk type's current resolved value here (e.g.
  /// `synkValue.value`, `synkMap.toMap()`, `synkList.toList()`).
  final T initialData;

  /// Called whenever a new value is available from [stream], or immediately
  /// on the first frame using [initialData].
  ///
  /// The `data` parameter is always fully resolved — it will never be null
  /// unless [T] itself is nullable.
  final SynkWidgetBuilder<T> builder;

  @override
  State<SynkBuilder<T>> createState() => _SynkBuilderState<T>();
}

class _SynkBuilderState<T> extends State<SynkBuilder<T>> {
  late StreamSubscription<T> _subscription;
  late T _currentData;

  @override
  void initState() {
    super.initState();
    _currentData = widget.initialData;
    _subscribe();
  }

  @override
  void didUpdateWidget(SynkBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _unsubscribe();
      _currentData = widget.initialData;
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.stream.listen((data) {
      if (mounted) {
        setState(() => _currentData = data);
      }
    });
  }

  void _unsubscribe() {
    _subscription.cancel();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _currentData);
}
