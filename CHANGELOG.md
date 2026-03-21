# 0.1.0-dev.2

* feat: added `SynkBool`, `SynkDouble`, `SynkInt`, and `SynkString` for basic data types
* docs: added examples for all the primitive data types

# 0.1.0-dev.1

* chore: initial pre-release of the Synk core engine ✨
* chore: initial project scaffolding and internal data structures (`Item`, `ID`, `Transaction`)
* feat: added `SynkDoc` and `StateVector` for tracking distributed document states
* feat: implemented `SynkMap` with deterministic LWW (Last-Writer-Wins) conflict resolution
* feat: implemented `SynkProtocol` for binary (`Uint8List`) delta-updates between peers
