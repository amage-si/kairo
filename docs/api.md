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
Role:    ButtonRole{} | TextRole{}
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
  WindowFocus{focused: Bool}
  Resize{width: F32, height: F32}
  CloseRequested{}

Action:  Activated{id} | TextDelivered{id, text} | Mounted{id} | Unmounted{id} | Closed{}
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
- Tab/Shift+Tab cycle enabled buttons and wrap. Enter and Space arm on key down
  and activate on the matching key up; repeats and duplicate downs are ignored.
  Keyboard input without focus is inert.
- Tab, Escape, `Cancel`, window blur, resize, and removing the control cancel
  pending gestures. Blur clears focus and hover.
- `TextInput` is delivered to the focused target as `TextDelivered`.
- `CloseRequested` clears the registry, emits `Closed{}`, and later inputs are
  ignored.

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

## Ownership and scope

All Kairo data is plain Bend data; the caller threads `State` and the
`Adapter` through its loop. The core performs no IO. The API is not stable yet.
