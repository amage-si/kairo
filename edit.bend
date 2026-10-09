import Base
import ./types.bend as T

# Pure single-line text editing for an editable control (EditRole).
#
# An `Edit` holds the text and two scalar indices into it: the caret and the
# selection anchor (equal when nothing is selected). `count` is the number of
# scalars. The application keeps one `Edit` per editable control, keyed by
# its node id; Kairo's State never holds text.
#
# Caret stops follow Syllo's cluster rule: index 0 and the end are stops,
# and an index whose scalar is a combining mark (U+0300..U+036F) never is,
# so a base character and its marks move and delete as one. A word is a run
# of scalars other than space (U+0020) and NBSP (U+00A0).
#
# The text refuses C0 controls, DEL and C1 controls (LF and CR as a line
# break) and more scalars than the limit. Any other scalar is accepted:
# whether a font can draw it is the caller's decision, made before it
# commits the new Edit.

type Edit is Data:
  Edit{text: String, count: U32, caret: U32, anchor: U32}

# What the application must do for the user after an edit.
type Request is Data:
  NoRequest{}
  CopyText{text: String}
  PasteText{}

type Refusal is Data:
  ControlChar{code: U32}
  LineBreak{}
  TooLong{limit: U32}

# `caret_changed` is True when the caret or the anchor moved.
type Applied is Data:
  Applied{edit: Edit, text_changed: Bool, caret_changed: Bool, request: Request}

def default_limit() -> U32:
  256

def max_limit() -> U32:
  4096

def cap(+limit: U32) -> U32:
  U32.min(limit, max_limit())

def empty() -> Edit:
  Edit{"", 0, 0, 0}

def is_mark(+c: U32) -> Bool:
  U32.is_ge(c, 768) && U32.is_le(c, 879)

def is_space(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 160)

# Anything but C0 controls, DEL and C1 controls.
def allowed(+c: U32) -> Bool:
  U32.is_ge(c, 32) && Bool.not(U32.is_ge(c, 127) && U32.is_le(c, 159))

def refusal(+c: U32) -> Refusal:
  Bool.pick(Refusal, U32.is_eq(c, 10) || U32.is_eq(c, 13), LineBreak{}, ControlChar{c})

# The scalar count of `s`, or the refusal of its first refused scalar.
# `ok` says whether the previous scalar, `code`, was accepted.
def check(s: String, ok: Bool, +code: U32, +n: U32) -> Result<&2, &2, Refusal, U32>:
  match s ok:
    case _ False{}:
      Fail{refusal(code)}
    case SNil{} True{}:
      Done{n}
    case SCon{Chr{+c}, t} True{}:
      check(t, allowed(c), c, (n + 1 : U32))

# `s` without its first `n` scalars; `more` is `n > 0`.
def drop(s: String, more: Bool, +n: U32) -> String:
  match s more:
    case SCon{h, t} True{}:
      drop(t, U32.is_gt(n, 1), (n - 1 : U32))
    case SCon{h, t} False{}:
      SCon{h, t}
    case SNil{} _:
      SNil{}

# The first `n` scalars of `s`, reversed onto `acc`; `more` is `n > 0`.
def rev_take(s: String, more: Bool, +n: U32, acc: String) -> String:
  match s more:
    case SCon{h, t} True{}:
      rev_take(t, U32.is_gt(n, 1), (n - 1 : U32), SCon{h, acc})
    case _ _:
      acc

# `rev` reversed, followed by `tail`.
def onto(rev: String, tail: String) -> String:
  match rev:
    case SNil{}:
      tail
    case SCon{h, t}:
      onto(t, SCon{h, tail})

# `text` with the scalars [lo, hi) replaced by `typed`.
def splice(+text: String, +lo: U32, +hi: U32, typed: String) -> String:
  suffix = drop(text, U32.is_gt(hi, 0), hi)
  onto(rev_take(text, U32.is_gt(lo, 0), lo, ""), onto(String.reverse(typed), suffix))

# The scalars [lo, hi) of `text`.
def slice(+text: String, +lo: U32, +hi: U32) -> String:
  +n = (hi - lo : U32)
  String.reverse(rev_take(drop(text, U32.is_gt(lo, 0), lo), U32.is_gt(n, 0), n, ""))

# The largest caret stop below `limit`, scanning from index `j` with `best`
# found so far; `more` is `j < limit`. Reaching the end returns it.
def stop_below(s: String, more: Bool, +j: U32, +limit: U32, +best: U32) -> U32:
  match s more:
    case _ False{}:
      best
    case SNil{} True{}:
      j
    case SCon{Chr{+c}, t} True{}:
      +next = (j + 1 : U32)
      stop_below(t, U32.is_lt(next, limit), next, limit, Bool.pick(U32, U32.is_eq(j, 0) || Bool.not(is_mark(c)), j, best))

# The smallest caret stop above `i`, scanning from index `j`; `found` says
# the previous index, `at`, was it. Reaching the end returns it.
def stop_above(s: String, found: Bool, +j: U32, +i: U32, +at: U32) -> U32:
  match s found:
    case _ True{}:
      at
    case SNil{} False{}:
      j
    case SCon{Chr{+c}, t} False{}:
      stop_above(t, U32.is_gt(j, i) && Bool.not(is_mark(c)), (j + 1 : U32), i, j)

# The largest word start below `limit` (0 when none): a scalar that is not
# a space, after a space or at index 0, and not a mark past index 0.
def word_below(s: String, more: Bool, +j: U32, +limit: U32, +after_space: Bool, +best: U32) -> U32:
  match s more:
    case _ False{}:
      best
    case SNil{} True{}:
      best
    case SCon{Chr{+c}, t} True{}:
      +space = is_space(c)
      start = after_space && Bool.not(space) && (U32.is_eq(j, 0) || Bool.not(is_mark(c)))
      +next = (j + 1 : U32)
      word_below(t, U32.is_lt(next, limit), next, limit, space, Bool.pick(U32, start, j, best))

# The smallest word end above `i` (the end when none): an index whose
# scalar is a space, after a scalar that is not. `found` says the previous
# index, `at`, was it.
def word_above(s: String, found: Bool, +j: U32, +i: U32, +in_word: Bool, +at: U32) -> U32:
  match s found:
    case _ True{}:
      at
    case SNil{} False{}:
      j
    case SCon{Chr{+c}, t} False{}:
      +space = is_space(c)
      word_above(t, in_word && space && U32.is_gt(j, i), (j + 1 : U32), i, Bool.not(space), j)

def left_of(by: T.Motion, +text: String, +i: U32) -> U32:
  match by:
    case T.ByChar{}:
      stop_below(text, U32.is_gt(i, 0), 0, i, 0)
    case T.ByWord{}:
      word_below(text, U32.is_gt(i, 0), 0, i, True{}, 0)
    case T.ToEdge{}:
      0

def right_of(by: T.Motion, +text: String, +count: U32, +i: U32) -> U32:
  match by:
    case T.ByChar{}:
      stop_above(text, U32.is_ge(i, count), 0, i, count)
    case T.ByWord{}:
      word_above(text, U32.is_ge(i, count), 0, i, False{}, count)
    case T.ToEdge{}:
      count

def is_char(by: T.Motion) -> Bool:
  match by:
    case T.ByChar{}:
      True{}
    case _:
      False{}

# `held`: an unshifted ByChar move collapses a selection onto its edge `i`.
def left_target(held: Bool, by: T.Motion, +text: String, +i: U32) -> U32:
  match held:
    case True{}:
      i
    case False{}:
      left_of(by, text, i)

def right_target(held: Bool, by: T.Motion, +text: String, +count: U32, +i: U32) -> U32:
  match held:
    case True{}:
      i
    case False{}:
      right_of(by, text, count, i)

def unchanged(e: Edit) -> Applied:
  Applied{e, False{}, False{}, NoRequest{}}

def moved(e: Edit, +caret: U32, +anchor: U32) -> Applied:
  Edit{text, count, +old_caret, +old_anchor} = e
  Applied{Edit{text, count, caret, anchor}, False{}, U32.is_ne(caret, old_caret) || U32.is_ne(anchor, old_anchor), NoRequest{}}

# The selection as (start, end), start <= end.
def selection(e: Edit) -> U32 & U32:
  Edit{t, n, +caret, +anchor} = e
  (U32.min(caret, anchor), U32.max(caret, anchor))

def selected(e: Edit) -> String:
  Edit{+text, n, +caret, +anchor} = e
  slice(text, U32.min(caret, anchor), U32.max(caret, anchor))

# With Shift the caret moves from where it is and the anchor stays. Without
# it the edit collapses: from a selection's start (left) or end (right),
# where ByChar stops, while ByWord and ToEdge move on from there.
def move_left(select: Bool, +e: Edit, +by: T.Motion) -> Applied:
  match select:
    case True{}:
      Edit{+text, n, +caret, +anchor} = e
      moved(e, left_target(False{}, by, text, caret), anchor)
    case False{}:
      Edit{+text, n, +caret, +anchor} = e
      +target = left_target(U32.is_ne(caret, anchor) && is_char(by), by, text, U32.min(caret, anchor))
      moved(e, target, target)

def move_right(select: Bool, +e: Edit, +by: T.Motion) -> Applied:
  match select:
    case True{}:
      Edit{+text, +count, +caret, +anchor} = e
      moved(e, right_target(False{}, by, text, count, caret), anchor)
    case False{}:
      Edit{+text, +count, +caret, +anchor} = e
      +target = right_target(U32.is_ne(caret, anchor) && is_char(by), by, text, count, U32.max(caret, anchor))
      moved(e, target, target)

# Removes the scalars [lo, hi) and leaves the caret at lo; `none` when empty.
def removed(none: Bool, +e: Edit, +lo: U32, +hi: U32, request: Request) -> Applied:
  match none:
    case True{}:
      unchanged(e)
    case False{}:
      Edit{+text, +count, +caret, +anchor} = e
      next = {Edit{splice(text, lo, hi, ""), (count - (hi - lo) : U32), lo, lo} : Edit}
      Applied{next, True{}, U32.is_ne(caret, lo) || U32.is_ne(anchor, lo), request}

# A selection is deleted whole; otherwise the motion reaches from the caret.
def back_from(selecting: Bool, by: T.Motion, +text: String, +lo: U32) -> U32:
  match selecting:
    case True{}:
      lo
    case False{}:
      left_of(by, text, lo)

def forward_to(selecting: Bool, by: T.Motion, +text: String, +count: U32, +hi: U32) -> U32:
  match selecting:
    case True{}:
      hi
    case False{}:
      right_of(by, text, count, hi)

def delete_back(+e: Edit, by: T.Motion) -> Applied:
  Edit{+text, n, +caret, +anchor} = e
  +hi = U32.max(caret, anchor)
  +from = back_from(U32.is_ne(caret, anchor), by, text, U32.min(caret, anchor))
  removed(U32.is_eq(from, hi), e, from, hi, NoRequest{})

def delete_forward(+e: Edit, by: T.Motion) -> Applied:
  Edit{+text, +count, +caret, +anchor} = e
  +lo = U32.min(caret, anchor)
  +to = forward_to(U32.is_ne(caret, anchor), by, text, count, U32.max(caret, anchor))
  removed(U32.is_eq(lo, to), e, lo, to, NoRequest{})

def copied(none: Bool, +e: Edit) -> Applied:
  match none:
    case True{}:
      unchanged(e)
    case False{}:
      Applied{e, False{}, False{}, CopyText{selected(e)}}

def copy(+e: Edit) -> Applied:
  Edit{t, n, +caret, +anchor} = e
  copied(U32.is_eq(caret, anchor), e)

def cut(+e: Edit) -> Applied:
  Edit{t, n, +caret, +anchor} = e
  +lo = U32.min(caret, anchor)
  +hi = U32.max(caret, anchor)
  removed(U32.is_eq(lo, hi), e, lo, hi, CopyText{selected(e)})

def select_all(+e: Edit) -> Applied:
  Edit{t, +count, c, a} = e
  moved(e, count, 0)

# Applies a command. Paste only asks the application for the clipboard
# text, which comes back through `insert`.
def apply(+e: Edit, c: T.EditCommand) -> Applied:
  match c:
    case T.MoveLeft{+by, select}:
      move_left(select, e, by)
    case T.MoveRight{+by, select}:
      move_right(select, e, by)
    case T.DeleteBack{by}:
      delete_back(e, by)
    case T.DeleteForward{by}:
      delete_forward(e, by)
    case T.SelectAll{}:
      select_all(e)
    case T.Copy{}:
      copy(e)
    case T.Cut{}:
      cut(e)
    case T.Paste{}:
      Applied{e, False{}, False{}, PasteText{}}

# The first caret stop at or after `at` in the new text.
def stop_from(zero: Bool, +text: String, +count: U32, +at: U32) -> U32:
  match zero:
    case True{}:
      0
    case False{}:
      +before = (at - 1 : U32)
      stop_above(text, U32.is_ge(before, count), 0, before, count)

def put(none: Bool, +e: Edit, +lo: U32, +hi: U32, typed: String, +n: U32) -> Applied:
  match none:
    case True{}:
      unchanged(e)
    case False{}:
      Edit{+text, +count, +caret, +anchor} = e
      +next = splice(text, lo, hi, typed)
      +total = (count - (hi - lo) + n : U32)
      +at = (lo + n : U32)
      +stop = stop_from(U32.is_eq(at, 0), next, total, at)
      Applied{Edit{next, total, stop, stop}, True{}, U32.is_ne(caret, stop) || U32.is_ne(anchor, stop), NoRequest{}}

def fits(ok: Bool, +e: Edit, +lo: U32, +hi: U32, typed: String, +n: U32, +limit: U32) -> Result<&2, &2, Refusal, Applied>:
  match ok:
    case False{}:
      Fail{TooLong{limit}}
    case True{}:
      Done{put(U32.is_eq(n, 0) && U32.is_eq(lo, hi), e, lo, hi, typed, n)}

def inserted(r: Result<&2, &2, Refusal, U32>, +e: Edit, typed: String, +limit: U32) -> Result<&2, &2, Refusal, Applied>:
  match r:
    case Fail{x}:
      Fail{x}
    case Done{+n}:
      Edit{t, +count, +caret, +anchor} = e
      +lo = U32.min(caret, anchor)
      +hi = U32.max(caret, anchor)
      fits(U32.is_le((count - (hi - lo) + n : U32), limit), e, lo, hi, typed, n, limit)

# Replaces the selection (or inserts at the caret) with `typed`, all of it
# or nothing: a refused scalar or a result longer than `limit` (at most
# 4096) refuses the whole insertion. The caret ends after the new text.
def insert(+e: Edit, +typed: String, +limit: U32) -> Result<&2, &2, Refusal, Applied>:
  inserted(check(typed, True{}, 0, 0), e, typed, cap(limit))

def fits_text(ok: Bool, text: String, +n: U32, +limit: U32) -> Result<&2, &2, Refusal, Edit>:
  match ok:
    case False{}:
      Fail{TooLong{limit}}
    case True{}:
      Done{Edit{text, n, n, n}}

def made(r: Result<&2, &2, Refusal, U32>, +text: String, +limit: U32) -> Result<&2, &2, Refusal, Edit>:
  match r:
    case Fail{x}:
      Fail{x}
    case Done{+n}:
      fits_text(U32.is_le(n, limit), text, n, limit)

# An Edit of `text` with the caret at its end, under the same refusals as
# `insert`.
def of(+text: String, +limit: U32) -> Result<&2, &2, Refusal, Edit>:
  made(check(text, True{}, 0, 0), text, cap(limit))

# Moves the caret to `index`, clamped to the text and snapped back to the
# start of its cluster. `extend` keeps the anchor (a drag or Shift+click).
def place(e: Edit, +index: U32, +extend: Bool) -> Edit:
  Edit{+text, +count, caret, +anchor} = e
  +at = stop_below(text, True{}, 0, (U32.min(index, count) + 1 : U32), 0)
  Edit{text, count, at, Bool.pick(U32, extend, anchor, at)}
