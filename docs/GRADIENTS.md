# Gradients

v-gui supports linear and radial gradients for both fills and borders.

## Types

- **Linear**: Color transitions along a direction or angle
- **Radial**: Color transitions outward from center

## API Reference

### GradientType

```v ignore
pub enum GradientType {
	linear // default
	radial
}
```

### GradientDirection

Eight preset directions for linear gradients:

```v ignore
pub enum GradientDirection {
	to_top
	to_top_right
	to_right
	to_bottom_right
	to_bottom      // default (CSS standard)
	to_bottom_left
	to_left
	to_top_left
}
```

### GradientStop

Defines a color at a position along the gradient:

```v ignore
pub struct GradientStop {
pub:
	color Color
	pos   f32 // 0.0 to 1.0 (0% to 100%)
}
```

### Gradient

```v ignore
pub struct Gradient {
pub:
	stops     []GradientStop
	type      GradientType      = .linear
	direction GradientDirection = .to_bottom
	angle     ?f32              // Optional angle in degrees, overrides direction
}
```

## Usage

### Fill Gradients

Use `gradient:` property on containers:

```v ignore
gui.column(
	width:    200
	height:   150
	radius:   15
	gradient: &gui.Gradient{
		stops: [
			gui.GradientStop{color: gui.blue, pos: 0.0},
			gui.GradientStop{color: gui.purple, pos: 1.0},
		]
	}
	content: [...]
)
```

### Border Gradients

Use `border_gradient:` property:

```v ignore
gui.column(
	width:           200
	height:          100
	radius:          10
	border_gradient: &gui.Gradient{
		stops: [
			gui.GradientStop{color: gui.red, pos: 0.0},
			gui.GradientStop{color: gui.blue, pos: 1.0},
		]
	}
	content: [...]
)
```

## Examples

### Linear Gradient with Direction

```v ignore
gradient: &gui.Gradient{
	direction: .to_right
	stops: [
		gui.GradientStop{color: gui.green, pos: 0.0},
		gui.GradientStop{color: gui.blue, pos: 1.0},
	]
}
```

### Radial Gradient

```v ignore
gradient: &gui.Gradient{
	type: .radial
	stops: [
		gui.GradientStop{color: gui.yellow, pos: 0.0},
		gui.GradientStop{color: gui.red, pos: 1.0},
	]
}
```

### Multi-Stop Gradient

```v ignore
gradient: &gui.Gradient{
	type: .radial
	stops: [
		gui.GradientStop{color: gui.red, pos: 0.0},
		gui.GradientStop{color: gui.green, pos: 0.5},
		gui.GradientStop{color: gui.blue, pos: 1.0},
	]
}
```

### Gradient with Shadow

```v ignore
gui.column(
	gradient: &gui.Gradient{
		stops: [
			gui.GradientStop{color: gui.green, pos: 0.0},
			gui.GradientStop{color: gui.blue, pos: 1.0},
		]
	}
	shadow: &gui.BoxShadow{
		blur_radius: 20
		color:       gui.Color{0, 0, 0, 50}
		offset_y:    5
	}
	content: [...]
)
```

## Demo Programs

```bash
v run examples/gradient_demo.v         # Linear and radial gradients
v run examples/gradient_border_demo.v  # Gradient borders
```
