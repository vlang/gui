# Examples

Sometimes the best way to learn is to read example code. Many of the
examples were used to verify the behavior of GUI.

## How to build

Example:

``` bash
cd examples
v run calc.v
```

The `_build.vsh` V script builds all examples to a `/bin` folder The
`_check.vsh` V script does a quick syntax/format check and does generate
binaries.

Example:

``` bash
v run _build.vsh
```

## Getting Started

If you’re new to GUI, start with the `get-started.v` example. It
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

## More Examples

``` bash
v run gradient_demo.v         # Linear and radial gradients
v run gradient_border_demo.v  # Gradient borders
v run custom_shader.v         # Custom fragment shaders
```
