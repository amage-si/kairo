import Base
import ./types.bend as T
import ../Tessra/geometry.bend as G

def is_button(role: T.Role) -> Bool:
  match role:
    case T.ButtonRole{}:
      True{}
    case T.TextRole{}:
      False{}

def eligible(n: T.Node) -> Bool:
  T.Node{id, rect, label, role, enabled, focusable} = n
  enabled && focusable && is_button(role)

def has(nodes: +List<T.Node>, +id: U32) -> Bool:
  match nodes:
    case Nil{}:
      False{}
    case Con{T.Node{other, r, l, role, e, f}, rest}:
      U32.is_eq(other, id) || has(rest, id)

def valid(n: T.Node) -> Bool:
  T.Node{id, bounds, label, role, enabled, focusable} = n
  U32.is_ne(id, 0) && G.valid_rect(bounds)

def check_one(ok: Bool, duplicate: Bool, id: U32, rest: Result<&2, &2, T.Error, Unit>) -> Result<&2, &2, T.Error, Unit>:
  match ok duplicate:
    case False{} _:
      Fail{T.InvalidNode{id}}
    case True{} True{}:
      Fail{T.DuplicateId{id}}
    case True{} False{}:
      rest

def validate(nodes: +List<T.Node>) -> Result<&2, &2, T.Error, Unit>:
  match nodes:
    case Nil{}:
      Done{Unit{}}
    case Con{+n, +rest}:
      T.Node{+id, r, l, role, e, f} = n
      check_one(valid(n), has(rest, id), id, validate(rest))

def hit(nodes: +List<T.Node>, +x: F32, +y: F32) -> U32:
  match nodes:
    case Nil{}:
      0
    case Con{+n, rest}:
      T.Node{id, rect, l, role, enabled, focusable} = n
      Bool.pick(U32, eligible(n) && G.contains(rect, x, y), id, hit(rest, x, y))

def focus_ids(nodes: +List<T.Node>) -> +List<U32>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{+n, rest}:
      T.Node{id, r, l, role, e, f} = n
      +tail = focus_ids(rest)
      Bool.pick(+List<U32>, eligible(n), Con{id, tail}, tail)

def first(ids: +List<U32>) -> U32:
  match ids:
    case Nil{}:
      0
    case Con{h, t}:
      h

def after(ids: +List<U32>, +current: U32, +fallback: U32) -> U32:
  match ids:
    case Nil{}:
      fallback
    case Con{h, +t}:
      +next = first(t)
      Bool.pick(U32, U32.is_eq(h, current), Bool.pick(U32, U32.is_eq(next, 0), fallback, next), after(t, current, fallback))

def traverse(nodes: +List<T.Node>, current: U32, reverse: Bool) -> U32:
  +ids = focus_ids(nodes)
  +ordered = Bool.pick(+List<U32>, reverse, List.reverse(&2, U32, ids), ids)
  after(ordered, current, first(ordered))

def remove(nodes: +List<T.Node>, +id: U32) -> +List<T.Node>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{+n, rest}:
      T.Node{other, r, l, role, e, f} = n
      +tail = remove(rest, id)
      Bool.pick(+List<T.Node>, U32.is_eq(other, id), tail, Con{n, tail})

def relocate(nodes: +List<T.Node>, +id: U32, +bounds: G.Rect) -> +List<T.Node>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{T.Node{+other, old, l, role, e, f}, rest}:
      r = Bool.pick(G.Rect, U32.is_eq(other, id), bounds, old)
      Con{T.Node{other, r, l, role, e, f}, relocate(rest, id, bounds)}

def label_same(nodes: +List<T.Node>, +id: U32, +label: String) -> Bool:
  match nodes:
    case Nil{}:
      True{}
    case Con{T.Node{other, r, old, role, e, f}, rest}:
      Bool.pick(Bool, U32.is_eq(other, id), String.eq(old, label), label_same(rest, id, label))

def relabel(nodes: +List<T.Node>, +id: U32, +label: String) -> +List<T.Node>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{T.Node{+other, r, old, role, e, f}, rest}:
      next = Bool.pick(String, U32.is_eq(other, id), label, old)
      Con{T.Node{other, r, next, role, e, f}, relabel(rest, id, label)}
