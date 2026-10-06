import Base
import ../Tessra/geometry.bend as G

type Role is Data:
  ButtonRole{}
  TextRole{}

type Node is Data:
  Node{id: U32, bounds: G.Rect, label: String, role: Role, enabled: Bool, focusable: Bool}

type KeyName is Data:
  TabKey{}
  EnterKey{}
  SpaceKey{}
  EscapeKey{}
  OtherKey{code: U32}

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
  WindowFocus{focused: Bool}
  Resize{width: F32, height: F32}
  CloseRequested{}

type Action is Data:
  Activated{id: U32}
  TextDelivered{id: U32, text: String}
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
