import Base
import ./types.bend as T
import ./base_adapter.bend as B
import ../Ankra/window.bend as A

# Normalizes the events of Ankra's native window (Ankra/window.bend) into
# Kairo inputs, with a device scale from physical pixels to logical units.
#
# Unlike Base's window, Ankra flags key repeats itself (from X11 detectable
# autorepeat, or by collapsing release+press pairs with one timestamp), so
# no key release is deferred to a later poll: an idle window may wait for
# events without a deadline. Key codes follow Base's convention, so names
# come from base_adapter. Shift comes from the event's modifier bits
# (Shift+Tab also arrives as code 25). Window focus, resize and close map
# to Kairo's own inputs; position, exposure, visibility, entering and the
# wheel do not concern Kairo and are dropped.

def logical(+v: F32, +scale: F32) -> F32:
  (v / scale : F32)

def input(e: A.Input, +scale: F32) -> List<&2, T.Input>:
  match e:
    case A.Resized{w, h}:
      [T.Resize{logical(U32.to_f32(w), scale), logical(U32.to_f32(h), scale)}]
    case A.Focused{g}:
      [T.WindowFocus{g}]
    case A.CloseRequested{}:
      [T.CloseRequested{}]
    case A.KeyDown{+code, repeat, mods}:
      [T.KeyDown{B.key_name(code), repeat,
        U32.is_ne((mods .&. 1 : U32), 0) || U32.is_eq(code, 25)}]
    case A.KeyUp{code, mods}:
      [T.KeyUp{B.key_name(code)}]
    case A.PointerMoved{x, y}:
      [T.PointerMove{logical(x, scale), logical(y, scale)}]
    case A.PointerDown{x, y, b, m}:
      [T.PointerDown{logical(x, scale), logical(y, scale), b}]
    case A.PointerUp{x, y, b, m}:
      [T.PointerUp{logical(x, scale), logical(y, scale), b}]
    case A.PointerLeft{}:
      [T.PointerLeave{}]
    case _:
      Nil{}

def inputs(es: List<&2, A.Input>, +scale: F32) -> List<&2, T.Input>:
  match es:
    case Nil{}:
      Nil{}
    case Con{e, rest}:
      List.append(&2, T.Input, input(e, scale), inputs(rest, scale))

def normalize.checked(ok: Bool, es: List<&2, A.Input>, +scale: F32) ->
  Result<&2, &2, String, List<&2, T.Input>>:
  match ok:
    case False{}:
      Fail{"Kairo Ankra adapter: scale must be finite and in (0,16]"}
    case True{}:
      Done{inputs(es, scale)}

# The events of one wait, in order, as Kairo inputs. The scale must be
# finite and in (0, 16].
def normalize(es: List<&2, A.Input>, +scale: F32) -> Result<&2, &2, String, List<&2, T.Input>>:
  normalize.checked((scale > 0.0 : F32) && (scale <= 16.0 : F32), es, scale)
