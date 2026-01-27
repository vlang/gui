# V-GUI Performance Characteristics

## Overview

This document describes the performance characteristics of the v-gui framework and provides 
guidance for building performant applications.

## Layout Performance

### Current Characteristics

- **Frame rate**: 60 FPS achievable with 1000+ simple widgets
- **Layout calculation**: ~1-2ms for 100 widgets
- **Complexity**: O(n) where n = widget count

### Layout Pipeline Costs

| Pass | Relative Cost | Notes |
|------|---------------|-------|
| `layout_widths` | Low | Simple arithmetic |
| `layout_fill_widths` | Low | Simple arithmetic |
| `layout_wrap_text` | Medium-High | Text measurement is expensive |
| `layout_heights` | Low | Simple arithmetic |
| `layout_fill_heights` | Low | Simple arithmetic |
| `layout_positions` | Low | Simple arithmetic |

**Bottleneck**: Text wrapping and measurement dominate layout time for text-heavy UIs.

### Optimization Tips

1. **Minimize text changes**: Only update text that actually changed
2. **Use fixed dimensions**: Avoid `fit` sizing when dimensions are known
3. **Limit nesting depth**: Shallow trees calculate faster
4. **Batch updates**: Group related state changes together

## Rendering Performance

### Costs by Renderer Type

| Renderer | Relative Cost | Notes |
|----------|---------------|-------|
| `DrawRect` | Very Low | Single quad |
| `DrawRoundedRect` | Low | Custom shader |
| `DrawText` | Medium | Font rendering |
| `DrawShadow` | Medium-High | Blur calculation |
| `DrawBlur` | High | Multi-pass blur |
| `DrawGradient` | Low | Single quad |
| `DrawImage` | Low-Medium | Texture sampling |

### GPU Considerations

- **MSAA**: 2x samples add ~10% overhead (disabled on macOS Retina)
- **Shader switches**: Minimize different shader types per frame
- **Texture binds**: Image-heavy UIs should cache images

## Memory Usage

### Per-Widget Memory

| Component | Size | Notes |
|-----------|------|-------|
| Layout | ~200 bytes | Tree node |
| Shape | ~300 bytes | Rendering data |
| **Total** | ~500 bytes | Per widget |

### Example Calculations

| Widgets | Layout Memory | Notes |
|---------|---------------|-------|
| 100 | ~50 KB | Small form |
| 1,000 | ~500 KB | Complex dashboard |
| 10,000 | ~5 MB | Large list view |

### Memory Tips

1. **Use virtual scrolling**: For lists > 100 items
2. **Lazy load images**: Load on demand, cache appropriately
3. **Clear unused state**: Call appropriate cleanup methods

## Event Handling Performance

### Event Propagation

- **Complexity**: O(n) tree traversal per event
- **Optimization**: Events short-circuit on `is_handled = true`

### Tips

1. **Handle events early**: Set `is_handled = true` as soon as possible
2. **Avoid expensive callbacks**: Keep event handlers fast
3. **Debounce rapid events**: Especially mouse move events

## Text Rendering Performance

Text rendering is the most expensive operation in typical GUIs.

### Costs

| Operation | Relative Cost |
|-----------|---------------|
| Measure text | Medium |
| Wrap text | High |
| Render text | Medium |
| Font loading | High (one-time) |

### Optimization Tips

1. **Pre-calculate dimensions**: Avoid measuring the same text repeatedly
2. **Use fixed-width inputs**: Avoids re-wrapping on each keystroke
3. **Limit font variants**: Each font adds loading time
4. **Cache text layouts**: vglyph handles this internally

## Profiling

### Enable Debug Stats

```oksyntax
mut window := gui.window(
    debug_layout: true
    // ...
)
```

### What to Measure

1. **Frame time**: Should be < 16ms for 60 FPS
2. **Layout time**: Check `window.layout_stats`
3. **Render time**: Profile with GPU tools

### V Profiling

```bash
# Compile with profiling
v -profile profile.txt run examples/your_app.v

# View results
cat profile.txt
```

## Benchmarks

### Running Benchmarks

```bash
# Run layout benchmark
v run tests/benchmarks/layout_bench.v
```

### Expected Results (Reference Hardware)

| Test | Time | Notes |
|------|------|-------|
| Layout 100 widgets | ~1-2ms | Simple tree |
| Layout 1000 widgets | ~10-15ms | Complex tree |
| Render 100 widgets | ~0.5ms | No shadows |
| Render with shadows | ~2-5ms | Per shadow |

## Best Practices

### Do

- Use immediate mode idiomatically (regenerate views each frame)
- Keep widget counts reasonable (< 1000 visible)
- Use appropriate sizing modes
- Handle events efficiently
- Cache expensive computations

### Don't

- Create thousands of widgets when virtual scrolling works
- Use `fit` sizing everywhere (measure cost)
- Perform expensive operations in event handlers
- Load images synchronously in the main loop
- Ignore the `refresh_window` mechanism

## Future Optimizations

Potential improvements being considered:

1. **Layout caching**: Skip recalculation when view unchanged
2. **Dirty rectangles**: Only redraw changed regions
3. **Parallel layout**: Calculate independent subtrees concurrently
4. **GPU text rendering**: Move more text work to GPU

## Reporting Performance Issues

When reporting performance problems, include:

1. Widget count
2. Frame rate observed
3. V version
4. Hardware specs
5. Minimal reproduction code
