import Base
import ./types.bend as T
import ./nodes.bend as N
import ./events.bend as E
import ./dirty.bend as D
import ../Tessra/geometry.bend as G

def initialized(check: Result<&2, &2, T.Error, Unit>, nodes: +List<T.Node>, width: F32, height: F32) -> Result<&2, &2, T.Error, T.State>:
  match check:
    case Fail{error}:
      Fail{error}
    case Done{u}:
      Done{T.State{nodes, 0, 0, 0, 0, 0, False{}, True{}, True{}, width, height}}

def initialize_valid(ok: Bool, +nodes: +List<T.Node>, width: F32, height: F32) -> Result<&2, &2, T.Error, T.State>:
  match ok:
    case False{}:
      Fail{T.InvalidViewport{}}
    case True{}:
      initialized(N.validate(nodes), nodes, width, height)

def init(nodes: +List<T.Node>, +width: F32, +height: F32) -> Result<&2, &2, T.Error, T.State>:
  initialize_valid(G.valid_length(width) && G.valid_length(height), nodes, width, height)

def dispatch(state: T.State, event: T.Input) -> T.Change:
  E.dispatch(state, event)

def next(change: T.Change) -> T.State:
  T.Change{state, a, d, l} = change
  state

def replay(events: +List<T.Input>, state: T.State) -> T.State:
  match events:
    case Nil{}:
      state
    case Con{event, rest}:
      replay(rest, next(dispatch(state, event)))

def bounds(nodes: +List<T.Node>, +id: U32) -> +List<G.Rect>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{T.Node{other, r, l, role, e, f}, rest}:
      Bool.pick(+List<G.Rect>, U32.is_eq(other, id), [r], bounds(rest, id))

def mount_ready(n: T.Node, state: T.State) -> Result<&2, &2, T.Error, T.Change>:
  T.Node{id, r, l, role, e, f} = n
  Done{T.Change{state, [T.Mounted{id}], [r], False{}}}

def mount_checked(live: Bool, valid: Bool, duplicate: Bool, s: T.State, n: T.Node) -> Result<&2, &2, T.Error, T.Change>:
  match live valid duplicate:
    case False{} _ _:
      Fail{T.NotLive{}}
    case True{} False{} _:
      T.Node{id, r, l, role, e, f} = n
      Fail{T.InvalidNode{id}}
    case True{} True{} True{}:
      T.Node{id, r, l, role, e, f} = n
      Fail{T.DuplicateId{id}}
    case True{} True{} False{}:
      T.State{nodes, h, f, c, k, t, d, life, active, w, hh} = s
      +node = n
      mount_ready(node, T.State{List.append(&2, T.Node, nodes, [node]), h, f, c, k, t, d, life, active, w, hh})

def mount(+s: T.State, +n: T.Node) -> Result<&2, &2, T.Error, T.Change>:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  T.Node{id, r, l, role, e, ff} = n
  mount_checked(live, N.valid(n), N.has(nodes, id), s, n)

def clear_id(+value: U32, id: U32) -> U32:
  Bool.pick(U32, U32.is_eq(value, id), 0, value)

def unmount_existing(exists: Bool, s: T.State, +id: U32) -> T.Change:
  match exists:
    case False{}:
      D.unchanged(s)
    case True{}:
      T.State{+nodes, h, f, +c, k, +t, d, live, active, w, hh} = s
      next = {T.State{N.remove(nodes, id), clear_id(h, id), clear_id(f, id), clear_id(c, id), Bool.pick(U32, U32.is_eq(t, id), 0, k), clear_id(t, id), d && U32.is_ne(c, id), live, active, w, hh} : T.State}
      T.Change{next, [T.Unmounted{id}], bounds(nodes, id), False{}}

def unmount(+s: T.State, +id: U32) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  unmount_existing(N.has(nodes, id), s, id)

def same_bounds(rs: +List<G.Rect>, r: G.Rect) -> Bool:
  match rs:
    case Nil{}:
      True{}
    case Con{old, rest}:
      G.equal(old, r)

def relocate_checked(valid: Bool, same: Bool, s: T.State, +id: U32, +r: G.Rect) -> Result<&2, &2, T.Error, T.Change>:
  match valid same:
    case False{} _:
      Fail{T.InvalidNode{id}}
    case True{} True{}:
      Done{D.unchanged(s)}
    case True{} False{}:
      T.State{+nodes, h, f, +c, k, +t, d, live, active, w, hh} = s
      next = {T.State{N.relocate(nodes, id, r), clear_id(h, id), f, clear_id(c, id), Bool.pick(U32, U32.is_eq(t, id), 0, k), clear_id(t, id), d && U32.is_ne(c, id), live, active, w, hh} : T.State}
      Done{T.Change{next, Nil{}, List.append(&2, G.Rect, bounds(nodes, id), [r]), False{}}}

def set_bounds(+s: T.State, +id: U32, +r: G.Rect) -> Result<&2, &2, T.Error, T.Change>:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  relocate_checked(G.valid_rect(r), same_bounds(bounds(nodes, id), r), s, id, r)

def activation_count(actions: +List<T.Action>) -> U32:
  match actions:
    case Nil{}:
      0
    case Con{T.Activated{id}, rest}:
      (1 + activation_count(rest) : U32)
    case Con{other, rest}:
      activation_count(rest)

def relabel_changed(same: Bool, s: T.State, +id: U32, label: String) -> T.Change:
  match same:
    case True{}:
      D.unchanged(s)
    case False{}:
      T.State{+nodes, h, f, c, k, t, d, live, active, w, hh} = s
      T.Change{T.State{N.relabel(nodes, id, label), h, f, c, k, t, d, live, active, w, hh}, Nil{}, bounds(nodes, id), False{}}

def set_label(+s: T.State, +id: U32, +label: String) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  relabel_changed(N.label_same(nodes, id, label), s, id, label)
