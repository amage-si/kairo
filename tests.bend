import Base
import ./main.bend as K
import ./types.bend as T
import ./dirty.bend as D
import ./nodes.bend as N
import ../Tessra/geometry.bend as G
import ../Tessra/test_support.bend as A

type Trace is Data:
  Trace{state: T.State, clicks: U32, regions: U32}

def button(+id: U32, x: F32, enabled: Bool) -> T.Node:
  T.Node{id, G.Rect{x, 10.0, 100.0, 40.0}, "Button " ++ U32.show(id), T.ButtonRole{}, enabled, True{}}

def nodes() -> +List<T.Node>:
  [button(1, 10.0, True{}), button(2, 130.0, False{}), button(3, 250.0, True{})]

def fixture() -> T.State:
  T.State{nodes(), 0, 0, 0, 0, 0, False{}, True{}, True{}, 400.0, 200.0}

def add(change: T.Change, clicks: U32, regions: U32) -> Trace:
  T.Change{state, actions, dirty, layout} = change
  Trace{state, (clicks + K.activation_count(actions) : U32), (regions + U32.from_nat(List.length(&2, G.Rect, dirty)) : U32)}

def step(trace: Trace, event: T.Input) -> Trace:
  Trace{s, c, d} = trace
  add(K.dispatch(s, event), c, d)

def run(events: +List<T.Input>, trace: Trace) -> Trace:
  match events:
    case Nil{}:
      trace
    case Con{event, rest}:
      run(rest, step(trace, event))

def clicks(trace: Trace) -> U32:
  Trace{s, c, d} = trace
  c

def state(trace: Trace) -> T.State:
  Trace{s, c, d} = trace
  s

def count(events: +List<T.Input>) -> U32:
  clicks(run(events, Trace{fixture(), 0, 0}))

def focus(s: T.State) -> U32:
  T.State{nodes, h, f, c, k, t, d, l, a, w, hh} = s
  f

def region_count(change: T.Change) -> U32:
  T.Change{s, a, dirty, layout} = change
  U32.from_nat(List.length(&2, G.Rect, dirty))

def no_change(change: T.Change) -> Bool:
  match change:
    case T.Change{s, Nil{}, Nil{}, False{}}:
      True{}
    case _:
      False{}

def is_layout(change: T.Change) -> Bool:
  T.Change{s, a, d, layout} = change
  layout

def result_no_change(result: Result<&2, &2, T.Error, T.Change>) -> Bool:
  match result:
    case Fail{e}:
      False{}
    case Done{c}:
      no_change(c)

def mount_effect(result: Result<&2, &2, T.Error, T.Change>) -> Bool:
  match result:
    case Done{T.Change{s, Con{T.Mounted{4}, Nil{}}, Con{r, Nil{}}, False{}}}:
      True{}
    case _:
      False{}

def fail_init(result: Result<&2, &2, T.Error, T.State>) -> Bool:
  Result.is_fail(&2, &2, T.Error, T.State, result)

def down() -> T.Input:
  T.PointerDown{20.0, 20.0, 0}

def up() -> T.Input:
  T.PointerUp{20.0, 20.0, 0}

def tab() -> T.Input:
  T.KeyDown{T.TabKey{}, False{}, False{}}

def space() -> T.Input:
  T.KeyDown{T.SpaceKey{}, False{}, False{}}

def main() -> IO(Unit):
  do IO<Unit>:
    A.expect(Bool.not(fail_init(K.init(nodes(), 400.0, 200.0))), "fixture validates")
    A.expect(U32.is_eq(region_count(K.dispatch(fixture(), T.PointerMove{20.0, 20.0})), 1), "hover dirties only target")
    A.expect(no_change(K.dispatch(K.replay([T.PointerMove{20.0, 20.0}], fixture()), T.PointerMove{21.0, 22.0})), "motion within hovered control is clean")
    A.expect(no_change(K.dispatch(fixture(), T.PointerMove{399.0, 199.0})), "motion outside controls is clean")
    A.expect(U32.is_eq(count([up()]), 0), "release without press does not activate")
    A.expect(U32.is_eq(count([down(), down(), up(), up()]), 1), "duplicate down and up activate exactly once")
    A.expect(U32.is_eq(count([down(), T.PointerMove{399.0, 199.0}, T.PointerUp{399.0, 199.0, 0}]), 0), "release outside never activates")
    A.expect(U32.is_eq(count([down(), T.PointerUp{399.0, 199.0, 0}]), 0), "release coordinates are authoritative without move")
    A.expect(U32.is_eq(count([T.PointerDown{399.0, 199.0, 0}, up()]), 0), "press outside then release inside does not activate")
    A.expect(U32.is_eq(count([down(), T.PointerMove{399.0, 199.0}, T.PointerMove{20.0, 20.0}, up()]), 1), "captured drag out and back can activate")
    A.expect(U32.is_eq(count([T.PointerDown{110.0, 20.0, 0}, T.PointerUp{110.0, 20.0, 0}]), 0), "exclusive boundary is not clickable")
    A.expect(U32.is_eq(count([T.PointerDown{140.0, 20.0, 0}, T.PointerUp{140.0, 20.0, 0}]), 0), "disabled button cannot activate")
    A.expect(U32.is_eq(count([down(), T.Cancel{}, up()]), 0), "cancel consumes pending gesture")
    A.expect(U32.is_eq(count([down(), T.WindowFocus{False{}}, T.WindowFocus{True{}}, up()]), 0), "blur cancels capture")
    A.expect(no_change(K.dispatch(fixture(), T.PointerDown{20.0, 20.0, 2})), "secondary button is ignored")
    A.expect(U32.is_eq(focus(K.replay([tab(), tab()], fixture())), 3), "tab skips disabled nodes")
    A.expect(U32.is_eq(focus(K.replay([tab(), tab(), tab()], fixture())), 1), "tab wraps")
    A.expect(U32.is_eq(focus(K.replay([T.KeyDown{T.TabKey{}, False{}, True{}}], fixture())), 3), "shift tab reverses")
    A.expect(U32.is_eq(count([tab(), space(), T.KeyDown{T.SpaceKey{}, True{}, False{}}, space(), T.KeyUp{T.SpaceKey{}}, T.KeyUp{T.SpaceKey{}}]), 1), "space repeat and duplicate releases suppressed")
    A.expect(U32.is_eq(count([tab(), T.KeyDown{T.EnterKey{}, False{}, False{}}, T.KeyUp{T.EnterKey{}}]), 1), "enter activates on matching release")
    A.expect(U32.is_eq(count([space(), T.KeyUp{T.SpaceKey{}}]), 0), "keyboard without focus is inert")
    A.expect(U32.is_eq(count([tab(), space(), tab(), T.KeyUp{T.SpaceKey{}}]), 0), "focus change cancels keyboard gesture")
    A.expect(U32.is_eq(count([tab(), space(), T.KeyDown{T.EscapeKey{}, False{}, False{}}, T.KeyUp{T.SpaceKey{}}]), 0), "escape cancels keyboard gesture")
    A.expect(U32.is_eq(count([tab(), space(), T.KeyUp{T.EnterKey{}}, T.KeyUp{T.SpaceKey{}}]), 1), "mismatched release cannot activate")
    A.expect(D.pressed(K.replay([down()], fixture()), 1), "pressed projection is visible")
    A.expect(Bool.not(D.pressed(K.replay([down(), T.PointerLeave{}], fixture()), 1)), "leaving hides pressed projection")
    A.expect(no_change(K.dispatch(fixture(), T.Resize{400.0, 200.0})), "same size does not invalidate")
    A.expect(is_layout(K.dispatch(fixture(), T.Resize{300.0, 200.0})), "resize explicitly requests layout")
    A.expect(no_change(K.dispatch(fixture(), T.Resize{F32.neg(1.0), 20.0})), "invalid resize ignored")
    A.expect(U32.is_eq(count([down(), T.CloseRequested{}, up(), down(), up()]), 0), "closed runtime does not dispatch")
    A.expect(fail_init(K.init([button(1, 0.0, True{}), button(1, 200.0, True{})], 400.0, 200.0)), "duplicate ids rejected")
    A.expect(fail_init(K.init([button(0, 0.0, True{})], 400.0, 200.0)), "zero id reserved")
    A.expect(fail_init(K.init(nodes(), F32.div(0.0, 0.0), 200.0)), "NaN viewport rejected")
    A.expect(mount_effect(K.mount(fixture(), button(4, 0.0, True{}))), "mount produces lifecycle and local damage")
    A.expect(U32.is_eq(focus(K.next(K.unmount(K.replay([down()], fixture()), 1))), 0), "unmount clears focus and capture")
    A.expect(no_change(K.unmount(fixture(), 99)), "unmount absent id is clean")
    A.expect(result_no_change(K.set_bounds(fixture(), 1, G.Rect{10.0, 10.0, 100.0, 40.0})), "unchanged bounds are clean")
    A.expect(no_change(K.set_label(fixture(), 1, "Button 1")), "same label is clean")
    A.expect(U32.is_eq(region_count(K.set_label(fixture(), 1, "New label")), 1), "changed label dirties one control")
    A.expect(no_change(K.dispatch(fixture(), T.PointerDown{20.0, 20.0, 1})), "secondary one is ignored")
    A.expect(U32.is_eq(count([down(), up(), down(), up(), tab(), space(), T.KeyUp{T.SpaceKey{}}]), 3), "deterministic total click count")
    IO.print("Kairo: 41 tests passed")
