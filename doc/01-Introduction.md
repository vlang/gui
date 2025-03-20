# Introduction

GUI is a flex-box style UI framework written in [V](https://vlang.io),
with declarative syntax and microsecond performance. If that sounds like
the Clay layout library, you're not mistaken. GUI is based on the same
concepts and algorithms. Many thanks to Nic Barker for his [video on how
Clay works](https://www.youtube.com/watch?v=by9lQvpvMIc&t=2371s&pp=ygUNY2xheSBsYXlvdXQgYw%3D%3D).

GUI's rendering mechanism is immediate mode. That means that any change
in the UI requires a complete recalculation of the layout and redrawing
of the window. That sounds slow, but in reality, it is quite the
opposite. In theory, GUI can draw 10,000 frames a second. Of course,
hardware limitations and other factors limit performance, but
practically speaking, GUI is faster than you'll ever need it to be.

Immediate mode is what web frameworks like React use. The main benefit
of immediate mode is not the speed (a nice feature) but the ease of
updating the interface. By recalculating the entire layout, there is no
need to remember to undo something. Just create a new layout when the
view needs to be updated. It sounds complicated, but it's not. Review a
few examples to see what I mean.

GUI is platform-independent and should run on the same platforms the V
supports.

In GUI, you describe your UI declaratively using good-ole functions. The
declarative syntax comes from nesting function calls in a tree-like
fashion. More on this in the next chapter.
