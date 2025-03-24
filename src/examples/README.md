# Examples

V needs to find the GUI package. Since it is not an offical V package it can
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
```
VFLAGS=-path /Users/mike/gui/src|@vlib|@vmodules
```