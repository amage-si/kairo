import Base
import ./base_adapter.bend as B
import ./main.bend as K
import ./types.bend as T
import ../Tessra/geometry.bend as G
import ../Tessra/test_support.bend as A

type Trial is Data:
  Trial{adapter: B.Adapter, state: T.State, clicks: U32}

def initial() -> Trial:
  Trial{B.init(), T.State{[T.Node{1, G.Rect{10.0, 10.0, 100.0, 40.0}, "A", T.ButtonRole{}, True{}, True{}}], 0, 0, 0, 0, 0, False{}, True{}, True{}, 400.0, 200.0}, 0}

def changed(change: T.Change, adapter: B.Adapter, clicks: U32) -> Trial:
  T.Change{s, actions, dirty, layout} = change
  Trial{adapter, s, (clicks + K.activation_count(actions) : U32)}

def step(trial: Trial, event: T.Input) -> Trial:
  Trial{adapter, s, clicks} = trial
  changed(K.dispatch(s, event), adapter, clicks)

def inputs(events: +List<T.Input>, trial: Trial) -> Trial:
  match events:
    case Nil{}:
      trial
    case Con{event, rest}:
      inputs(rest, step(trial, event))

def normalized(n: B.Normalized, s: T.State, clicks: U32) -> Trial:
  B.Normalized{adapter, events} = n
  inputs(events, Trial{adapter, s, clicks})

def batch(trial: Trial, events: +List<Event>) -> Result<&2, &2, String, Trial>:
  Trial{adapter, s, clicks} = trial
  do Result<&2, &2, String, Trial>:
    n : B.Normalized <- B.normalize(events, adapter, 1.0)
    return normalized(n, s, clicks)

def batches(all: +List<+List<Event>>, trial: Trial) -> Result<&2, &2, String, Trial>:
  match all:
    case Nil{}:
      Done{trial}
    case Con{events, rest}:
      do Result<&2, &2, String, Trial>:
        next : Trial <- batch(trial, events)
        batches(rest, next)

def count(result: Result<&2, &2, String, Trial>, expected: U32) -> Bool:
  match result:
    case Fail{e}:
      False{}
    case Done{Trial{adapter, state, clicks}}:
      U32.is_eq(clicks, expected)

def scale(n: Result<&2, &2, String, B.Normalized>) -> Bool:
  match n:
    case Done{B.Normalized{adapter, Con{T.PointerMove{x, y}, Nil{}}}}:
      F32.is_eq(x, 15.0) && F32.is_eq(y, 20.0)
    case _:
      False{}

def reverse(n: Result<&2, &2, String, B.Normalized>) -> Bool:
  match n:
    case Done{B.Normalized{adapter, Con{T.KeyDown{T.TabKey{}, False{}, True{}}, Nil{}}}}:
      True{}
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    A.expect(count(batches([[Mouse{20, 20, 0, True{}}, Mouse{20, 20, 0, False{}}]], initial()), 1), "Base primary zero maps to one activation")
    A.expect(count(batches([[Mouse{20, 20, 1, True{}}, Mouse{20, 20, 1, False{}}]], initial()), 0), "Base secondary never activates")
    A.expect(count(batches([[Key{9, True{}}, Key{32, True{}}, Key{32, False{}}]], initial()), 0), "activation release is deferred")
    A.expect(count(batches([[Key{9, True{}}, Key{32, True{}}, Key{32, False{}}], Nil{}], initial()), 1), "next empty poll flushes exactly one release")
    A.expect(count(batches([[Key{9, True{}}, Key{32, True{}}, Key{32, False{}}, Key{32, True{}}, Key{32, False{}}], Nil{}], initial()), 1), "same batch X11 repeat pair is collapsed")
    A.expect(count(batches([[Key{9, True{}}, Key{32, True{}}, Key{32, False{}}], [Key{32, True{}}, Key{32, False{}}], Nil{}], initial()), 1), "cross batch X11 repeat pair is collapsed")
    A.expect(count(batches([[Key{9, True{}}, Key{13, True{}}, Key{13, True{}}, Key{13, False{}}], Nil{}], initial()), 1), "duplicate key downs do not rearm")
    A.expect(count(batches([[Key{9, True{}}, Key{13, True{}}, Key{13, False{}}], Nil{}, [Key{13, True{}}, Key{13, False{}}], Nil{}], initial()), 2), "separate real keystrokes remain separate")
    A.expect(scale(B.normalize([Move{30, 40}], B.init(), 2.0)), "physical coordinates explicitly divided by scale")
    A.expect(reverse(B.normalize([Key{25, True{}}], B.init(), 1.0)), "ISO Left Tab is reverse focus navigation")
    A.expect(Result.is_fail(&2, &2, String, B.Normalized, B.normalize(Nil{}, B.init(), 0.0)), "zero scale rejected")
    IO.print("Kairo Base adapter: 11 tests passed")
