# Kairo API

Kairo depends on `Base` from the official Bend toolchain and on Tessra's
`geometry.bend`. Import paths are relative to the calling file. An application
next to the `Kairo` and `Tessra` directories uses:

```bend
import Base
import ./Kairo/main.bend as K
import ./Kairo/types.bend as T
import ./Kairo/base_adapter.bend as B
import ./Tessra/geometry.bend as G
```

## Types (`types.bend`)

```bend
Role:    ButtonRole{} | TextRole{} | EditRole{}
Node{id: U32, bounds: G.Rect, label: String, role: Role, enabled: Bool, focusable: Bool}
KeyName: TabKey{} | EnterKey{} | SpaceKey{} | EscapeKey{} | OtherKey{code: U32}

Input:
  PointerMove{x: F32, y: F32}
  PointerDown{x: F32, y: F32, button: U32}
  PointerUp{x: F32, y: F32, button: U32}
  PointerLeave{}
  Cancel{}
  KeyDown{key: KeyName, repeat: Bool, shift: Bool}
  KeyUp{key: KeyName}
  TextInput{text: String}
  Editing{command: EditCommand}
  WindowFocus{focused: Bool}
  Resize{width: F32, height: F32}
  CloseRequested{}

Motion:  ByChar{} | ByWord{} | ToEdge{}
EditCommand:
  MoveLeft{by: Motion, select: Bool}  MoveRight{by: Motion, select: Bool}
  DeleteBack{by: Motion}  DeleteForward{by: Motion}
  SelectAll{}  Copy{}  Cut{}  Paste{}

Action:  Activated{id} | TextDelivered{id, text} | EditRequested{id, command}
       | EditPointer{id, x: F32, y: F32, drag: Bool}
       | Mounted{id} | Unmounted{id} | Closed{}
Change{state: State, actions: +List<Action>, dirty: +List<G.Rect>, layout: Bool}
Error:   InvalidNode{id} | DuplicateId{id} | InvalidViewport{} | NotLive{}
```

`State` holds the registry, the hovered, focused, captured, and keyboard-armed
ids, whether the runtime is live, window focus, and the viewport. Id `0` means
"no target" and is reserved. Buttons are `0` primary, `1` secondary, `2`
middle. Coordinates are logical `F32` units; the caller normalizes the backend.

## Entry points (`main.bend`)

| Function | Contract |
| --- | --- |
| `init(nodes, width, height)` | `Result<&2, &2, Error, State>`. Validates the viewport, every node's bounds, and id uniqueness (O(n²)). |
| `dispatch(state, input)` | `Change` for one input. |
| `next(change)` | The `State` inside a `Change`. |
| `replay(inputs, state)` | Applies a list and discards actions and dirty regions. For simulations only. |
| `mount(state, node)` | `Result<Error, Change>`: emits `Mounted{id}` and dirties only the new bounds. Fails on invalid or duplicate nodes, or after close. |
| `unmount(state, id)` | Emits `Unmounted{id}`, clears hover/focus/capture/keyboard references to it, dirties its old bounds. An absent id is a no-op. |
| `set_bounds(state, id, rect)` | Dirties old and new bounds and cancels that control's gestures. Identical bounds or an absent id are no-ops; invalid bounds fail. |
| `set_label(state, id, label)` | Dirties only that control. An identical label is a no-op. |
| `activation_count(actions)` | Number of `Activated` actions. |

There is no setter for `enabled`; rebuild the control with unmount/mount.

## Interaction rules

- Hit testing and Tab order follow node order. The first enabled, eligible
  control containing the point receives the interaction. Edges follow Tessra:
  left/top inclusive, right/bottom exclusive.
- A primary press captures the target. Releasing activates only the same target
  under the release coordinates, even without an intermediate move.
- Tab/Shift+Tab cycle enabled buttons and editable text and wrap. Enter and
  Space arm a focused button on key down and activate on the matching key up;
  repeats and duplicate downs are ignored. Keyboard input without focus is
  inert.
- Editable text (`EditRole`) takes focus and capture but never activates: a
  release over it, Enter and Space do nothing. A primary press on it emits
  `EditPointer{id, x, y, False}`; while the button stays down, each valid move
  emits `EditPointer{id, x, y, True}`, also outside its bounds.
- Tab, Escape, `Cancel`, window blur, resize, and removing the control cancel
  pending gestures. Blur clears focus and hover.
- `TextInput` is delivered as `TextDelivered` and `Editing{command}` as
  `EditRequested{id, command}`, only when the window is active and the focus
  is editable text. Otherwise both are ignored, with no change.
- `CloseRequested` clears the registry, emits `Closed{}`, and later inputs are
  ignored.

## Editing (`edit.bend`)

Pure single-line editing. The application keeps one `Edit` per editable
control, keyed by its node id, and applies Kairo's actions to it.

```bend
Edit{text: String, count: U32, caret: U32, anchor: U32}    # scalar indices
Request: NoRequest{} | CopyText{text} | PasteText{}
Refusal: ControlChar{code} | LineBreak{} | TooLong{limit}
Applied{edit: Edit, text_changed: Bool, caret_changed: Bool, request: Request}
```

| Function | Contract |
| --- | --- |
| `empty()` | Empty text, caret 0. |
| `of(text, limit)` | `Result<&2, &2, Refusal, Edit>` with the caret at the end. |
| `apply(edit, command)` | `Applied` for an `EditCommand`. `caret_changed` covers the caret and the anchor. |
| `insert(edit, text, limit)` | `Result<&2, &2, Refusal, Applied>`: replaces the selection with `text`, caret after it. |
| `place(edit, index, extend)` | Clamps to the text, snaps back off combining marks; `extend` keeps the anchor. |
| `selection(edit)` | `(start, end)`, `start <= end`. |
| `selected(edit)` | The selected text. |
| `is_mark(c)` | `c` in U+0300..U+036F. |
| `default_limit()`, `max_limit()` | 256 and 4096. |

- Caret stops: index 0, the end, and every index whose scalar is not a
  combining mark (U+0300..U+036F). Moves and deletions go by stop, so a base
  character and its marks act as one.
- A word is a run of scalars other than space and NBSP. `ByWord` moves left
  to the previous word start and right to the next word end; `ToEdge` to
  the start or the end.
- Without `select`, a selection collapses: `ByChar` stops at its start
  (left) or end (right); `ByWord` and `ToEdge` move on from that edge. With
  `select` the caret moves and the anchor stays.
- Deletions remove the selection when there is one, otherwise from the
  caret to the motion's target.
- `Copy` and `Cut` request `CopyText` only with a selection; `Cut` also
  deletes it. `Paste` requests `PasteText` and changes nothing: the
  application reads the clipboard and calls `insert`.
- `of` and `insert` refuse whole texts: C0 controls, DEL and C1 controls as
  `ControlChar` (LF and CR as `LineBreak`), and a result over the limit,
  capped at 4096, as `TooLong`. Any other scalar is accepted; whether the
  font can draw it is the caller's check before committing.

## Invalidation (`dirty.bend`)

`hovered`, `pressed`, and `focused(state, id)` are the visual projections. A
`Change` dirties a control's bounds only when one of them changed for that id.
`Resize` to a valid, different size sets `layout = True` and dirties the old
and new viewports; an invalid or identical size is ignored. Regions are not
merged across events. An application action may require invalidating other
content (Mokko's counter label, for example); the application adds it.

## Base adapter (`base_adapter.bend`)

| Function | Contract |
| --- | --- |
| `init()` | An empty `Adapter`. |
| `normalize(events, adapter, scale)` | `Result<&2, &2, String, Normalized{adapter, events}>`. `scale` must be finite and in `(0, 16]`. |

Physical coordinates are divided by `scale`. Mouse button `0` stays primary.
Key codes 9 and 25 map to Tab (25 also as Shift+Tab), 13 to Enter, 32 to
Space, and 27 to Escape. Shift is tracked from held key codes 65592/65596.

`Base` carries no repeat bit or timestamp. For Enter and Space the adapter
holds a key-up until the next event or poll, and merges an adjacent
release/press of the same key, also across batches, into a repeat. Call
`normalize` on empty polls as well, so a pending key-up is flushed. This costs
up to one poll of latency and can merge a genuine very fast tap with the same
pattern.

## Ankra adapter (`ankra_adapter.bend`)

| Function | Contract |
| --- | --- |
| `normalize(events, scale)` | `Result<&2, &2, String, List<&2, Input>>` for one wait's events, in order. `scale` must be finite and in `(0, 16]`. |
| `input(event, scale)` | The Kairo inputs of one Ankra event (zero or one). |
| `binding(code, mods)` | `Maybe<&2, EditCommand>`: the editing command of a key press, if any. |

Ankra flags repeats itself, so no key-up is deferred and an idle window can
wait without a deadline. Pointer coordinates and sizes are divided by
`scale`; window position, exposure, visibility, entering and the wheel are
dropped. `TextTyped{text}` and a paste's answer `Clipboard{Pasted{text}}`
become `TextInput{text}`; the other clipboard events (`Asked`, `Lost`,
`PasteFailed`) are the host's to serve through Ankra's `clipboard.bend` and
are dropped.

A key press (first or repeat) with a binding becomes `Editing{command}`
instead of `KeyDown`; its key-up stays a `KeyUp`. Modifier bits are Shift 1,
Ctrl 2, Alt 4, Super 8; Caps Lock (16) is ignored, and nothing is bound while
Alt or Super is held. AltGr is not a modifier bit (AltGr+q arrives as `q`
with no bits), so no binding uses it.

| Keys (Ankra code) | Command |
| --- | --- |
| Left (63234), Right (63235) | `MoveLeft`/`MoveRight{ByChar}`; Ctrl: `ByWord`; Shift selects |
| Home (63273), End (63275) | `MoveLeft`/`MoveRight{ToEdge}`; Shift selects |
| Backspace (127) | `DeleteBack{ByChar}`; Ctrl: `ByWord` |
| Delete (63272) | `DeleteForward{ByChar}`; Ctrl: `ByWord`; Shift (no Ctrl): `Cut` |
| Ctrl+A (97), Ctrl+C (99), Ctrl+X (120), Ctrl+V (118) | `SelectAll`, `Copy`, `Cut`, `Paste` (Shift ignored) |
| Shift+Insert, Ctrl+Insert (63271) | `Paste`, `Copy` |

Ankra types nothing while Ctrl, Alt or Super is held and drops control
characters, so Ctrl+V yields only `Paste`, and Backspace and Delete never type.
Kairo routes `Editing` only to focused editable text, so a binding while a
button has focus changes nothing. A dead key or compose sequence arrives as
key-ups without presses followed by `TextTyped`; those key-ups match no armed
key and change nothing. Letters are bound by code, which is the key's
character with only Shift and Lock applied: on a non-Latin layout, Ctrl+C
may arrive as another code and not copy. Keypad arrows are not bound.

## Ownership and scope

All Kairo data is plain Bend data; the caller threads `State` and the
`Adapter` through its loop. The core performs no IO. The API is not stable yet.
