import Base
import ./ankra_adapter.bend as AA
import ./main.bend as K
import ./types.bend as T
import ../Ankra/window.bend as A
import ../Tessra/geometry.bend as G

# Checks of the Ankra adapter: Ankra's native-window events as Kairo
# inputs, and a button driven by them end to end. No display needed.

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
    case Con{e, rest}: 0 <> kinds(rest)

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
    IO.print("10 Kairo Ankra-adapter checks passed")
