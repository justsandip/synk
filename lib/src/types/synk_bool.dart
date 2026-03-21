// ignore_for_file: avoid_positional_boolean_parameters

import 'package:synk/synk.dart';

/// {@template synk_bool}
/// A collaborative boolean toggle register.
///
/// [SynkBool] implements a Last-Writer-Wins (LWW) Register.
/// {@endtemplate}
class SynkBool {
  /// {@macro synk_bool}
  SynkBool(this.doc, this.name) {
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
    if (item.content is! bool) return;

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
  void set(bool value) {
    doc.transact((txn) {
      final item = Item(
        id: txn.getNextId(),
        parentKey: name,
        content: value,
      );
      doc.addItem(item);
    });
  }

  /// Toggles the current boolean value.
  void toggle() {
    set(!value);
  }

  /// Gets the current resolved value. Returns false if unset.
  bool get value {
    final item = _activeItem;
    if (item == null || item.deleted) return false;
    return item.content as bool;
  }
}
