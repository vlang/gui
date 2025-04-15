# Examples

Sometimes the best way to learn is to read example code.

## How to build
V needs to locate the GUI package. Since it is not an offical V package it can
not be installed via `v install`. Instead, give the path to this installation.

Example:
```bash
v -path "/Users/mike/gui/src|@vlib|@vmodules" run calc.v
```
Important:
- quotes around the paths are required
- @vlib|@vmodules required

Tip:
Set the `VFLAGS` environment variable to save yourself some typing.

Example:
```bash
export VFLAGS=-path /Users/mike/gui/src|@vlib|@vmodules
```

## Getting Started
If you're new to GUI, start with the `get-started.v` example. It explains the
basics of view generators, state models and event handling. Some of the other
examples like `two-panel.v` and `test-layout.v` were used to test the layout
engine during development and are not meant as examples of how to write an app.