import Base
import ./ankra_adapter.bend as AA
import ./main.bend as K
import ./types.bend as T
import ../Ankra/window.bend as A
import ../Tessra/geometry.bend as G

# Checks of the Ankra adapter: Ankra's native-window events as Kairo
# inputs, text and editing key bindings, and a button and an editable
# field driven by them end to end. No display needed.

def check(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ message)
    case False{}: IO.die(Unit, 1, "FAIL " ++ message)

def inputs.of(r: Result<&2, &2, String, List<&2, T.Input>>) -> List<&2, T.Input>:
  match r:
    case Fail{m}: Nil{}
    case Done{xs}: xs

def inputs(es: List<&2, A.Input>, +scale: F32) -> List<&2, T.Input>:
  inputs.of(AA.normalize(es, scale))

def failed(r: Result<&2, &2, String, List<&2, T.Input>>) -> Bool:
  match r:
    case Fail{m}: True{}
    case Done{xs}: False{}

# kind * 100 + motion * 10 + select: MoveLeft 1, MoveRight 2, DeleteBack 3,
# DeleteForward 4, SelectAll 5, Copy 6, Cut 7, Paste 8; ByChar 1, ByWord 2,
# ToEdge 3.
def motion(m: T.Motion) -> U32:
  match m:
    case T.ByChar{}: 1
    case T.ByWord{}: 2
    case T.ToEdge{}: 3

def selecting(b: Bool) -> U32:
  match b:
    case True{}: 1
    case False{}: 0

def command(c: T.EditCommand) -> U32:
  match c:
    case T.MoveLeft{m, s}: (100 + motion(m) * 10 + selecting(s) : U32)
    case T.MoveRight{m, s}: (200 + motion(m) * 10 + selecting(s) : U32)
    case T.DeleteBack{m}: (300 + motion(m) * 10 : U32)
    case T.DeleteForward{m}: (400 + motion(m) * 10 : U32)
    case T.SelectAll{}: 500
    case T.Copy{}: 600
    case T.Cut{}: 700
    case T.Paste{}: 800

def kinds(xs: List<&2, T.Input>) -> List<&2, U32>:
  match xs:
    case Nil{}: Nil{}
    case Con{T.PointerMove{x, y}, rest}: 1 <> kinds(rest)
    case Con{T.PointerDown{x, y, b}, rest}: 2 <> kinds(rest)
    case Con{T.PointerUp{x, y, b}, rest}: 3 <> kinds(rest)
    case Con{T.PointerLeave{}, rest}: 4 <> kinds(rest)
    case Con{T.KeyDown{k, r, s}, rest}: 5 <> kinds(rest)
    case Con{T.KeyUp{k}, rest}: 6 <> kinds(rest)
    case Con{T.WindowFocus{f}, rest}: 7 <> kinds(rest)
    case Con{T.Resize{w, h}, rest}: 8 <> kinds(rest)
    case Con{T.CloseRequested{}, rest}: 9 <> kinds(rest)
    case Con{T.TextInput{t}, rest}: 10 <> kinds(rest)
    case Con{T.Editing{c}, rest}: (1000 + command(c) : U32) <> kinds(rest)
    case Con{e, rest}: 0 <> kinds(rest)

# The kinds of one key press with the given modifier bits.
def pressed(+code: U32, +mods: U32) -> List<&2, U32>:
  kinds(inputs([A.KeyDown{code, False{}, mods}], 1.0))

# The kinds of one press per (code, mods) pair, in order.
def presses(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Con{+code, Con{+mods, rest}}:
      List.append(&2, U32, pressed(code, mods), presses(rest))
    case _:
      Nil{}

def text_is(xs: List<&2, T.Input>, t: String) -> Bool:
  match xs:
    case Con{T.TextInput{a}, Nil{}}: String.eq(a, t)
    case _: False{}

def same(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}: True{}
    case Con{a, ra} Con{b, rb}: U32.is_eq(a, b) && same(ra, rb)
    case _ _: False{}

def resize_is(xs: List<&2, T.Input>, +w: F32, +h: F32) -> Bool:
  match xs:
    case Con{T.Resize{a, b}, Nil{}}: F32.is_eq(a, w) && F32.is_eq(b, h)
    case _: False{}

def press_at(xs: List<&2, T.Input>, +x: F32, +y: F32, +button: U32) -> Bool:
  match xs:
    case Con{T.PointerDown{a, b, c}, Nil{}}: F32.is_eq(a, x) && F32.is_eq(b, y) && U32.is_eq(c, button)
    case _: False{}

def shifted_tab(xs: List<&2, T.Input>) -> Bool:
  match xs:
    case Con{T.KeyDown{T.TabKey{}, False{}, True{}}, Nil{}}: True{}
    case _: False{}

def repeated_space(xs: List<&2, T.Input>) -> Bool:
  match xs:
    case Con{T.KeyDown{T.SpaceKey{}, True{}, False{}}, Nil{}}: True{}
    case _: False{}

# A button at (10, 10, 100, 40) driven by Ankra events.
def state() -> T.State:
  T.State{[T.Node{1, G.Rect{10.0, 10.0, 100.0, 40.0}, "A", T.ButtonRole{}, True{}, True{}}],
    0, 0, 0, 0, 0, False{}, True{}, True{}, 400.0, 200.0}

def activated(c: T.Change) -> U32:
  T.Change{s, actions, d, l} = c
  K.activation_count(actions)

def run(xs: List<&2, T.Input>, s: T.State, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{x, rest}:
      +c = K.dispatch(s, x)
      run(rest, K.next(c), (n + activated(c) : U32))

# A button (1) and editable text (5) below it, in Tab order.
def field_state() -> T.State:
  T.State{[T.Node{1, G.Rect{10.0, 10.0, 100.0, 40.0}, "A", T.ButtonRole{}, True{}, True{}},
    T.Node{5, G.Rect{10.0, 60.0, 200.0, 30.0}, "Name", T.EditRole{}, True{}, True{}}],
    0, 0, 0, 0, 0, False{}, True{}, True{}, 400.0, 200.0}

# Activated 1, TextDelivered 2, EditPointer 4, EditRequested 1000 + command.
def action_kinds(actions: +List<T.Action>) -> List<&2, U32>:
  match actions:
    case Nil{}: Nil{}
    case Con{T.Activated{id}, rest}: 1 <> action_kinds(rest)
    case Con{T.TextDelivered{id, t}, rest}: 2 <> action_kinds(rest)
    case Con{T.EditPointer{id, x, y, d}, rest}: 4 <> action_kinds(rest)
    case Con{T.EditRequested{id, c}, rest}: (1000 + command(c) : U32) <> action_kinds(rest)
    case Con{other, rest}: 0 <> action_kinds(rest)

def action_texts(actions: +List<T.Action>) -> String:
  match actions:
    case Nil{}: ""
    case Con{T.TextDelivered{id, t}, rest}: t ++ action_texts(rest)
    case Con{other, rest}: action_texts(rest)

def change_kinds(c: T.Change) -> List<&2, U32>:
  T.Change{s, actions, d, l} = c
  action_kinds(actions)

def change_texts(c: T.Change) -> String:
  T.Change{s, actions, d, l} = c
  action_texts(actions)

def acted(xs: List<&2, T.Input>, s: T.State) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      +c = K.dispatch(s, x)
      List.append(&2, U32, change_kinds(c), acted(rest, K.next(c)))

def typed(xs: List<&2, T.Input>, s: T.State) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      +c = K.dispatch(s, x)
      change_texts(c) ++ typed(rest, K.next(c))

# Every Kairo action of Ankra events on the button-and-field window.
def field_actions(es: List<&2, A.Input>) -> List<&2, U32>:
  acted(inputs(es, 1.0), field_state())

def field_text(es: List<&2, A.Input>) -> String:
  typed(inputs(es, 1.0), field_state())

# Tab twice focuses the field; then "a" typed, Backspace held (two
# repeats), Ctrl+V and its answer, Space, Enter.
def field_session() -> List<&2, A.Input>:
  [A.KeyDown{9, False{}, 0}, A.KeyUp{9, 0}, A.KeyDown{9, False{}, 0}, A.KeyUp{9, 0},
    A.KeyDown{97, False{}, 0}, A.TextTyped{"a"}, A.KeyUp{97, 0},
    A.KeyDown{127, False{}, 0}, A.KeyDown{127, True{}, 0}, A.KeyDown{127, True{}, 0}, A.KeyUp{127, 0},
    A.KeyDown{118, False{}, 2}, A.KeyUp{118, 2}, A.Clipboard{A.Pasted{"café"}},
    A.KeyDown{32, False{}, 0}, A.TextTyped{" "}, A.KeyUp{32, 0},
    A.KeyDown{13, False{}, 0}, A.KeyUp{13, 0}]

def activations(es: List<&2, A.Input>) -> U32:
  run(inputs(es, 1.0), state(), 0)

def main() -> IO(Unit):
  do IO<Unit>:
    check(same(kinds(inputs([A.PointerMoved{1.0, 2.0}, A.PointerDown{1.0, 2.0, 0, 0}, A.PointerUp{1.0, 2.0, 0, 0},
      A.PointerLeft{}, A.KeyDown{32, False{}, 0}, A.KeyUp{32, 0}, A.Focused{False{}}, A.Resized{800, 600},
      A.CloseRequested{}], 1.0)), [1, 2, 3, 4, 5, 6, 7, 8, 9]), "every Kairo input kind, in order")
    check(same(kinds(inputs([A.Moved{3.0, 4.0}, A.Exposed{}, A.Shown{True{}}, A.PointerEntered{1.0, 1.0},
      A.Wheel{1.0, 1.0, 0.0, 1.0}], 1.0)), []), "window position, exposure, visibility, entering and wheel are dropped")
    check(resize_is(inputs([A.Resized{800, 600}], 2.0), 400.0, 300.0), "resize in logical units")
    check(press_at(inputs([A.PointerDown{50.0, 30.0, 1, 0}], 2.0), 25.0, 15.0, 1), "pointer in logical units, button kept")
    check(shifted_tab(inputs([A.KeyDown{25, False{}, 1}], 1.0)), "Shift+Tab")
    check(repeated_space(inputs([A.KeyDown{32, True{}, 0}], 1.0)), "a repeat stays a repeat")
    check(failed(AA.normalize([A.Exposed{}], 0.0)) && failed(AA.normalize([A.Exposed{}], 17.0)), "invalid scale rejected")
    check(U32.is_eq(activations([A.PointerMoved{20.0, 20.0}, A.PointerDown{20.0, 20.0, 0, 0},
      A.PointerUp{20.0, 20.0, 0, 0}]), 1), "click activates once")
    check(U32.is_eq(activations([A.KeyDown{9, False{}, 0}, A.KeyDown{32, False{}, 0}, A.KeyDown{32, True{}, 0},
      A.KeyDown{32, True{}, 0}, A.KeyUp{32, 0}]), 1), "Tab, then Space held with repeats and released, activates once without waiting for another event")
    check(U32.is_eq(activations([A.KeyDown{9, False{}, 0}, A.KeyDown{13, False{}, 0}, A.Focused{False{}},
      A.KeyUp{13, 0}]), 0), "losing window focus cancels a pending Enter")
    check(text_is(inputs([A.TextTyped{"ã"}], 1.0), "ã"), "typed text becomes TextInput")
    check(text_is(inputs([A.Clipboard{A.Pasted{"café"}}], 1.0), "café"), "a paste's answer becomes TextInput")
    check(same(kinds(inputs([A.Clipboard{A.Lost{}}, A.Clipboard{A.PasteFailed{61}},
      A.Clipboard{A.Asked{A.Request{1, 2, 3, 4, 5}}}], 1.0)), []), "clipboard requests, loss and failures are the host's, not Kairo's")
    check(same(presses([63234, 0, 63234, 1, 63234, 2, 63234, 3]),
      [1110, 1111, 1120, 1121]), "Left moves; Shift selects, Ctrl moves by word")
    check(same(presses([63235, 0, 63235, 1, 63235, 2, 63235, 3]),
      [1210, 1211, 1220, 1221]), "Right moves; Shift selects, Ctrl moves by word")
    check(same(presses([63273, 0, 63273, 1, 63275, 0, 63275, 1, 63275, 2]),
      [1130, 1131, 1230, 1231, 1230]), "Home and End move to the edges; Shift selects")
    check(same(presses([127, 0, 127, 2, 127, 1, 63272, 0, 63272, 2]),
      [1310, 1320, 1310, 1410, 1420]), "Backspace and Delete; Ctrl deletes a word")
    check(same(presses([97, 2, 99, 2, 120, 2, 118, 2, 118, 3, 118, 18]),
      [1500, 1600, 1700, 1800, 1800, 1800]), "Ctrl+A/C/X/V, also with Shift or Caps Lock")
    check(same(presses([63271, 1, 63271, 2, 63272, 1, 63271, 0, 63271, 3]),
      [1800, 1600, 1700, 5, 5]), "Shift+Insert pastes, Ctrl+Insert copies, Shift+Delete cuts; plain Insert is a key")
    check(same(presses([97, 0, 118, 1, 63234, 4, 63234, 8, 118, 6]),
      [5, 5, 5, 5, 5]), "letters without Ctrl, and anything with Alt or Super, stay keys")
    check(same(kinds(inputs([A.KeyDown{127, False{}, 0}, A.KeyDown{127, True{}, 0}, A.KeyDown{127, True{}, 0},
      A.KeyUp{127, 0}], 1.0)), [1310, 1310, 1310, 6]), "held Backspace deletes on every repeat")
    check(same(kinds(inputs([A.KeyDown{118, False{}, 2}, A.KeyUp{118, 2}], 1.0)), [1800, 6]),
      "Ctrl+V is only Paste: no KeyDown, and Ankra types nothing under Ctrl")
    check(same(kinds(inputs([A.KeyDown{32, False{}, 0}, A.TextTyped{" "}, A.KeyUp{32, 0},
      A.KeyDown{13, False{}, 0}, A.KeyUp{13, 0}, A.KeyDown{9, False{}, 1}], 1.0)), [5, 10, 6, 5, 6, 5]),
      "Space, Enter and Tab stay keys")
    check(same(field_actions([A.KeyDown{9, False{}, 0}, A.KeyDown{97, False{}, 2}, A.KeyDown{63234, False{}, 1},
      A.KeyDown{127, False{}, 0}, A.KeyDown{118, False{}, 2}, A.Clipboard{A.Pasted{"x"}},
      A.KeyDown{32, False{}, 0}, A.TextTyped{" "}, A.KeyUp{32, 0}]), [1]),
      "bindings and text do nothing to a focused button, and Space still activates it once")
    check(same(field_actions(field_session()), [2, 1310, 1310, 1310, 1800, 2, 2]),
      "a focused field gets text, each Backspace repeat, Paste and its text; Space and Enter never activate")
    check(String.eq(field_text(field_session()), "acafé "), "the field receives the typed and pasted text in order")
    check(same(field_actions([A.KeyDown{9, False{}, 0}, A.KeyDown{9, False{}, 0}, A.KeyUp{180, 0},
      A.KeyUp{97, 0}, A.TextTyped{"á"}]), [2]) && String.eq(field_text([A.KeyDown{9, False{}, 0},
      A.KeyDown{9, False{}, 0}, A.KeyUp{180, 0}, A.KeyUp{97, 0}, A.TextTyped{"á"}]), "á"),
      "a dead-key sequence (only key-ups, then text) types once and nothing else")
    check(same(field_actions([A.KeyDown{9, False{}, 0}, A.KeyUp{32, 0}, A.KeyUp{13, 0}, A.TextTyped{"´"}]), []),
      "key-ups without a press (dead keys) never activate a focused button")
    IO.print("27 Kairo Ankra-adapter checks passed")
