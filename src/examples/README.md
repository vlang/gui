# Examples

Sometimes the best way to learn is to read example code. Many of the
examples were used to verify the behavior of GUI.

## How to build

V needs to locate the GUI package. Since it is not an offical V package
it can not be installed via `v install`. Instead, give the path to this
installation.

Example:

``` bash
v -path "/Users/mike/gui/src|@vlib|@vmodules" run calc.v
```

Important: - quotes around the paths are required - @vlib\|@vmodules
required

Tip: Set the `VFLAGS` environment variable to save yourself some typing.

Example:

``` bash
export VFLAGS=-path /Users/mike/gui/src|@vlib|@vmodules
```

The `_build.vsh` V script builds all examples to a `/bin` folder
The `_check.vsh` V script does a quick syntax/format check and does
generate binaries.

Example:
``` bash
v run _build.vsh
```

## Getting Started

If you're new to GUI, start with the `get-started.v` example. It
explains the basics of view generators, state models and event handling.
Some of the other examples like `two-panel.v` and `test-layout.v` were
used to test the layout engine during development and are not meant as
examples of how to write an app.

## Documentation

The `Makefile` at the root of the project build documentation from the
source code. Type `make doc` to produce the documention and `make read`
to open the documention in the browser.

There is also some hand written documentation in the `/doc` folder
labled `01 Introduction.md`, `02 Getting Started.md`, etc. It's a work
in progress.
