# Kairo: instructions for contributors and agents

Kairo is the interaction runtime of the AMAGE UI ecosystem, implemented in
**Bend 2**: it manages control state and lifecycle, routes events, controls
focus, and tracks invalidation so the interface only redraws when something
changed. Read the README for current capabilities and limits; a roadmap item
is not implemented merely because it appears in the project scope.

## Implementation

- Implement library logic in Bend 2, rather than wrapping an equivalent toolkit
  written in another language.
- The official Bend compiler/runtime, OS APIs, and drivers remain external
  dependencies. The core stays free of IO; platform events enter through a
  small, explicit adapter such as `base_adapter.bend`.
- Before writing Bend, run `bend version` and read `bend guide` from the installed
  toolchain. Verify available syntax/effects instead of assuming old examples work.
- Mokko and Auvia import Kairo's modules as `../Kairo/...`. Keep file paths and
  public names stable, or update the dependent libraries in the same change.
- Keep source, comments, documentation, and commit messages in English.

## Linux first

The initial goal is excellent behavior on Ian's actual Linux development machine:
correctness, stability, measured performance, and a finished user experience.
Inspect the effective environment before choosing integrations.

Build compatibility layers as the project progresses, after visible, well-made
Linux results. Do not let speculative Windows or macOS abstractions delay local
quality. Introduce abstractions from concrete needs.

## Working practice

- Preserve existing work and keep the library's boundary clear: Kairo decides
  interaction state; it does not lay out, draw, or own the window.
- Favor simple, maintainable code. Pursue fast, polished behavior with evidence.
- A backend or component must never produce a second activation for one
  gesture. Add a regression check for every rule you change.
- Run the native checks after changes. Validate affected interactions in a real
  window (Mokko's demo) when visible behavior changes, then close the window.
- Compilation is not visual proof. Runtime checks are not proofs of the entire
  system. Synthetic events sent to a window are not a physical-keyboard test.
  State partial support and unverified behavior explicitly.
- Build sequentially. Do not impose virtual-address limits on the Bend compiler
  or runtime, or suppress crash reporting. Investigate failures before retrying.
- Keep generated binaries, logs, crash dumps, credentials, and machine-specific
  evidence out of Git. Stage explicit paths and preserve concurrent changes.

See [CONTRIBUTING.md](CONTRIBUTING.md) for validation commands.
