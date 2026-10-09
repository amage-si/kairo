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
#
# Text: Ankra's TextTyped (keys, dead keys, compose) and a paste's answer
# (Clipboard{Pasted}) become TextInput; the other clipboard events are the
# host's to serve through Ankra's clipboard.bend and are dropped. Editing
# keys become Editing commands instead of KeyDown (see `binding`). Ankra
# types no text while Ctrl, Alt or Super is held and drops control
# characters, so Ctrl+V, Backspace and Delete never also type.

def by_word(ctrl: Bool) -> T.Motion:
  match ctrl:
    case True{}:
      T.ByWord{}
    case False{}:
      T.ByChar{}

def ctrl_only(ctrl: Bool, command: T.EditCommand) -> Maybe<&2, T.EditCommand>:
  match ctrl:
    case True{}:
      Some{command}
    case False{}:
      None{}

# Delete: Shift (without Ctrl) cuts, Ctrl deletes a word.
def delete_key(ctrl: Bool, shift: Bool) -> Maybe<&2, T.EditCommand>:
  match ctrl:
    case True{}:
      Some{T.DeleteForward{T.ByWord{}}}
    case False{}:
      match shift:
        case True{}:
          Some{T.Cut{}}
        case False{}:
          Some{T.DeleteForward{T.ByChar{}}}

# Insert: Shift pastes, Ctrl copies, alone or with both it is a plain key.
def insert_key(shift: Bool, ctrl: Bool) -> Maybe<&2, T.EditCommand>:
  match shift ctrl:
    case True{} False{}:
      Some{T.Paste{}}
    case False{} True{}:
      Some{T.Copy{}}
    case _ _:
      None{}

# Codes follow Ankra/keys.bend (Base's convention); letters arrive in
# lower case with or without Shift and Caps Lock.
def binding.key(+code: U32, shift: Bool, ctrl: Bool) -> Maybe<&2, T.EditCommand>:
  match code:
    case 63234: # Left
      Some{T.MoveLeft{by_word(ctrl), shift}}
    case 63235: # Right
      Some{T.MoveRight{by_word(ctrl), shift}}
    case 63273: # Home
      Some{T.MoveLeft{T.ToEdge{}, shift}}
    case 63275: # End
      Some{T.MoveRight{T.ToEdge{}, shift}}
    case 127: # Backspace
      Some{T.DeleteBack{by_word(ctrl)}}
    case 63272: # Delete
      delete_key(ctrl, shift)
    case 63271: # Insert
      insert_key(shift, ctrl)
    case 97: # A
      ctrl_only(ctrl, T.SelectAll{})
    case 99: # C
      ctrl_only(ctrl, T.Copy{})
    case 120: # X
      ctrl_only(ctrl, T.Cut{})
    case 118: # V
      ctrl_only(ctrl, T.Paste{})
    case _:
      None{}

def binding.plain(plain: Bool, +code: U32, +mods: U32) -> Maybe<&2, T.EditCommand>:
  match plain:
    case True{}:
      binding.key(code, U32.is_ne((mods .&. 1 : U32), 0), U32.is_ne((mods .&. 2 : U32), 0))
    case False{}:
      None{}

# The editing command of a key press (repeats included), from Ankra's code
# and modifier bits (Shift 1, Ctrl 2, Alt 4, Super 8; Caps Lock ignored):
# Left/Right/Home/End move (Shift selects, Ctrl moves by word on the
# arrows), Backspace/Delete delete (Ctrl by word), Ctrl+A/C/X/V select all,
# copy, cut and paste (Shift ignored), Shift+Insert pastes, Ctrl+Insert
# copies, Shift+Delete cuts. Nothing is bound while Alt or Super is held.
def binding(+code: U32, +mods: U32) -> Maybe<&2, T.EditCommand>:
  binding.plain(U32.is_eq((mods .&. 12 : U32), 0), code, mods)

def key_down(b: Maybe<&2, T.EditCommand>, +code: U32, repeat: Bool, +mods: U32) -> List<&2, T.Input>:
  match b:
    case Some{command}:
      [T.Editing{command}]
    case None{}:
      [T.KeyDown{B.key_name(code), repeat,
        U32.is_ne((mods .&. 1 : U32), 0) || U32.is_eq(code, 25)}]

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
    case A.KeyDown{+code, repeat, +mods}:
      key_down(binding(code, mods), code, repeat, mods)
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
    case A.TextTyped{text}:
      [T.TextInput{text}]
    case A.Clipboard{A.Pasted{text}}:
      [T.TextInput{text}]
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
