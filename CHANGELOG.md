# Changelog

All notable changes to Kairo are recorded here. Kairo follows
[semantic versioning](https://semver.org) in its 0.x form: while the API is
experimental, a minor version (0.2.0) may change it in breaking ways and a
patch version (0.1.1) only fixes. Kairo is built from source together with its
sibling AMAGE libraries; the set of versions tested together is listed in
[eco-build's releases](https://github.com/amage-si/eco-build/tree/main/releases).

## [0.1.0] - 2026-10-09

First tagged release, tested with Bend 2.0.35 on Linux (X11/XWayland) as part
of AMAGE Eco 0.1.0.

### Included

- Validated control registry with button, static text and editable text
  roles.
- Pointer hover, capture and activation; Tab order; Enter and Space on
  buttons; cancellation and lifecycle.
- Editable text: focus and pointer routing that never activates, and
  `edit.bend`, pure single-line editing (caret, selection, word moves,
  cluster-aware deletion, copy/cut/paste requests, limits).
- Precise invalidation with dirty regions.
- Adapters for the official Bend window and for Ankra's, including typed and
  pasted text and the editing key bindings.
- 56 core, 46 editing, 11 Base adapter and 27 Ankra adapter checks.

[0.1.0]: https://github.com/amage-si/kairo/releases/tag/v0.1.0
