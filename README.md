# Synk

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Test Coverage](coverage_badge.svg)](https://github.com/justsandip/synk/actions)

**Synk** is a conflict-free shared editing library for Dart. 

Synk uses Conflict-Free Replicated Data Types (CRDTs) to allow multiple peers to collaborate on the same data concurrently without needing a central server to dictate the truth. Every peer resolves conflicts in exactly the same way.

Currently, Synk supports the foundational CRDT structures and a deterministic Last-Writer-Wins Map (`SynkMap`).

---

Synk is released for the community under the [MIT License](LICENSE).
Contributions, bug reports, and PRs are warmly welcomed as we build out the Dart shared-editing ecosystem!
