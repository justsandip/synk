import 'package:synk/synk.dart';

/// {@template synk_string}
/// A collaborative single-value string register.
///
/// [SynkString] implements a Last-Writer-Wins (LWW) Register.
/// When two users modify the string concurrently, the one with the higher
/// logical clock (or client ID tie-breaker) wins.
/// {@endtemplate}
class SynkString {
  /// {@macro synk_string}
  SynkString(this.doc, this.name) {
    doc.listen((item) {
      if (item.parentKey == name) {
        _applyRemoteItem(item);
      }
    });

    // Apply existing history
    for (final clientItems in doc.store.values) {
      for (final item in clientItems) {
        if (item.parentKey == name) {
          _applyRemoteItem(item);
        }
      }
    }
  }

  /// The document this register belongs to.
  final SynkDoc doc;

  /// The unique key name of this register in the document.
  final String name;

  Item? _activeItem;

  void _applyRemoteItem(Item item) {
    if (item.content is! String) return;

    final existing = _activeItem;
    if (existing != null) {
      final a = item.id;
      final b = existing.id;
      if (a.clock > b.clock || (a.clock == b.clock && a.client > b.client)) {
        existing.delete();
        _activeItem = item;
      } else {
        item.delete();
      }
    } else {
      _activeItem = item;
    }
  }

  /// Sets the register to a new [value].
  void set(String value) {
    doc.transact((txn) {
      final item = Item(
        id: txn.getNextId(),
        parentKey: name,
        content: value,
      );
      doc.addItem(item);
    });
  }

  /// Gets the current resolved value. Returns an empty string if unset.
  String get value {
    final item = _activeItem;
    if (item == null || item.deleted) return '';
    return item.content as String;
  }
}
