# Deviations from upstream Rich

Intentional differences between rich.mbt and Rich 15.0.0, by module.

## General

* Offsets into strings (spans, `Text.length()`, `divide`, regex matches) are
  UTF-16 code units, not code points. Identical for text without astral
  characters (most emoji are astral).
* `__rich__` is not supported: implement `Renderable` instead. Arbitrary
  non-renderable values cannot be printed; wrap them (`@pretty.Pretty`) or
  format them as strings.
* `Console.print(*objects)` → `print(object)` and `print_many(objects)`.
* No Jupyter, no legacy Windows console API (`legacy_windows` only affects
  layout), no `file_proxy` redirection, no `inspect`.

## style

* Upstream caches the ANSI codes of a style for the first color system it
  is rendered with, so a style shared between consoles with different color
  systems renders with the wrong codes (upstream bug). rich.mbt caches per
  color system.
* Meta data is a `Map[String, Json]` (upstream pickles arbitrary values).
* Link ids are generated from a counter seeded with the clock.

## markup

* Emoji variants (`emoji_variant`) are also applied to emoji inside markup
  (upstream only applies them when the text contains no markup).
* `[@handler(...)]` parameters are parsed by a subset of Python's
  `literal_eval` (numbers, strings, tuples, lists, dicts, True/False/None)
  and stored as JSON.

## console

* `log` reports the MoonBit source location (`SourceLoc`) of the call;
  `log_locals` is not supported.
* `status`, `print_exception` and `pager` are functions of the `status` /
  `traceback` packages or take closures (`console.pager(fn() { ... })`).
* Contexts (`capture`, `use_theme`, `screen`, `pager`) take closures.
* `input` reads from stdin via the native runtime (not available on wasm/js).

## json

* `JSON::from_data` takes a MoonBit `Json`; numbers without a textual
  representation are printed as integers when integral.

## pretty (and repr)

* No object introspection. A value is pretty printed through the
  `PrettyRepr` trait, whose `pretty_node(ctx)` builds the upstream `Node`
  tree with the `PrettyContext` builders: `leaf` / `str_leaf`, `sequence`,
  `tuple`, `mapping` (upstream's container branch), `rich_repr`
  (`__rich_repr__` and attrs objects), `dataclass`, `namedtuple`. The
  `Node` layout algorithm (`Node::render`, `_Line` expansion) is ported
  exactly.
* Builtin values are formatted as the corresponding Python value: integers,
  `Double`/`Float` via `py_float_repr`, `Bool` → `True`/`False`, `Unit` →
  `None`, `Char`/`String` → `repr(str)`, `Bytes` → `repr(bytes)`,
  `Option` → `None` or the value, `Array`/`FixedArray`/`ArrayView`/
  `ReadOnlyArray` → list, `Map`/`HashMap` → dict, `Set`/`HashSet` → set
  (in iteration order), `Deque` → `deque([...])`, MoonBit tuples → tuple,
  `Json`/`JsonValue` → what `json.loads` returns. `Result` has no Python
  counterpart and renders as `Ok(...)` / `Err(...)`; `Error` uses its
  `Show` output. `@pretty.Tuple` (1-tuples, empty tuples, heterogeneous
  tuples) and `@pretty.Dict` (keys of different types) model Python values
  MoonBit has no literal for.
* Values known only through `Show`/`Debug` are opaque leaves
  (`@pretty.shown`, `@pretty.debugged`, `@pretty.Leaf`); `@debug.Repr`
  cannot be traversed. Python-specific containers (`defaultdict`,
  `Counter`, `array`, `deque(maxlen=)`, `frozenset`, `UserDict`, ...) are
  not built in but can be modelled with `sequence`/`mapping` and custom
  braces.
* Reference cycles: upstream uses `id(obj)`. MoonBit has no identity for
  arbitrary values, so detection is opt-in: objects that may be part of a
  cycle carry a `PrettyId` and pass it to the builders (`id=`) or use
  `PrettyContext::visit`. A cycle through containers without an id
  recurses without bound.
* Broken `__repr__` (`<repr-error ...>`), broken/lying `__getattr__`,
  custom `__repr__` overrides of containers and namedtuples, and attrs
  `repr=callable` fields are Python-only (the latter is a `Leaf`).
* A `Node` passed where a child is expected renders as itself (upstream
  would traverse the `Node` dataclass).
* `Pretty` with an empty repr shows `__repr__ returned empty string`
  (upstream prefixes the Python type).
* `install` (REPL display hook) and the IPython hook are not ported.
* `rich.repr.auto` cannot derive `__rich_repr__` from an `__init__`
  signature: list the arguments with `arg`/`kwarg`/`arg_default`/
  `kwarg_default`; `repr_string` builds the `__repr__` text (`ReprError`
  is therefore not needed).
* Skipped upstream tests: `test_install*`, `test_ipy_display_hook*`,
  `test_broken_repr`, `test_broken_getattr`, `test_lying_attribute`,
  `test_attrs_broken*`, `test_pretty_namedtuple_custom_repr`,
  `test_pretty_namedtuple_fields_invalid_type`, the `D2` (custom `__repr__`)
  half of `test_user_dict`, `test_broken_egg`. `test_deque` covers only
  `deque` without `maxlen`.

## scope

* `render_scope` takes a `Map[String, &PrettyRepr]` (insertion order is
  kept when `sort_keys=false`).
