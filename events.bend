import Base
import ./types.bend as T
import ./nodes.bend as N
import ./dirty.bend as D
import ../Tessra/geometry.bend as G

def move(+s: T.State, +x: F32, +y: F32) -> T.Change:
  T.State{+nodes, h, f, c, k, target, down, live, active, w, hh} = s
  hover = Bool.pick(U32, active && G.valid_coord(x) && G.valid_coord(y), N.hit(nodes, x, y), 0)
  D.finish(s, T.State{nodes, hover, f, c, k, target, down, live, active, w, hh}, Nil{})

def press_allowed(ok: Bool, +s: T.State, x: F32, y: F32) -> T.Change:
  match ok:
    case False{}:
      D.unchanged(s)
    case True{}:
      T.State{+nodes, h, f, c, k, target, d, live, active, w, hh} = s
      +hit = N.hit(nodes, x, y)
      D.finish(s, T.State{nodes, hit, hit, hit, 0, 0, True{}, live, active, w, hh}, Nil{})

def press(+s: T.State, +x: F32, +y: F32, button: U32) -> T.Change:
  T.State{nodes, h, f, c, k, target, down, live, active, w, hh} = s
  press_allowed(U32.is_eq(button, 0) && Bool.not(down) && active && G.valid_coord(x) && G.valid_coord(y), s, x, y)

def activation(ok: Bool, id: U32) -> +List<T.Action>:
  match ok:
    case False{}:
      Nil{}
    case True{}:
      Con{T.Activated{id}, Nil{}}

def release_allowed(ok: Bool, +s: T.State, +x: F32, +y: F32) -> T.Change:
  match ok:
    case False{}:
      D.unchanged(s)
    case True{}:
      T.State{+nodes, h, f, +c, k, target, down, live, active, w, hh} = s
      +hit = Bool.pick(U32, G.valid_coord(x) && G.valid_coord(y), N.hit(nodes, x, y), 0)
      actions = activation(U32.is_ne(c, 0) && U32.is_eq(c, hit), c)
      D.finish(s, T.State{nodes, hit, f, 0, k, target, False{}, live, active, w, hh}, actions)

def release(+s: T.State, x: F32, y: F32, button: U32) -> T.Change:
  T.State{nodes, h, f, c, k, target, down, live, active, w, hh} = s
  release_allowed(U32.is_eq(button, 0) && down && active, s, x, y)

def leave(+s: T.State) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  D.finish(s, T.State{nodes, 0, f, c, k, t, d, live, active, w, hh}, Nil{})

def cancel(+s: T.State) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  D.finish(s, T.State{nodes, h, f, 0, 0, 0, False{}, live, active, w, hh}, Nil{})

def tab(+s: T.State, reverse: Bool) -> T.Change:
  T.State{+nodes, h, f, c, k, t, d, live, active, w, hh} = s
  next = N.traverse(nodes, f, reverse)
  D.finish(s, T.State{nodes, h, next, 0, 0, 0, False{}, live, active, w, hh}, Nil{})

def key_code(key: T.KeyName) -> U32:
  match key:
    case T.EnterKey{}:
      1
    case T.SpaceKey{}:
      2
    case _:
      0

def arm_allowed(ok: Bool, +s: T.State, code: U32) -> T.Change:
  match ok:
    case False{}:
      D.unchanged(s)
    case True{}:
      T.State{nodes, h, +f, c, k, t, d, live, active, w, hh} = s
      D.finish(s, T.State{nodes, h, f, c, code, f, d, live, active, w, hh}, Nil{})

def arm(+s: T.State, +code: U32) -> T.Change:
  T.State{nodes, h, f, c, k, t, down, live, active, w, hh} = s
  arm_allowed(U32.is_ne(code, 0) && U32.is_ne(f, 0) && U32.is_eq(k, 0) && Bool.not(down), s, code)

def key_down_fresh(key: T.KeyName, s: T.State, shift: Bool) -> T.Change:
  match key:
    case T.TabKey{}:
      tab(s, shift)
    case T.EscapeKey{}:
      cancel(s)
    case _:
      arm(s, key_code(key))

def key_down_allowed(ok: Bool, key: T.KeyName, s: T.State, shift: Bool) -> T.Change:
  match ok:
    case False{}:
      D.unchanged(s)
    case True{}:
      key_down_fresh(key, s, shift)

def key_down(+s: T.State, key: T.KeyName, repeat: Bool, shift: Bool) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  key_down_allowed(Bool.not(repeat) && active, key, s, shift)

def key_up_allowed(ok: Bool, +s: T.State) -> T.Change:
  match ok:
    case False{}:
      D.unchanged(s)
    case True{}:
      T.State{nodes, h, +f, c, k, +target, d, live, active, w, hh} = s
      acts = activation(U32.is_ne(target, 0) && U32.is_eq(f, target) && active, target)
      D.finish(s, T.State{nodes, h, f, c, 0, 0, d, live, active, w, hh}, acts)

def key_up(+s: T.State, key: T.KeyName) -> T.Change:
  T.State{nodes, h, f, c, +k, t, d, live, active, w, hh} = s
  key_up_allowed(U32.is_ne(k, 0) && U32.is_eq(k, key_code(key)), s)

def next_active(next: T.State, before: T.State, active: Bool) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, old, w, hh} = next
  D.finish(before, T.State{nodes, h, f, c, k, t, d, live, active, w, hh}, Nil{})

def window_focus(+s: T.State, +active: Bool) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, was_active, w, hh} = s
  +next = Bool.pick(T.State, active, s, T.State{nodes, 0, 0, 0, 0, 0, False{}, live, False{}, w, hh})
  # The true transition must also restore the delivery gate after a blur.
  next_active(next, s, active)

def resize_allowed(ok: Bool, s: T.State, +w: F32, +h: F32) -> T.Change:
  match ok:
    case False{}:
      D.unchanged(s)
    case True{}:
      T.State{nodes, hover, focus, c, k, t, d, live, active, oldw, oldh} = s
      next = {T.State{nodes, 0, focus, 0, 0, 0, False{}, live, active, w, h} : T.State}
      T.Change{next, Nil{}, [G.Rect{0.0, 0.0, oldw, oldh}, G.Rect{0.0, 0.0, w, h}], True{}}

def resize(+s: T.State, +w: F32, +h: F32) -> T.Change:
  T.State{nodes, hover, focus, c, k, t, d, live, active, oldw, oldh} = s
  resize_allowed(G.valid_length(w) && G.valid_length(h) && (F32.is_ne(oldw, w) || F32.is_ne(oldh, h)), s, w, h)

def text_allowed(ok: Bool, s: T.State, id: U32, text: String) -> T.Change:
  match ok:
    case False{}:
      D.unchanged(s)
    case True{}:
      T.Change{s, [T.TextDelivered{id, text}], Nil{}, False{}}

def text_input(+s: T.State, text: String) -> T.Change:
  T.State{nodes, h, +f, c, k, t, d, live, active, w, hh} = s
  text_allowed(active && U32.is_ne(f, 0), s, f, text)

def close(s: T.State) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  T.Change{T.State{Nil{}, 0, 0, 0, 0, 0, False{}, False{}, False{}, w, hh}, [T.Closed{}], Nil{}, False{}}

def route(event: T.Input, s: T.State) -> T.Change:
  match event:
    case T.PointerMove{x, y}:
      move(s, x, y)
    case T.PointerDown{x, y, b}:
      press(s, x, y, b)
    case T.PointerUp{x, y, b}:
      release(s, x, y, b)
    case T.PointerLeave{}:
      leave(s)
    case T.Cancel{}:
      cancel(s)
    case T.KeyDown{k, repeat, shift}:
      key_down(s, k, repeat, shift)
    case T.KeyUp{k}:
      key_up(s, k)
    case T.TextInput{text}:
      text_input(s, text)
    case T.WindowFocus{active}:
      window_focus(s, active)
    case T.Resize{w, h}:
      resize(s, w, h)
    case T.CloseRequested{}:
      close(s)

def when_live(live: Bool, event: T.Input, s: T.State) -> T.Change:
  match live:
    case False{}:
      D.unchanged(s)
    case True{}:
      route(event, s)

def dispatch(+s: T.State, event: T.Input) -> T.Change:
  T.State{nodes, h, f, c, k, t, d, live, active, w, hh} = s
  when_live(live, event, s)
