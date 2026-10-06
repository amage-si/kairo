import Base
import ./types.bend as T

# Base has no repeat bit or timestamp. Delay activation-key release until the
# next event/poll, collapsing adjacent release/press pairs from X11 autorepeat.
type Adapter is Data:
  Adapter{held: +List<U32>, pending_up: U32}

type Normalized is Data:
  Normalized{adapter: Adapter, events: +List<T.Input>}

type Work is Data:
  Work{adapter: Adapter, reversed: +List<T.Input>}

def init() -> Adapter:
  Adapter{Nil{}, 0}

def contains(keys: +List<U32>, +code: U32) -> Bool:
  match keys:
    case Nil{}:
      False{}
    case Con{k, rest}:
      U32.is_eq(k, code) || contains(rest, code)

def remove(keys: +List<U32>, +code: U32) -> +List<U32>:
  match keys:
    case Nil{}:
      Nil{}
    case Con{+k, rest}:
      +tail = remove(rest, code)
      Bool.pick(+List<U32>, U32.is_eq(k, code), tail, Con{k, tail})

def key_name(code: U32) -> T.KeyName:
  match code:
    case 9:
      T.TabKey{}
    case 25:
      T.TabKey{}
    case 13:
      T.EnterKey{}
    case 32:
      T.SpaceKey{}
    case 27:
      T.EscapeKey{}
    case _:
      T.OtherKey{code}

def is_activation(+code: U32) -> Bool:
  U32.is_eq(code, 13) || U32.is_eq(code, 32)

def key_release(defer: Bool, +keys: +List<U32>, +code: U32) -> Normalized:
  match defer:
    case True{}:
      Normalized{Adapter{keys, code}, Nil{}}
    case False{}:
      Normalized{Adapter{remove(keys, code), 0}, [T.KeyUp{key_name(code)}]}

def key_event(down: Bool, +keys: +List<U32>, +code: U32) -> Normalized:
  match down:
    case True{}:
      +repeat = contains(keys, code)
      shift = contains(keys, 65592) || contains(keys, 65596) || U32.is_eq(code, 25)
      updated = Bool.pick(+List<U32>, repeat, keys, Con{code, keys})
      Normalized{Adapter{updated, 0}, [T.KeyDown{key_name(code), repeat, shift}]}
    case False{}:
      key_release(is_activation(code), keys, code)

def mouse(down: Bool, x: U32, y: U32, button: U32, +scale: F32) -> T.Input:
  match down:
    case True{}:
      T.PointerDown{(U32.to_f32(x) / scale : F32), (U32.to_f32(y) / scale : F32), button}
    case False{}:
      T.PointerUp{(U32.to_f32(x) / scale : F32), (U32.to_f32(y) / scale : F32), button}

def raw(event: Event, adapter: Adapter, +scale: F32) -> Normalized:
  match event:
    case Key{code, down}:
      Adapter{keys, pending} = adapter
      key_event(down, keys, code)
    case Mouse{x, y, button, down}:
      Normalized{adapter, [mouse(down, x, y, button, scale)]}
    case Move{x, y}:
      Normalized{adapter, [T.PointerMove{(U32.to_f32(x) / scale : F32), (U32.to_f32(y) / scale : F32)}]}
    case Close{}:
      Normalized{init(), [T.CloseRequested{}]}
    case _:
      Normalized{adapter, Nil{}}

def pending(adapter: Adapter) -> Normalized:
  match adapter:
    case Adapter{keys, 0}:
      Normalized{Adapter{keys, 0}, Nil{}}
    case Adapter{keys, code}:
      key_release(False{}, keys, code)

def repeat_pair(event: Event, +pending_up: U32) -> Bool:
  match event:
    case Key{code, True{}}:
      U32.is_ne(pending_up, 0) && U32.is_eq(code, pending_up)
    case _:
      False{}

def prepend(before: +List<T.Input>, result: Normalized) -> Normalized:
  Normalized{a, events} = result
  Normalized{a, List.append(&2, T.Input, before, events)}

def flushed(result: Normalized, event: Event, scale: F32) -> Normalized:
  Normalized{a, before} = result
  prepend(before, raw(event, a, scale))

def choose_repeat(repeat: Bool, event: Event, adapter: Adapter, scale: F32) -> Normalized:
  match repeat:
    case True{}:
      Adapter{keys, code} = adapter
      raw(event, Adapter{keys, 0}, scale)
    case False{}:
      flushed(pending(adapter), event, scale)

def step(+event: Event, +adapter: Adapter, scale: F32) -> Normalized:
  Adapter{keys, code} = adapter
  choose_repeat(repeat_pair(event, code), event, adapter, scale)

def accumulate(result: Normalized, reversed: +List<T.Input>) -> Work:
  Normalized{adapter, events} = result
  Work{adapter, List.append(&2, T.Input, List.reverse(&2, T.Input, events), reversed)}

def consume(work: Work, event: Event, scale: F32) -> Work:
  Work{adapter, reversed} = work
  accumulate(step(event, adapter, scale), reversed)

def fold(events: +List<Event>, work: Work, +scale: F32) -> Work:
  match events:
    case Nil{}:
      work
    case Con{event, rest}:
      fold(rest, consume(work, event, scale), scale)

def finish(work: Work) -> Normalized:
  Work{adapter, reversed} = work
  Normalized{adapter, List.reverse(&2, T.Input, reversed)}

def batch(events: +List<Event>, adapter: Adapter, scale: F32) -> Normalized:
  match events:
    case Nil{}:
      pending(adapter)
    case Con{event, rest}:
      finish(fold(Con{event, rest}, Work{adapter, Nil{}}, scale))

def checked(valid: Bool, events: +List<Event>, adapter: Adapter, scale: F32) -> Result<&2, &2, String, Normalized>:
  match valid:
    case False{}:
      Fail{"Kairo Base adapter: scale must be finite and in (0,16]"}
    case True{}:
      Done{batch(events, adapter, scale)}

def normalize(events: +List<Event>, adapter: Adapter, +scale: F32) -> Result<&2, &2, String, Normalized>:
  checked((scale > 0.0 : F32) && (scale <= 16.0 : F32), events, adapter, scale)
