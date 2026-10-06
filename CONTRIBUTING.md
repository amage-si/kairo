# Contributing to Kairo

Use Bend 2.0.35 for the current baseline. Read `bend guide` before editing Bend
and keep project text in English. Library implementation belongs in Bend; the
official runtime and operating system remain external dependencies.

## Validation

Clone [Tessra](https://github.com/amage-si/tessra) beside this directory as
`Tessra`. From the Kairo repository root:

```sh
export BEND_NO_TELEMETRY=1
mkdir -p build
bend main.bend --check-only
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
bend adapter_tests.bend -o build/adapter_tests
./build/adapter_tests --threads 2 --gpu off
bend examples/button.bend -o build/button
./build/button --threads 2 --gpu off
```

The tests need no display. When a change affects visible interaction, also run
[Mokko](https://github.com/amage-si/mokko)'s tests and its window demo, and
check pointer, keyboard, and focus behavior in the real window. A successful
build alone does not validate the user experience.

Build one target at a time. The native Bend runtime reserves substantial virtual
address space; a virtual-memory limit is not a resident-memory limit. Preserve
crash evidence and investigate before repeating a failed compiler invocation.

## Changes

Keep the API small and the rules explicit. Add a focused regression check when
behavior changes, update [docs/api.md](docs/api.md), and report what was
actually validated. Distinguish "no dirty region" from "no presentation": the
official runtime keeps presenting and polling even when Kairo reports nothing
to redraw.

Use English commit messages that explain the result. Do not commit `build/`,
generated C, logs, crash dumps, credentials, or machine-specific paths. Do not
publish BendHub packages or create releases as a side effect of validation.

Compatibility work follows concrete Linux progress. New input sources need
explicit adapters and their own validation before being advertised as
supported.
