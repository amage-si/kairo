import Base
import ../main.bend as K
import ../types.bend as T
import ../../Tessra/geometry.bend as G

# One button driven by a scripted input sequence, without a window.
def button() -> T.Node:
  T.Node{1, G.Rect{20.0, 20.0, 120.0, 44.0}, "OK", T.ButtonRole{}, True{}, True{}}

def script() -> +List<T.Input>:
  # Click inside: one activation.
  [T.PointerMove{30.0, 30.0}, T.PointerDown{30.0, 30.0, 0}, T.PointerUp{30.0, 30.0, 0},
    # Press inside, drag out, release outside: no activation.
    T.PointerDown{30.0, 30.0, 0}, T.PointerMove{300.0, 180.0}, T.PointerUp{300.0, 180.0, 0},
    # Tab to the button, hold Space with a repeat, release: one activation.
    T.KeyDown{T.TabKey{}, False{}, False{}}, T.KeyUp{T.TabKey{}},
    T.KeyDown{T.SpaceKey{}, False{}, False{}}, T.KeyDown{T.SpaceKey{}, True{}, False{}},
    T.KeyUp{T.SpaceKey{}},
    # Enter: one activation.
    T.KeyDown{T.EnterKey{}, False{}, False{}}, T.KeyUp{T.EnterKey{}}]

# Applications consume Change.actions on every step; each Activated counts once.
def tally(change: T.Change, count: U32) -> T.State & U32:
  T.Change{next, actions, dirty, layout} = change
  (next, (count + K.activation_count(actions) : U32))

def advance(acc: T.State & U32, event: T.Input) -> T.State & U32:
  (state, count) = acc
  tally(K.dispatch(state, event), count)

def run(events: +List<T.Input>, acc: T.State & U32) -> U32:
  match events:
    case Nil{}:
      (state, count) = acc
      count
    case Con{event, rest}:
      run(rest, advance(acc, event))

def report(result: Result<&2, &2, T.Error, T.State>) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.die(Unit, 1, "Kairo rejected the nodes")
    case Done{state}:
      IO.print("Kairo: " ++ U32.show(run(script(), (state, 0))) ++ " activations (expected 3)")

def main() -> IO(Unit):
  report(K.init([button()], 320.0, 200.0))
