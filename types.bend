import Base
import ../Tessra/geometry.bend as G

type Role is Data:
  ButtonRole{}
  TextRole{}
  EditRole{}

type Node is Data:
  Node{id: U32, bounds: G.Rect, label: String, role: Role, enabled: Bool, focusable: Bool}

type KeyName is Data:
  TabKey{}
  EnterKey{}
  SpaceKey{}
  EscapeKey{}
  OtherKey{code: U32}

# How far a caret move or a deletion reaches. ByChar steps one caret stop
# (a base character with its combining marks), ByWord to the next word edge
# (words are runs of characters other than space and NBSP), ToEdge to the
# start or the end of the text.
type Motion is Data:
  ByChar{}
  ByWord{}
  ToEdge{}

# A text-editing command for the focused editable control. Adapters map key
# bindings to these; Kairo routes them, and edit.bend applies them.
type EditCommand is Data:
  MoveLeft{by: Motion, select: Bool}
  MoveRight{by: Motion, select: Bool}
  DeleteBack{by: Motion}
  DeleteForward{by: Motion}
  SelectAll{}
  Copy{}
  Cut{}
  Paste{}

# Button 0 is primary, 1 secondary, 2 middle; backends normalize here.
type Input is Data:
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

type Action is Data:
  Activated{id: U32}
  TextDelivered{id: U32, text: String}
  EditRequested{id: U32, command: EditCommand}
  EditPointer{id: U32, x: F32, y: F32, drag: Bool}
  Mounted{id: U32}
  Unmounted{id: U32}
  Closed{}

type State is Data:
  State{nodes: +List<Node>, hover: U32, focus: U32, capture: U32, key: U32, key_target: U32, pointer_down: Bool, live: Bool, window_focus: Bool, width: F32, height: F32}

type Change is Data:
  Change{state: State, actions: +List<Action>, dirty: +List<G.Rect>, layout: Bool}

type Error is Data:
  InvalidNode{id: U32}
  DuplicateId{id: U32}
  InvalidViewport{}
  NotLive{}
