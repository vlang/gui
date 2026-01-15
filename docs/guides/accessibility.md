# Accessibility

Make your application accessible to users with disabilities.

## Screen Reader Support

v-gui provides automatic accessibility support through platform APIs.

### Automatic Text Exposure

Text views are automatically exposed to screen readers:

```v
import gui

gui.text(text: 'This text is automatically accessible')
```

### Semantic Labels

Provide context for non-text elements:

```oksyntax
gui.button(
	aria_label: 'Save document'
	content:    [
		gui.text(text: gui.icon_save, text_style: gui.theme().icon3)
	]
)
```

## Keyboard Navigation

Ensure all interactive elements are keyboard accessible:

```v
import gui

gui.column(
	content: [
		gui.button(
			id_focus: 1
			content:  [gui.text(text: 'First')]
		),
		gui.button(
			id_focus: 2
			content:  [gui.text(text: 'Second')]
		),
		gui.button(
			id_focus: 3
			content:  [gui.text(text: 'Third')]
		),
	]
)
```

Users can navigate with Tab and activate with Enter/Space.

## Color Contrast

Ensure sufficient contrast for readability:

```v
import gui

// Good contrast
gui.text(
	text:       'Readable text'
	text_style: gui.TextStyle{
		...gui.theme().text_style
		color: gui.rgb(0, 0, 0) // Black on white
	}
)

// Poor contrast (avoid)
gui.text(
	text:       'Hard to read'
	text_style: gui.TextStyle{
		...gui.theme().text_style
		color: gui.rgb(200, 200, 200) // Light gray on white
	}
)
```

WCAG recommends 4.5:1 contrast ratio for normal text, 3:1 for large text.

## Focus Indicators

Always provide visible focus indicators:

```v
import gui

gui.button(
	color_focus: gui.rgb(0, 120, 255) // Clear focus indicator
	content:     [gui.text(text: 'Accessible Button')]
)
```

## Best Practices

1. **Provide text alternatives**: Icon-only buttons need `aria_label`
2. **Maintain focus order**: Use `id_focus` logically (top-to-bottom,
   left-to-right)
3. **Use semantic HTML**: v-gui maps components to appropriate native
   controls
4. **Test with screen readers**: VoiceOver (macOS), NVDA (Windows), Orca
   (Linux)
5. **Support keyboard-only**: All functionality accessible without mouse
6. **Provide sufficient contrast**: Follow WCAG guidelines

## Platform Integration

v-gui integrates with platform accessibility APIs:
- **macOS**: NSAccessibility
- **Windows**: UI Automation
- **Linux**: AT-SPI

This happens automatically - no additional code required.

## Testing

Test accessibility with:
- **VoiceOver** (macOS): Cmd+F5
- **NVDA** (Windows): Free screen reader
- **Orca** (Linux): Built into GNOME
- **Keyboard only**: Unplug mouse and navigate

## Related Topics

- **[Focus Management](focus-management.md)** - Keyboard navigation
- **[Events](../core/events.md)** - Keyboard events
- **[Themes](../core/themes.md)** - Color and contrast