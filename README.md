# Synk

[![Build Status](https://github.com/justsandip/synk/actions/workflows/main.yaml/badge.svg)](https://github.com/justsandip/synk/actions/workflows/main.yaml)
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Test Coverage](coverage_badge.svg)](https://github.com/justsandip/synk/actions)
[![Pub Package](https://img.shields.io/pub/v/synk.svg)](https://pub.dev/packages/synk)

Synk is an offline-first conflict-free shared editing library for Dart. Multiple peers can edit the same data at the same time and always end up with exactly the same result, without any server deciding who is right.

![Watch the demo video](./assets/synk_demo.mp4)

## Installation

Add the dependency to your `pubspec.yaml`:

```sh
dart pub add synk
```

```yaml
dependencies:
  synk: <current-synk-version>
```

## Core Concepts

Synk is built around these ideas:

- [SynkDoc](#creating-a-document) represents your local replica of the shared document. Each peer has their own.
- [SynkProtocol](#syncing-between-peers) is the sync layer that computes minimal binary deltas between peers.

The collaborative data structures you attach to a doc are:

- [SynkMap](#synkmap)
- [SynkList](#synklist)
- [SynkInt](#synkint)
- [SynkString](#synkstring)
- [SynkBool](#synkbool)
- [SynkDouble](#synkdouble)

### Creating a document

```dart
import 'package:synk/synk.dart';

final doc = SynkDoc();
```

Each doc gets a random `clientId` automatically. You can also supply a fixed one:

```dart
final doc = SynkDoc(clientId: 42);
```

## Shared Types

All shared types are attached to a `SynkDoc` with a unique `name` key. Two peers using the same name on docs sharing the same history will always converge to the same value.

### `SynkMap`

A collaborative map (key-value store) that resolves concurrent writes using Last-Writer-Wins (LWW).

```dart
final map = SynkMap(doc);

map.set('theme', 'dark');
map.get('theme');          // 'dark'
map.delete('theme');
map.containsKey('theme');  // false
map.toMap();               // {}
```

> Full example - [`example/synk_example.dart`](example/synk_example.dart)

### `SynkList`

A collaborative list that supports append, insert, and delete operations. Concurrent operations are resolved deterministically using a causal ordering algorithm.

```dart
final list = SynkList(doc, 'items');

list.append('a');
list.insert(0, 'b');
list.toList(); // ['b', 'a']

list.delete(1);
list.toList(); // ['b']
```

> Full example - [`example/synk_list_example.dart`](example/synk_list_example.dart)

### `SynkInt`

A PN-Counter (Positive-Negative Counter). Concurrent increments from any peer are always fully preserved — there are no conflicts.

```dart
final counter = SynkInt(doc, 'score');

counter.increment();     // +1
counter.increment(10);   // +10
counter.decrement(3);    // -3
counter.value;           // 8
```

> Full example - [`example/synk_int_example.dart`](example/synk_int_example.dart)

### `SynkString`

A single-value string register. Concurrent writes are resolved deterministically via LWW — the write with the higher logical clock wins. If clocks tie, the higher `clientId` wins.

```dart
final title = SynkString(doc, 'title');

title.set('Hello, World!');
title.value; // 'Hello, World!'
```

> Full example - [`example/synk_string_example.dart`](example/synk_string_example.dart)

### `SynkBool`

Same LWW semantics as `SynkString`, with an extra `toggle()` helper.

```dart
final flag = SynkBool(doc, 'isPublished');

flag.set(true);
flag.toggle();
flag.value; // false
```

> Full example - [`example/synk_bool_example.dart`](example/synk_bool_example.dart)

### `SynkDouble`

Same LWW semantics as `SynkString`. JSON-safe: integer payloads from the wire are cast to `double` transparently.

```dart
final price = SynkDouble(doc, 'price');

price.set(9.99);
price.value; // 9.99
```

> Full example - [`example/synk_double_example.dart`](example/synk_double_example.dart)

## Syncing Between Peers

Synk is network-agnostic. You exchange plain `Uint8List` binary buffers — send them over WebSockets, REST, Bluetooth, or anything else.

The handshake is always the same three steps:

```dart
// 1. Peer B encodes what it already has
final bState = SynkProtocol.encodeStateVector(docB);

// 2. Peer A computes only what B is missing
final update = SynkProtocol.encodeStateAsUpdate(docA, bState);

// 3. Peer B applies the update
SynkProtocol.applyUpdate(docB, update);
```

To do a full sync for a peer joining cold, omit the state vector:

```dart
final fullUpdate = SynkProtocol.encodeStateAsUpdate(doc);
SynkProtocol.applyUpdate(newPeerDoc, fullUpdate);
```

`applyUpdate` is **idempotent** — applying the same update twice is always safe.

> Full multi-peer example with deletions and a late-joining peer - [`example/synk_example.dart`](example/synk_example.dart)

## License

Released under the [MIT License](LICENSE).
Contributions, bug reports, and PRs are welcome.

## Maintainers

- [Sandip Pramanik](https://github.com/justsandip)
