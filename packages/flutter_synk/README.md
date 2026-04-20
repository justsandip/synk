# Flutter Synk

[![Build Status](https://github.com/justsandip/synk/actions/workflows/main.yaml/badge.svg)](https://github.com/justsandip/synk/actions/workflows/main.yaml)
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/justsandip/synk/graph/badge.svg?token=3S7K24D5FJ)](https://codecov.io/gh/justsandip/synk)
[![Pub Package](https://img.shields.io/pub/v/flutter_synk.svg)](https://pub.dev/packages/flutter_synk)

Flutter widgets that bridge [Synk](https://pub.dev/packages/synk)'s offline-first, conflict-free data structures with the Flutter UI layer.

## Installation

Add the dependency to your `pubspec.yaml`:

```sh
flutter pub add flutter_synk
```

## Core Concepts

Flutter Synk provides two primary components to integrate collaborative data into your app:

- **[SynkProvider](#synkprovider)** manages the injection of a `SynkDoc` into the widget tree.
- **[SynkBuilder<T>](#synkbuilder)** listens to any Synk type's stream and rebuilds on every transaction.

## Widgets

### `SynkProvider`

An `InheritedWidget` that makes a `SynkDoc` available to all widgets in its subtree. Place it near the root of your application to establish the collaborative context.

```dart
import 'package:flutter_synk/flutter_synk.dart';
import 'package:synk/synk.dart';

final doc = SynkDoc();

SynkProvider(
  doc: doc,
  child: MyApp(),
)
```

Access the document anywhere below it using the static helper:

```dart
final doc = SynkProvider.docOf(context);
```

### `SynkBuilder<T>`

A reactive widget that rebuilds its subtree in response to changes emitted by a Synk type (e.g., `SynkValue`, `SynkMap`, `SynkList`).

Unlike a standard `StreamBuilder`, `SynkBuilder` is transaction-aware. It processes stream events such that it triggers exactly one rebuild per completed transaction—never more—ensuring UI consistency and performance during complex collaborative updates.

```dart
final title = SynkValue<String>(doc, 'title');

SynkBuilder<String?>(
  stream: title.stream,
  initialData: title.value,
  builder: (context, value) {
    return Text(value ?? 'Untitled');
  },
)
```

## License

Released under the [MIT License](LICENSE).
Contributions, bug reports, and PRs are welcome.

## Maintainers

- [Sandip Pramanik](https://github.com/justsandip)
