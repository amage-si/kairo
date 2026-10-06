import Base
import ./types.bend as T
import ../Tessra/geometry.bend as G

def pressed(+state: T.State, id: U32) -> Bool:
  T.State{nodes, h, f, capture, key, target, down, live, active, w, hh} = state
  +wanted = id
  U32.is_ne(wanted, 0) && live && active && ((U32.is_eq(capture, wanted) && U32.is_eq(h, wanted)) || U32.is_eq(target, wanted))

def focused(state: T.State, +id: U32) -> Bool:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = state
  U32.is_ne(id, 0) && U32.is_eq(f, id) && live && active

def hovered(state: T.State, +id: U32) -> Bool:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = state
  U32.is_ne(id, 0) && U32.is_eq(h, id) && live && active

def changed(+before: T.State, +after: T.State, +id: U32) -> Bool:
  Bool.xor(pressed(before, id), pressed(after, id)) || Bool.xor(focused(before, id), focused(after, id)) || Bool.xor(hovered(before, id), hovered(after, id))

def regions(nodes: +List<T.Node>, +before: T.State, +after: T.State) -> +List<G.Rect>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{T.Node{id, bounds, l, role, e, f}, rest}:
      +tail = regions(rest, before, after)
      Bool.pick(+List<G.Rect>, changed(before, after, id), Con{bounds, tail}, tail)

def finish(+before: T.State, +after: T.State, actions: +List<T.Action>) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = before
  T.Change{after, actions, regions(nodes, before, after), False{}}

def unchanged(state: T.State) -> T.Change:
  T.Change{state, Nil{}, Nil{}, False{}}
