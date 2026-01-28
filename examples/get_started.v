// Getting Started with v-gui
// ===========================
//
// This tutorial introduces the core concepts of v-gui through a simple click counter app.
//
// ## Architecture Overview
//
// v-gui uses a **declarative, immediate-mode** UI pattern:
//
// 1. You define your UI as a **view generator function** that returns a `gui.View`
// 2. The framework calls this function whenever the UI needs to refresh
// 3. Your function reads current **state** and returns the corresponding view
//
// This approach has key advantages:
// - **Predictable**: View is always a pure function of state
// - **Simple**: No data binding, observers, or manual UI synchronization
// - **Thread-safe**: No worries about UI thread access
// - **Stateless views**: No need to manually undo previous UI states
//
// ## Running This Example
//
// ```
// v run examples/get_started.v
// ```

import gui

// ## Step 1: Define Your Application State
//
// All mutable data lives in a state struct. The `@[heap]` attribute ensures the struct
// is heap-allocated, which is required for state that persists across view generations.
//
// Keep state minimal - only store data that:
// - Changes over time
// - Affects the UI
@[heap]
struct GetStartedApp {
pub mut:
	clicks int // Tracks button click count
}

// ## Step 2: Create the Window
//
// The `main()` function sets up and runs the application window.
fn main() {
	// Create a window with `gui.window()`. Key parameters:
	// - `state`: Your application state (heap-allocated with &)
	// - `width/height`: Initial window dimensions
	// - `on_init`: Called once when window initializes
	mut window := gui.window(
		state:   &GetStartedApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			// Set the initial view generator. You can call `update_view()` anywhere
			// in your code to switch views (e.g., for navigation between screens).
			w.update_view(main_view)
		}
	)

	// Apply a theme. Available themes include:
	// - theme_dark / theme_dark_bordered
	// - theme_light / theme_light_bordered
	// - theme_gruvbox_*
	// - theme_ocean_*
	// See src/themes.v for the full list.
	window.set_theme(gui.theme_dark_bordered)

	// Start the event loop. This blocks until the window closes.
	window.run()
}

// ## Step 3: Define the View Generator
//
// A view generator is a function with signature:
//   `fn(&gui.Window) gui.View`
//
// It's called automatically on every user event (mouse move, click, key press,
// window resize, etc.). Return a complete description of what the UI should look like.
fn main_view(window &gui.Window) gui.View {
	// Get current window dimensions for responsive layouts
	w, h := window.window_size()

	// Retrieve your state. The generic parameter specifies which state type to get.
	// This returns an immutable reference - use `window.state_mut[]()` for mutations
	// (but prefer mutating in event handlers instead).
	app := window.state[GetStartedApp]()

	// ## Step 4: Build the UI with Layout Containers
	//
	// v-gui uses a composable widget tree. Common containers:
	// - `column()`: Vertical layout (children stack top-to-bottom)
	// - `row()`: Horizontal layout (children arranged left-to-right)
	//
	// Both support alignment and sizing options.
	return gui.column(
		width:   w
		height:  h
		// `sizing` controls how the container calculates its size:
		// - fixed_fixed: Use exact width/height values
		// - fit_fit: Shrink to fit content
		// - fill_fill: Expand to fill parent
		// - Combinations like fit_fixed, fill_fit, etc.
		sizing:  gui.fixed_fixed
		// Alignment options: .left/.center/.right for h_align
		//                    .top/.middle/.bottom for v_align
		h_align: .center
		v_align: .middle
		// `content` takes an array of child widgets
		content: [
			// ## Text Widget
			//
			// Display text with optional styling. `text_style` uses theme typography:
			// - h1, h2, h3: Headings
			// - b1, b2, b3: Body text (decreasing size)
			// - label: Small labels
			gui.text(
				text:       'Welcome to GUI'
				text_style: gui.theme().b1
			),
			// ## Button Widget
			//
			// Interactive button with click handler.
			gui.button(
				// `id_focus` enables keyboard navigation. Buttons with focus IDs
				// can be tabbed to and activated with Enter/Space.
				id_focus: 1
				// Button content is an array of widgets (usually just text)
				content:  [gui.text(text: '${app.clicks} Clicks')]
				// ## Step 5: Handle Events
				//
				// Event handlers receive:
				// - layout: The widget's computed layout (position, size)
				// - event: Event details (which you can mark as "consumed")
				// - window: Mutable window reference for state access
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					// Get mutable state reference and update it.
					// The framework automatically re-renders after event handlers.
					mut app := w.state[GetStartedApp]()
					app.clicks += 1
				}
			),
		]
	)
}

// ## Next Steps
//
// Explore more examples in this directory:
// - `containers.v`: Layout containers (row, column, scroll, canvas)
// - `buttons.v`: Button variants and styling
// - `inputs.v`: Text input fields
// - `animations.v`: Animation system with tweens and springs
// - `theme_designer.v`: Interactive theme customization
//
// See also:
// - `src/widgets/` for all available widgets
// - `src/themes.v` for theming system
// - `docs/` for additional documentation
