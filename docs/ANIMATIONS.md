# Animations

v-gui provides a flexible animation system for creating smooth, responsive UI motion.
This document explains the four animation types and how to use them effectively.

## Overview

The animation system supports four types of animations:

| Type               | Use Case                          | Duration    |
|--------------------|-----------------------------------|-------------|
| TweenAnimation     | Value interpolation with easing   | Fixed       |
| SpringAnimation    | Physics-based natural motion      | Open-ended  |
| Layout Transition  | Animate layout changes            | Fixed       |
| Hero Transition    | Morph elements between views      | Fixed       |

All animations are managed through the window and run on a background thread at ~60fps.

## Core Concepts

### Animation Lifecycle

1. Create an animation struct with required parameters
2. Register it with `window.animation_add()`
3. The animation calls `on_value` each frame with interpolated values
4. When complete, `on_done` fires (if provided)
5. The animation is automatically removed

### Animation IDs

Every animation requires a unique `id` string. If you add an animation with an ID that
already exists, the new animation replaces the old one. This prevents duplicate
animations from stacking up.

```oksyntax
w.animation_add(mut gui.TweenAnimation{
    id: 'my_animation' // unique identifier
    // ...
})
```

### State Updates

Animations modify your application state, which triggers view regeneration:

```oksyntax
struct State {
mut:
    box_x f32 = 0 // animated value
}

// In animation callback
on_value: fn (v f32, mut w gui.Window) {
    mut s := w.state[State]()
    s.box_x = v // update state -> triggers redraw
}
```

## Tween Animations

Tween animations interpolate between two values over a fixed duration. Use easing
functions to control the motion curve.

### Basic Example

```oksyntax
import time

fn move_box(mut w gui.Window) {
    state := w.state[State]()

    w.animation_add(mut gui.TweenAnimation{
        id:       'box_move'
        from:     state.box_x
        to:       400.0
        duration: 500 * time.millisecond
        easing:   gui.ease_out_cubic
        on_value: fn (v f32, mut w gui.Window) {
            mut s := w.state[State]()
            s.box_x = v
        }
    })
}
```

### Easing Functions

Easing controls acceleration and deceleration:

| Function            | Effect                                |
|---------------------|---------------------------------------|
| `ease_linear`       | Constant speed, no acceleration       |
| `ease_in_quad`      | Starts slow, accelerates              |
| `ease_out_quad`     | Starts fast, decelerates              |
| `ease_in_out_quad`  | Slow start and end                    |
| `ease_in_cubic`     | Smoother acceleration than quad       |
| `ease_out_cubic`    | Smoother deceleration (recommended)   |
| `ease_in_out_cubic` | Smooth start and end                  |
| `ease_in_back`      | Pulls back before moving forward      |
| `ease_out_back`     | Overshoots then settles               |
| `ease_out_elastic`  | Spring-like oscillation               |
| `ease_out_bounce`   | Bouncing ball effect                  |

For most UI animations, `ease_out_cubic` provides natural-feeling deceleration.

### Custom Easing with Cubic Bezier

Create custom easing curves matching CSS `cubic-bezier()`:

```oksyntax
// CSS-style "ease" curve
my_easing := gui.cubic_bezier(0.25, 0.1, 0.25, 1.0)

w.animation_add(mut gui.TweenAnimation{
    id:     'custom'
    easing: my_easing
    // ...
})
```

### Chaining Animations

Use `on_done` to sequence animations:

```oksyntax
w.animation_add(mut gui.TweenAnimation{
    id:       'step1'
    from:     0
    to:       100
    duration: 300 * time.millisecond
    on_value: fn (v f32, mut w gui.Window) {
        mut s := w.state[State]()
        s.value = v
    }
    on_done: fn (mut w gui.Window) {
        // Start next animation when this one completes
        w.animation_add(mut gui.TweenAnimation{
            id:       'step2'
            from:     100
            to:       200
            duration: 300 * time.millisecond
            on_value: fn (v f32, mut w gui.Window) {
                mut s := w.state[State]()
                s.value = v
            }
        })
    }
})
```

## Spring Animations

Spring animations use physics simulation for natural-feeling motion. Unlike tweens,
they have no fixed duration - they settle naturally based on physics parameters.

### Basic Example

```oksyntax
fn spring_sidebar(mut w gui.Window) {
    state := w.state[State]()
    target := if state.width > 100 { 60.0 } else { 200.0 }

    mut spring := gui.SpringAnimation{
        id:       'sidebar'
        config:   gui.spring_bouncy
        on_value: fn (v f32, mut w gui.Window) {
            mut s := w.state[State]()
            s.width = v
        }
    }
    spring.spring_to(state.width, target)
    w.animation_add(mut spring)
}
```

### Spring Presets

| Preset           | Stiffness | Damping | Feel                    |
|------------------|-----------|---------|-------------------------|
| `spring_default` | 100       | 10      | Balanced, general use   |
| `spring_gentle`  | 50        | 8       | Slow, smooth settling   |
| `spring_bouncy`  | 300       | 15      | Lively oscillation      |
| `spring_stiff`   | 500       | 30      | Quick, minimal bounce   |

### Custom Spring Configuration

```oksyntax
custom_spring := gui.SpringConfig{
    stiffness: 200  // higher = snappier
    damping:   12   // higher = less oscillation
    mass:      1.0  // higher = more inertia
    threshold: 0.01 // settling threshold
}

mut spring := gui.SpringAnimation{
    id:     'custom'
    config: custom_spring
    // ...
}
```

### Retargeting Springs

Change the target while preserving velocity for smooth redirects:

```oksyntax
// Initial animation
mut spring := gui.SpringAnimation{
    id: 'position'
    // ...
}
spring.spring_to(0, 100)
w.animation_add(mut spring)

// Later: change target without restarting
// (retrieve existing animation and retarget)
spring.retarget(200) // smoothly redirects to new target
```

## Layout Transitions

Layout transitions automatically animate position and size changes between frames.
Call `animate_layout()` before modifying state that affects layout.

### Basic Example

```oksyntax
fn toggle_sidebar(mut w gui.Window) {
    // Step 1: Capture current layout positions
    w.animate_layout(duration: 300 * time.millisecond)

    // Step 2: Modify state (triggers new layout)
    mut s := w.state[State]()
    s.sidebar_width = if s.sidebar_width > 100 { 60 } else { 200 }

    // Framework automatically animates from old to new positions
}
```

### How It Works

1. `animate_layout()` captures current positions of all elements with IDs
2. State change triggers view regeneration with new layout
3. Framework interpolates between old and new positions
4. Elements smoothly animate to their new locations

### Requirements

Elements must have an `id` to participate in layout transitions:

```oksyntax
gui.column(
    id:    'sidebar' // required for animation
    width: state.sidebar_width
    // ...
)
```

### Configuration

```oksyntax
w.animate_layout(
    duration: 200 * time.millisecond // animation length
    easing:   gui.ease_out_cubic     // motion curve
)
```

## Hero Transitions

Hero transitions morph elements between completely different views. Elements with
matching IDs and `hero: true` animate together during view switches.

### Basic Example

```oksyntax
// Source view
fn list_view(mut w gui.Window) gui.View {
    return gui.column(
        content: [
            gui.column(
                id:   'card-1'
                hero: true // marks for hero animation
                // small card layout...
            )
        ]
    )
}

// Target view
fn detail_view(mut w gui.Window) gui.View {
    return gui.column(
        content: [
            gui.column(
                id:     'card-1'        // same ID as source
                hero:   true            // also marked as hero
                sizing: gui.fill_fill   // now fills screen
                // expanded layout...
            )
        ]
    )
}

// Trigger transition
fn show_detail(mut w gui.Window) {
    w.transition_to_view(detail_view, duration: 600 * time.millisecond)
}
```

### What Gets Animated

The framework interpolates these properties:
- Position (x, y)
- Size (width, height)
- Border radius
- Opacity (for elements only in target view)

### Requirements

1. Both source and target elements need `id` set to the same value
2. Both elements need `hero: true`
3. Elements must be in different view functions
4. Use `transition_to_view()` to switch views

### Nested Hero Elements

Child elements can also be heroes for more complex animations:

```oksyntax
gui.column(
    id:   'card'
    hero: true
    content: [
        gui.text(
            id:   'title'
            hero: true // title also animates independently
            text: 'Item Title'
        )
    ]
)
```

## Managing Animations

### Check Animation Status

```oksyntax
if w.has_animation('my_animation') {
    // animation is still running
}
```

### Remove Animation

```oksyntax
w.remove_animation('my_animation') // stops and removes
```

### Delay Start

All animation types support a delay before starting:

```oksyntax
w.animation_add(mut gui.TweenAnimation{
    id:    'delayed'
    delay: 200 * time.millisecond // wait before starting
    // ...
})
```

## Tips and Best Practices

### Choosing Animation Types

| Scenario                        | Recommended Type    |
|---------------------------------|---------------------|
| Button press feedback           | TweenAnimation      |
| Sidebar expand/collapse         | SpringAnimation     |
| Panel resize                    | Layout Transition   |
| Navigate to detail view         | Hero Transition     |
| Loading spinner                 | TweenAnimation loop |
| Drag and drop                   | SpringAnimation     |

### Duration Guidelines

| Animation Type     | Typical Duration | Notes                       |
|--------------------|------------------|-----------------------------|
| Micro-interaction  | 100-200ms        | Button feedback, hover      |
| Panel transition   | 200-400ms        | Sidebar, accordion          |
| View transition    | 400-600ms        | Hero, page navigation       |
| Attention grabber  | 600-1000ms       | Bounce, elastic effects     |

### Performance Considerations

1. **Limit concurrent animations**: Each active animation runs every frame. Keep
   the number reasonable (< 10 simultaneous).

2. **Use springs for interruptible animations**: Springs handle retargeting
   gracefully. Tweens restart from the beginning if interrupted.

3. **Avoid animating layout-heavy properties**: Animating width/height triggers
   full layout recalculation. Position animations (x, y) are cheaper.

4. **Use IDs strategically**: Only elements that need animation require IDs.
   Adding IDs everywhere increases memory for layout snapshots.

5. **Consider animation cycle**: Animations update every ~16ms. Very short
   durations (< 50ms) may not animate smoothly.

### Common Pitfalls

1. **Duplicate IDs**: Animations with the same ID replace each other. Use unique
   IDs for concurrent animations.

2. **Missing IDs on elements**: Layout and hero transitions require element IDs
   to track positions.

3. **Forgetting `hero: true`**: Both source and target elements need this flag
   for hero transitions to work.

4. **Calling `animate_layout()` after state change**: Must be called before
   modifying state to capture the "before" snapshot.

5. **Long-running animations blocking UI**: Animations don't block, but expensive
   `on_value` callbacks can slow the UI. Keep callbacks fast.

## Example: Complete Animation Demo

See `examples/animations.v` for a complete working example demonstrating all
animation types with interactive controls.

```bash
v run examples/animations.v
```
