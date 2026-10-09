# Kairo

**Interaction state, focus, events, and invalidation for the AMAGE UI ecosystem, in Bend 2.**

Kairo is the interaction runtime of the AMAGE ecosystem. It keeps a registry of
controls and decides, for each input, what changed: hover, focus, pointer
capture, keyboard gestures, lifecycle, and which regions must be redrawn. It is
independent of any window or renderer, and the core uses no IO or native code.
Adapters normalize window events into Kairo inputs: the official Bend
runtime's (`base_adapter.bend`) and [Ankra](https://github.com/amage-si/ankra)'s
native window (`ankra_adapter.bend`).

**Status:** early implementation, tested with **Bend 2.0.35** on Linux
(Hyprland with X11/XWayland). The first priority is a polished, reliable
experience on the development Linux machine. Compatibility layers will follow
proven progress.

## What works today

- A validated control registry: unique non-zero ids, valid bounds, button,
  static text and editable text roles, enabled and focusable flags.
- Pointer: hover, primary-button capture, and activation only when the release
  lands on the captured control. Dragging out cancels the pressed look;
  returning and releasing over the captured control can still activate.
  Pressing outside and releasing inside does not activate.
- Keyboard: Tab and Shift+Tab cycle enabled buttons and editable text and
  wrap. Enter and Space arm a focused button on key down and activate on the
  matching key up; repeats and duplicate downs are ignored.
- Editable text (`EditRole`): it takes focus, Tab order and pointer capture
  like a button but never activates, by pointer, Enter or Space. A press
  emits `EditPointer{id, x, y, False}` and moves while it is captured emit
  `EditPointer{.., True}` drags, also outside its bounds. `TextInput` and
  `Editing{command}` reach only focused editable text, as `TextDelivered`
  and `EditRequested`.
- `edit.bend`: pure single-line editing that the application applies to its
  own text per control: caret and selection as scalar indices, moves by
  character, word or edge, cluster-aware deletion (a combining mark
  U+0300..U+036F is never a caret stop), select all, and copy, cut and
  paste requests. Insertion replaces the selection all or nothing and
  refuses controls, line breaks, and text over the limit (256 scalars by
  default, at most 4096).
- Cancellation: Tab, Escape, window blur, resize, and removing the control
  cancel pending gestures. Duplicate downs/ups never activate twice.
- Lifecycle: mount, unmount, bounds and label updates, close. Unmount clears
  every reference to the control; close blocks later events.
- Invalidation: visual projections (hover, pressed, focused) are compared per
  id. Moves within the same control, irrelevant events, repeats, and duplicate
  releases produce no dirty region. A valid, different `Resize` requests layout
  and invalidates the old and new viewports.
- `base_adapter.bend` converts `Base.Event` batches into Kairo inputs with a
  device scale, and filters X11 autorepeat release/press pairs for Enter and
  Space (see [Current boundaries](#current-boundaries)).
- `ankra_adapter.bend` converts the events of Ankra's native window: pointer,
  keys (repeats already flagged by Ankra, so no key-up waits for a later
  poll and an idle window can wait without a deadline), window focus, resize
  and close, with a device scale.

The native suites have **56 core checks**, **46 editing checks**, **11 Base
adapter checks** and **10 Ankra adapter checks**: mouse, hover, release
outside, duplicates, disabled controls, focus, keyboard, lifecycle,
invalidation, invalid input, scale, repeats across polls, routing to
editable text, the editing commands and refusals, and, through Ankra's
events, a click, Space with repeats, and Enter cancelled by losing window
focus. The integrated GPU demo
(Chromi's `examples/eco`) and Auvia's counter run on the Ankra adapter in a
real window.
In the Mokko demo, a real X11/XWayland window driven by synthetic X11 events
sent only to that window showed mouse activation, Space with autorepeat pairs,
and Enter activating exactly once each. Those were targeted synthetic events,
not a manual test with a physical keyboard.

## Quick start

Requirements: the [Bend 2 toolchain](https://bend-lang.com), Clang 14 or newer,
and [Tessra](https://github.com/amage-si/tessra) cloned beside Kairo. Kairo
imports Tessra's geometry as `../Tessra/geometry.bend`, so keep both
capitalized directory names. No display is needed.

```sh
git clone https://github.com/amage-si/tessra.git Tessra
git clone https://github.com/amage-si/kairo.git Kairo
cd Kairo
export BEND_NO_TELEMETRY=1
bend version
mkdir -p build
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
bend edit_tests.bend -o build/edit_tests
./build/edit_tests --threads 2 --gpu off
bend adapter_tests.bend -o build/adapter_tests
./build/adapter_tests --threads 2 --gpu off
bend ankra_tests.bend -o build/ankra_tests      # Ankra cloned beside Kairo
./build/ankra_tests --threads 2 --gpu off
```

Run the button example, which replays a click, a release outside, Tab + Space
with a repeat, and Enter on one button:

```sh
bend examples/button.bend -o build/button
./build/button --threads 2 --gpu off
# Kairo: 3 activations (expected 3)
```

Run the editing example, which types, selects, copies, drags and cuts in one
editable text control and prints the text, caret and anchor after each input:

```sh
bend examples/edit.bend -o build/edit
./build/edit --threads 2 --gpu off
# Kairo edit: " ação" caret 0 anchor 0 (expected " ação" caret 0 anchor 0)
```

## The interaction contract

`init(nodes, width, height)` validates the registry and the viewport and
returns the initial `State`. Each input goes through `dispatch(state, input)`,
which returns a `Change`:

| Field | Meaning |
| --- | --- |
| `state` | The next state. |
| `actions` | `Activated{id}`, `TextDelivered{id, text}`, `EditRequested{id, command}`, `EditPointer{id, x, y, drag}`, `Mounted{id}`, `Unmounted{id}`, `Closed{}`. |
| `dirty` | Regions to redraw, in logical units. Empty when nothing visible changed. |
| `layout` | `True` when the viewport changed and layout must run again. |

Only `Activated{id}` is an activation, and only a button produces it; a
backend must not synthesize a second click. `TextDelivered` and
`EditRequested` go only to focused editable text: the application applies
them to that control's `edit.bend` `Edit`, and maps an `EditPointer` x to a
caret index with its laid-out text before `place`. Consume `actions` on every step: `replay` keeps only the final state and
is meant for simulations. Coordinates are logical `F32` units; buttons are
`0` primary, `1` secondary, `2` middle. Start from `init`: the public records
are plain data, and building a `State` by hand bypasses validation.

Read the [API reference](docs/api.md) or the complete
[button example](examples/button.bend).

## Current boundaries

- The official runtime does not deliver key repeat flags, timestamps, text
  input, window focus, resize, or pointer leave; through `Base` they never
  arrive. Ankra's native window delivers repeats, window focus, resize and
  pointer leave, so the Ankra adapter passes them on. Neither adapter yet
  produces `TextInput` or `Editing` (key bindings); that waits for Ankra's
  text input.
- Without timestamps, the adapter delays the key-up of Enter and Space until
  the next event or poll and merges an adjacent release/press of the same key,
  also across batches. That stopped repeated activations in the X11 autorepeat
  pairs tested, at the cost of up to one poll of latency; a genuine very fast
  tap with the same pattern can be merged. Universal filtering of ambiguous or
  interleaved streams is not claimed. Call `normalize` on empty polls too.
- The node order defines hit testing and Tab order: the first eligible enabled
  control under the point wins. There is no tree, bubbling/capture phases,
  ancestor clipping, scrolling, or multitouch.
- Static text does not take focus. Text input is delivered only to focused
  editable text as `TextDelivered`; a focused button drops it (it used to
  receive it). Editing is single-line: no multi-line text, undo, IME
  composition, double-click word selection or bidirectional text. Caret
  stops follow Syllo's one-mark cluster rule, not full Unicode grapheme
  clusters. Whether a font can draw the text is the caller's check.
- Blur clears focus and hover; focus is not restored automatically when the
  window regains it. Changing `enabled` requires unmount and mount.
- Dirty regions are not merged or deduplicated across events; the host decides
  how to accumulate them.
- Id validation in `init` is O(n²); dispatch, lookup, and visual diffing are
  O(n) list passes. This targets small interfaces; throughput has not been
  measured. There is no scheduler, async tasks, or general reconciliation.
- Kairo exports state that Mokko turns into semantics (role, label, state,
  actions, focus), and [Auvia](https://github.com/amage-si/auvia) publishes it.
  Kairo itself has no `Activate{id}` or `Focus{id}` input for assistive
  requests.

The Bend checker and these tests are not a formal proof of every property of
the system.

## Repository map

| Path | Purpose |
| --- | --- |
| [types.bend](types.bend) | `Node`, `Role`, `Input`, `EditCommand`, `Action`, `State`, `Change`, `Error`. |
| [main.bend](main.bend) | `init`, `dispatch`, `next`, `replay`, mount/unmount, bounds and label updates. |
| [events.bend](events.bend) | Per-input rules: pointer, keyboard, focus, resize, text, close. |
| [nodes.bend](nodes.bend) | Registry validation, hit testing, Tab traversal, updates. |
| [edit.bend](edit.bend) | Pure single-line editing: `Edit`, `apply`, `insert`, `place`, selection. |
| [dirty.bend](dirty.bend) | Visual projections and dirty regions. |
| [base_adapter.bend](base_adapter.bend) | `Base.Event` normalization with scale and autorepeat filtering. |
| [ankra_adapter.bend](ankra_adapter.bend) | Ankra native-window event normalization with scale. |
| [tests.bend](tests.bend), [edit_tests.bend](edit_tests.bend), [adapter_tests.bend](adapter_tests.bend), [ankra_tests.bend](ankra_tests.bend) | Native checks; no display needed. |
| [examples/button.bend](examples/button.bend) | A scripted input sequence on one button. |
| [examples/edit.bend](examples/edit.bend) | A scripted editing session on one editable text control. |
| [docs/api.md](docs/api.md) | Types, rules, and the adapter contract. |

## Dependencies

- [Tessra](https://github.com/amage-si/tessra), beside Kairo: `geometry.bend`
  for rectangles and `test_support.bend` for the tests.
- The Bend 2 toolchain and its `Base` library. Nothing else.

[Mokko](https://github.com/amage-si/mokko) and
[Auvia](https://github.com/amage-si/auvia) import Kairo's `types.bend`,
`main.bend`, `dirty.bend`, `nodes.bend`, and `base_adapter.bend` as
`../Kairo/...`; keep those paths stable.

## Direction

Next: text input and editing key bindings through the Ankra adapter once
Ankra delivers text, inputs for assistive actions, and a component tree with
clipping and scrolling. These are goals, not supported features.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development rules. The API is
experimental and may change. Licensed under either of [Apache License 2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your option.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option. Unless you explicitly state otherwise, any contribution
intentionally submitted for inclusion in this work, as defined in the
Apache-2.0 license, shall be dual licensed as above, without any additional
terms or conditions.
