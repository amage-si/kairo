import Base
import ../main.bend as K
import ../types.bend as T
import ../edit.bend as E
import ../../Tessra/geometry.bend as G

# One editable text control driven by a scripted session, without a window.
# Kairo routes the inputs; the application keeps the Edit for the control
# and applies the actions with edit.bend. A real application maps a pointer
# x to a caret stop with the laid-out text (Syllo); this script assumes a
# fixed 8-unit advance from x = 24.

def field() -> T.Node:
  T.Node{1, G.Rect{20.0, 20.0, 200.0, 32.0}, "Name", T.EditRole{}, True{}, True{}}

def index_at(+x: F32) -> U32:
  U32.from_nat(F32.to_nat(F32.round(F32.max(0.0, ((x - 24.0) / 8.0 : F32)))))

def x_of(+i: U32) -> F32:
  (24.0 + U32.to_f32(i) * 8.0 : F32)

def script() -> +List<T.Input>:
  # Click into the field and type.
  [T.PointerDown{30.0, 30.0, 0}, T.PointerUp{30.0, 30.0, 0},
    T.TextInput{"Olá mundo"},
    # Ctrl+Left, then Shift+End selects "mundo"; Ctrl+C copies it.
    T.Editing{T.MoveLeft{T.ByWord{}, False{}}},
    T.Editing{T.MoveRight{T.ToEdge{}, True{}}},
    T.Editing{T.Copy{}},
    # Typing replaces the selection. Space never activates the field.
    T.TextInput{"ação"},
    T.KeyDown{T.SpaceKey{}, False{}, False{}}, T.KeyUp{T.SpaceKey{}},
    T.TextInput{"!"},
    T.Editing{T.DeleteBack{T.ByChar{}}},
    # Drag across "Olá" and cut it.
    T.PointerDown{x_of(0), 30.0, 0}, T.PointerMove{x_of(2), 30.0}, T.PointerMove{x_of(3), 30.0},
    T.PointerUp{x_of(3), 30.0, 0},
    T.Editing{T.Cut{}},
    # A paste with a line break is refused whole; Ctrl+V asks for the clipboard.
    T.TextInput{"a\nb"},
    T.Editing{T.Paste{}}]

type Run is Data:
  Run{edit: E.Edit, log: List<&2, String>}

def quoted(text: String) -> String:
  "\"" ++ text ++ "\""

def shown(e: E.Edit) -> String:
  E.Edit{text, n, caret, anchor} = e
  quoted(text) ++ " caret " ++ U32.show(caret) ++ " anchor " ++ U32.show(anchor)

def requested(r: E.Request, log: List<&2, String>) -> List<&2, String>:
  match r:
    case E.NoRequest{}:
      log
    case E.CopyText{text}:
      Con{"  copy " ++ quoted(text), log}
    case E.PasteText{}:
      Con{"  paste requested", log}

def refused(r: E.Refusal) -> String:
  match r:
    case E.ControlChar{c}:
      "  refused: control U+" ++ U32.show(c)
    case E.LineBreak{}:
      "  refused: line break"
    case E.TooLong{n}:
      "  refused: longer than " ++ U32.show(n)

def applied(a: E.Applied, log: List<&2, String>) -> Run:
  E.Applied{e, t, c, r} = a
  Run{e, requested(r, log)}

def typed(r: Result<&2, &2, E.Refusal, E.Applied>, e: E.Edit, log: List<&2, String>) -> Run:
  match r:
    case Fail{x}:
      Run{e, Con{refused(x), log}}
    case Done{a}:
      applied(a, log)

def act(a: T.Action, +e: E.Edit, log: List<&2, String>) -> Run:
  match a:
    case T.TextDelivered{id, text}:
      typed(E.insert(e, text, E.default_limit()), e, log)
    case T.EditRequested{id, c}:
      applied(E.apply(e, c), log)
    case T.EditPointer{id, x, y, drag}:
      Run{E.place(e, index_at(x), drag), log}
    case T.Activated{id}:
      Run{e, Con{"  activated (never expected)", log}}
    case _:
      Run{e, log}

def acts(actions: +List<T.Action>, r: Run) -> Run:
  match actions:
    case Nil{}:
      r
    case Con{a, rest}:
      Run{e, log} = r
      acts(rest, act(a, e, log))

def logged(r: Run) -> Run:
  Run{+e, log} = r
  Run{e, Con{shown(e), log}}

type Session is Data:
  Session{state: T.State, run: Run}

# Applications consume Change.actions on every step.
def absorb(change: T.Change, r: Run) -> Session:
  T.Change{next, actions, dirty, layout} = change
  Session{next, logged(acts(actions, r))}

def step(s: Session, event: T.Input) -> Session:
  Session{state, r} = s
  absorb(K.dispatch(state, event), r)

def run(events: +List<T.Input>, s: Session) -> Session:
  match events:
    case Nil{}:
      s
    case Con{event, rest}:
      run(rest, step(s, event))

def joined(lines: List<&2, String>, acc: String) -> String:
  match lines:
    case Nil{}:
      acc
    case Con{line, rest}:
      joined(rest, line ++ "\n" ++ acc)

def finish(s: Session) -> IO(Unit):
  Session{state, Run{e, log}} = s
  IO.print(joined(log, "Kairo edit: " ++ shown(e) ++ " (expected \" ação\" caret 0 anchor 0)"))

def report(result: Result<&2, &2, T.Error, T.State>) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.die(Unit, 1, "Kairo rejected the nodes")
    case Done{state}:
      finish(run(script(), Session{state, Run{E.empty(), Nil{}}}))

def main() -> IO(Unit):
  report(K.init([field()], 320.0, 200.0))
