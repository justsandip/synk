# 0.1.0-dev.9

* feat: add batched reactive streams to shared types ([#22](https://github.com/justsandip/synk/pull/22))

# 0.1.0-dev.8

* feat: add doc listeners, data types dispose ([#16](https://github.com/justsandip/synk/pull/16))
* refactor: optimize length calculation for list, text ([#17](https://github.com/justsandip/synk/pull/17))
* feat: implement transaction batching, mutation tracking ([#18](https://github.com/justsandip/synk/pull/18))
* refactor: [BREAKING CHANGE] unify primitives into generic SynkValue<T> ([#19](https://github.com/justsandip/synk/pull/19))
* docs: fix SynkMap constructor in README ([#20](https://github.com/justsandip/synk/pull/20))

# 0.1.0-dev.7

* fix(SynkMap): delete syncs correctly across peers ([#12](https://github.com/justsandip/synk/pull/12))
* fix(SynkMap): add name, isolate listener ([#14](https://github.com/justsandip/synk/pull/14))

# 0.1.0-dev.6

* feat: added `SynkText` for collaborative text editing (character-level sequence CRDT)
* docs: added example for `SynkText`

# 0.1.0-dev.5

* docs: add a flutter demo app for showcase
* docs(README): add a demo gif, minor revisions

# 0.1.0-dev.4

* fix(deps): downgrade meta to ^1.17.0 for flutter compatibility

# 0.1.0-dev.3

* feat: added `SynkList` for collaborative list operations
* docs: added example for `SynkList`

# 0.1.0-dev.2

* feat: added `SynkBool`, `SynkDouble`, `SynkInt`, and `SynkString` for basic data types
* docs: added examples for all the primitive data types

# 0.1.0-dev.1

* chore: initial pre-release of the Synk core engine ✨
* chore: initial project scaffolding and internal data structures (`Item`, `ID`, `Transaction`)
* feat: added `SynkDoc` and `StateVector` for tracking distributed document states
* feat: implemented `SynkMap` with deterministic LWW (Last-Writer-Wins) conflict resolution
* feat: implemented `SynkProtocol` for binary (`Uint8List`) delta-updates between peers
