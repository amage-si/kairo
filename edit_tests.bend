import Base
import ./types.bend as T
import ./edit.bend as E
import ../Tessra/test_support.bend as A

# One scalar as a String: combining marks, NBSP and controls stay visible.
def sc(+code: U32) -> String:
  SCon{Chr{code}, ""}

# "e" + U+0301 COMBINING ACUTE ACCENT: one cluster of two scalars.
def acute() -> String:
  "e" ++ sc(769)

def made(r: Result<&2, &2, E.Refusal, E.Edit>) -> E.Edit:
  match r:
    case Fail{x}:
      E.empty()
    case Done{e}:
      e

def ed(text: String) -> E.Edit:
  made(E.of(text, E.default_limit()))

# `text` with the caret at `caret` and the anchor at `anchor`.
def at(text: String, +caret: U32, +anchor: U32) -> E.Edit:
  E.place(E.place(ed(text), anchor, False{}), caret, True{})

def edit(a: E.Applied) -> E.Edit:
  E.Applied{e, t, c, r} = a
  e

def run(cmds: List<&2, T.EditCommand>, e: E.Edit) -> E.Edit:
  match cmds:
    case Nil{}:
      e
    case Con{c, rest}:
      run(rest, edit(E.apply(e, c)))

def inserted(r: Result<&2, &2, E.Refusal, E.Applied>) -> E.Edit:
  match r:
    case Fail{x}:
      E.empty()
    case Done{a}:
      edit(a)

def typed(e: E.Edit, text: String) -> E.Edit:
  inserted(E.insert(e, text, E.default_limit()))

def holds(e: E.Edit, text: String, +caret: U32, +anchor: U32) -> Bool:
  E.Edit{t, n, c, a} = e
  String.eq(t, text) && U32.is_eq(c, caret) && U32.is_eq(a, anchor)

def count(e: E.Edit) -> U32:
  E.Edit{t, n, c, a} = e
  n

def caret(e: E.Edit) -> U32:
  E.Edit{t, n, c, a} = e
  c

def nothing(a: E.Applied) -> Bool:
  match a:
    case E.Applied{e, False{}, False{}, E.NoRequest{}}:
      True{}
    case _:
      False{}

def copies(a: E.Applied, text: String, changed: Bool) -> Bool:
  match a:
    case E.Applied{e, t, c, E.CopyText{s}}:
      String.eq(s, text) && Bool.not(Bool.xor(t, changed))
    case _:
      False{}

def pastes(a: E.Applied) -> Bool:
  match a:
    case E.Applied{e, False{}, False{}, E.PasteText{}}:
      True{}
    case _:
      False{}

def refused(r: Result<&2, &2, E.Refusal, E.Edit>) -> U32:
  match r:
    case Done{e}:
      0
    case Fail{E.LineBreak{}}:
      1
    case Fail{E.ControlChar{c}}:
      (1000 + c : U32)
    case Fail{E.TooLong{n}}:
      (100000 + n : U32)

def insert_refused(r: Result<&2, &2, E.Refusal, E.Applied>) -> U32:
  match r:
    case Done{a}:
      0
    case Fail{E.LineBreak{}}:
      1
    case Fail{E.ControlChar{c}}:
      (1000 + c : U32)
    case Fail{E.TooLong{n}}:
      (100000 + n : U32)

def letters(+n: Nat, text: String) -> String:
  match n:
    case 0n:
      text
    case 1n+p:
      letters(p, SCon{'a', text})

def left(by: T.Motion) -> T.EditCommand:
  T.MoveLeft{by, False{}}

def right(by: T.Motion) -> T.EditCommand:
  T.MoveRight{by, False{}}

def words() -> String:
  "olá mundo  feliz"

def main() -> IO(Unit):
  do IO<Unit>:
    A.expect(U32.is_eq(count(ed("ação")), 4), "ação counts 4 scalars")
    A.expect(holds(ed("ação"), "ação", 4, 4), "of puts the caret at the end")
    A.expect(holds(typed(E.empty(), "a"), "a", 1, 1), "insert into empty text")
    A.expect(holds(typed(at("olá", 1, 1), "X"), "oXlá", 2, 2), "insert at the caret")
    A.expect(holds(typed(at("olá mundo", 3, 0), "oi"), "oi mundo", 2, 2), "insert replaces the selection")
    A.expect(nothing(E.apply(at("abc", 0, 0), T.DeleteBack{T.ByChar{}})), "Backspace at 0 changes nothing")
    A.expect(nothing(E.apply(ed("abc"), T.DeleteForward{T.ByChar{}})), "Delete at the end changes nothing")
    A.expect(holds(run([T.DeleteBack{T.ByChar{}}], ed("caf" ++ acute())), "caf", 3, 3), "Backspace removes a whole cluster")
    A.expect(holds(run([T.DeleteForward{T.ByChar{}}], at("caf" ++ acute() ++ "!", 3, 3)), "caf!", 3, 3), "Delete removes a whole cluster")
    A.expect(U32.is_eq(caret(run([right(T.ByChar{})], at(acute() ++ "x", 0, 0))), 2), "é as two scalars is one stop to the right")
    A.expect(U32.is_eq(caret(run([left(T.ByChar{})], at(acute() ++ "x", 2, 2))), 0), "é as two scalars is one stop to the left")
    A.expect(U32.is_eq(caret(at("caf" ++ acute(), 4, 4)), 3), "place snaps off a combining mark")
    A.expect(holds(at("abc", 99, 1), "abc", 3, 1), "place clamps to the end and extends")
    A.expect(holds(run([T.MoveRight{T.ByChar{}, True{}}, T.MoveRight{T.ByChar{}, True{}}], at("abc", 0, 0)), "abc", 2, 0), "Shift+Right extends the selection")
    A.expect(String.eq(E.selected(at("abc", 0, 2)), "ab"), "selected text in either direction")
    A.expect(holds(run([left(T.ByChar{})], at("abcd", 3, 1)), "abcd", 1, 1), "Left collapses a selection to its start")
    A.expect(holds(run([right(T.ByChar{})], at("abcd", 1, 3)), "abcd", 3, 3), "Right collapses a selection to its end")
    A.expect(holds(run([left(T.ToEdge{})], at("abc", 2, 2)), "abc", 0, 0), "Home goes to the start")
    A.expect(holds(run([T.MoveRight{T.ToEdge{}, True{}}], at("abc", 1, 1)), "abc", 3, 1), "Shift+End selects to the end")
    A.expect(holds(run([right(T.ByWord{}), right(T.ByWord{}), right(T.ByWord{})], at(words(), 0, 0)), words(), 16, 16), "word moves right")
    A.expect(holds(run([right(T.ByWord{})], at(words(), 3, 3)), words(), 9, 9), "word move right skips spaces to the next end")
    A.expect(holds(run([left(T.ByWord{}), left(T.ByWord{})], ed(words())), words(), 4, 4), "word moves left")
    A.expect(holds(run([left(T.ByWord{}), left(T.ByWord{}), left(T.ByWord{})], ed(words())), words(), 0, 0), "word moves left reach the start")
    A.expect(holds(run([right(T.ByWord{})], at("a" ++ sc(160) ++ "b", 0, 0)), "a" ++ sc(160) ++ "b", 1, 1), "NBSP separates words")
    A.expect(holds(run([T.DeleteBack{T.ByWord{}}], at(words(), 9, 9)), "olá   feliz", 4, 4), "Ctrl+Backspace deletes a word")
    A.expect(holds(run([T.DeleteForward{T.ByWord{}}], at(words(), 3, 3)), "olá  feliz", 3, 3), "Ctrl+Delete deletes to the next word end")
    A.expect(holds(run([T.DeleteBack{T.ToEdge{}}], at("abcd", 3, 1)), "ad", 1, 1), "deleting with a selection removes only the selection")
    A.expect(holds(run([T.SelectAll{}], at("olá", 1, 1)), "olá", 3, 0), "SelectAll")
    A.expect(copies(E.apply(at(words(), 9, 4), T.Copy{}), "mundo", False{}), "Copy asks to copy the selection")
    A.expect(nothing(E.apply(at(words(), 4, 4), T.Copy{})), "Copy without a selection does nothing")
    A.expect(copies(E.apply(at(words(), 4, 9), T.Cut{}), "mundo", True{}), "Cut asks to copy and deletes")
    A.expect(holds(run([T.Cut{}], at(words(), 4, 9)), "olá   feliz", 4, 4), "Cut removes the selection")
    A.expect(pastes(E.apply(at("abc", 1, 1), T.Paste{})), "Paste asks for the clipboard and changes nothing")
    A.expect(nothing(E.apply(at("abc", 0, 0), left(T.ByChar{}))), "Left at the start reports no change")
    A.expect(U32.is_eq(refused(E.of("a\nb", 256)), 1), "LF refused as a line break")
    A.expect(U32.is_eq(refused(E.of("a" ++ sc(13), 256)), 1), "CR refused as a line break")
    A.expect(U32.is_eq(refused(E.of("a" ++ sc(9), 256)), 1009), "TAB refused as a control")
    A.expect(U32.is_eq(refused(E.of(sc(127), 256)), 1127), "DEL refused")
    A.expect(U32.is_eq(refused(E.of(sc(133), 256)), 1133), "C1 control refused")
    A.expect(U32.is_eq(refused(E.of("abcde", 4)), 100004), "text over the limit refused")
    A.expect(U32.is_eq(insert_refused(E.insert(at("abc", 1, 1), "x\ny", 256)), 1), "a paste with a line break is refused whole")
    A.expect(U32.is_eq(insert_refused(E.insert(at("abc", 3, 3), "de", 4)), 100004), "insert over the limit refused")
    A.expect(U32.is_eq(insert_refused(E.insert(at("abc", 3, 0), "wxyz", 4)), 0), "replacing a selection may reach the limit")
    A.expect(U32.is_eq(refused(E.of(letters(4097n, ""), 10000)), 104096), "the limit is capped at 4096")
    A.expect(holds(typed(at("abc", 1, 1), ""), "abc", 1, 1), "empty text inserts nothing")
    A.expect(holds(typed(at("e", 1, 1), sc(769)), acute(), 2, 2), "a typed combining mark joins the cluster")
    IO.print("Kairo edit: 46 tests passed")
