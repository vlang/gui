# SVG Support

v-gui includes a complete SVG rendering pipeline for vector graphics. SVGs are parsed, tessellated
into triangles, cached, and rendered efficiently via the GPU.

## Basic Usage

```v ignore
// From file
gui.svg(file_name: 'icon.svg', width: 24, height: 24)

// Inline SVG data
gui.svg(svg_data: '<svg viewBox="0 0 24 24">...</svg>', width: 24, height: 24)

// With color override (for monochrome icons)
gui.svg(file_name: 'icon.svg', width: 24, height: 24, color: gui.theme().text_color)
```

## Supported SVG Features

### Elements

| Element | Support |
|---------|---------|
| `<path>` | Full (all commands: M, L, H, V, C, S, Q, T, A, Z) |
| `<rect>` | Full (including rx/ry for rounded corners) |
| `<circle>` | Full |
| `<ellipse>` | Full |
| `<line>` | Full |
| `<polygon>` | Full |
| `<polyline>` | Full |
| `<g>` | Full (nested groups with style inheritance) |

### Transforms

All SVG transform functions are supported:

```xml
<g transform="translate(10, 20)">...</g>
<g transform="rotate(45)">...</g>
<g transform="rotate(45, 100, 100)">...</g>  <!-- rotate around point -->
<g transform="scale(2)">...</g>
<g transform="scale(2, 0.5)">...</g>
<g transform="skewX(30)">...</g>
<g transform="skewY(30)">...</g>
<g transform="matrix(a, b, c, d, e, f)">...</g>

<!-- Multiple transforms are composed -->
<g transform="translate(50, 50) rotate(45) scale(2)">...</g>
```

### Fills and Strokes

```xml
<!-- Fill colors -->
<path fill="#ff0000" ... />
<path fill="rgb(255, 0, 0)" ... />
<path fill="red" ... />
<path fill="none" ... />

<!-- Strokes -->
<path stroke="#000" stroke-width="2" ... />
<path stroke-linecap="round" ... />   <!-- butt, round, square -->
<path stroke-linejoin="bevel" ... />  <!-- miter, round, bevel -->
```

### Style Inheritance

Styles cascade from parent groups to children:

```xml
<g fill="blue" stroke="black" stroke-width="2">
    <rect ... />          <!-- inherits blue fill, black stroke -->
    <circle fill="red" /> <!-- red fill, inherits black stroke -->
</g>
```

## Architecture

### Parsing

SVGs are parsed into `VectorPath` structures containing:
- Path segments (move, line, quadratic/cubic bezier, arc, close)
- Fill color
- Stroke properties (color, width, cap, join)
- Transform matrix

### Tessellation

Paths are converted to triangles for GPU rendering:

1. **Curve flattening**: Bezier curves subdivided to polylines based on tolerance
2. **Transform application**: Affine transforms applied to all coordinates
3. **Fill tessellation**: Ear clipping algorithm with hole support
4. **Stroke tessellation**: Polylines expanded to quads with proper joins and caps

### Caching

Tessellated SVGs are cached by source and size:

```v ignore
// Automatic caching - same SVG at same size reuses tessellation
gui.svg(file_name: 'icon.svg', width: 24, height: 24)  // tessellates
gui.svg(file_name: 'icon.svg', width: 24, height: 24)  // cache hit

// Different size = new cache entry
gui.svg(file_name: 'icon.svg', width: 48, height: 48)  // tessellates at new scale
```

Manual cache control:

```v ignore
// Clear specific SVG from cache
window.remove_svg_from_cache('icon.svg')

// Clear all cached SVGs
window.clear_svg_cache()
```

## Examples

### Simple Icon

```v ignore
gui.row(
    content: [
        gui.svg(file_name: 'save.svg', width: 16, height: 16),
        gui.text(text: 'Save'),
    ]
)
```

### Icon with Theme Color

```v ignore
gui.svg(
    file_name: 'settings.svg',
    width: 24,
    height: 24,
    color: gui.theme().text_color,  // overrides SVG fill colors
)
```

### Complex SVG (Ghostscript Tiger)

```v ignore
// See examples/tiger.v for complete example
gui.svg(file_name: 'tiger.svg', width: 450, height: 450)
```

The classic Ghostscript Tiger (240 paths with transforms, groups, and strokes) renders correctly,
demonstrating full SVG compatibility.

## Limitations

Currently not supported:
- `<defs>` and `<use>` (symbol reuse)
- `<clipPath>` and `<mask>`
- `<linearGradient>` and `<radialGradient>`
- CSS styling (`<style>` blocks, `class` attributes)
- `opacity` attribute
- Text (`<text>`, `<tspan>`)
- Filters (`<filter>`)

For icons and illustrations, these limitations rarely matter. For complex SVGs with gradients or
text, consider converting to supported features or using bitmap images.

## Performance Tips

1. **Use appropriate sizes**: Tessellation quality scales with display size. Don't render a
   1000x1000 SVG at 24x24.

2. **Reuse SVGs**: The cache is keyed by source+size. Identical SVG widgets share tessellation.

3. **Simplify paths**: Fewer path segments = faster tessellation. Tools like SVGO can optimize.

4. **Color override for icons**: Using `color:` parameter is faster than parsing colors from SVG.
