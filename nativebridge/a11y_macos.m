// a11y_macos.m — NSAccessibility backend for VoiceOver.
// Builds a parallel tree of NSAccessibilityElement objects
// synced from the V layout tree after each full rebuild.

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include "a11y_bridge.h"

// -------------------------------------------------------
// Role mapping: AccessRole ordinal → NSAccessibilityRole
// -------------------------------------------------------

// Must match AccessRole enum order in a11y.v:
//  0=none, 1=button, 2=checkbox, ... 34=tree_item
// NSAccessibilityRole values are NSString* constants
// (not compile-time), so use a switch function.
static NSAccessibilityRole gui_a11y_map_role(int role) {
    switch (role) {
        case  1: return NSAccessibilityButtonRole;
        case  2: return NSAccessibilityCheckBoxRole;
        case  3: return NSAccessibilityColorWellRole;
        case  4: return NSAccessibilityComboBoxRole;
        case  5: return NSAccessibilityTextFieldRole;  // date_field
        case  6: return NSAccessibilitySheetRole;      // dialog
        case  7: return NSAccessibilityDisclosureTriangleRole;
        case  8: return NSAccessibilityTableRole;      // grid
        case  9: return NSAccessibilityCellRole;       // grid_cell
        case 10: return NSAccessibilityGroupRole;      // group
        case 11: return NSAccessibilityGroupRole;      // heading
        case 12: return NSAccessibilityImageRole;
        case 13: return NSAccessibilityLinkRole;
        case 14: return NSAccessibilityListRole;
        case 15: return NSAccessibilityGroupRole;      // list_item
        case 16: return NSAccessibilityMenuRole;
        case 17: return NSAccessibilityMenuBarRole;
        case 18: return NSAccessibilityMenuItemRole;
        case 19: return NSAccessibilityProgressIndicatorRole;
        case 20: return NSAccessibilityRadioButtonRole;
        case 21: return NSAccessibilityRadioGroupRole;
        case 22: return NSAccessibilityScrollAreaRole;
        case 23: return NSAccessibilityScrollBarRole;
        case 24: return NSAccessibilitySliderRole;
        case 25: return NSAccessibilitySplitterRole;
        case 26: return NSAccessibilityStaticTextRole;
        case 27: return NSAccessibilityCheckBoxRole;   // switch_toggle
        case 28: return NSAccessibilityTabGroupRole;
        case 29: return NSAccessibilityRadioButtonRole; // tab_item
        case 30: return NSAccessibilityTextFieldRole;
        case 31: return NSAccessibilityTextAreaRole;
        case 32: return NSAccessibilityToolbarRole;
        case 33: return NSAccessibilityOutlineRole;    // tree
        case 34: return NSAccessibilityRowRole;        // tree_item
        default: return NSAccessibilityGroupRole;      // none/unknown
    }
}

// Subrole mapping for special cases
static NSAccessibilitySubrole gui_a11y_map_subrole(int role) {
    switch (role) {
        case 27: // switch_toggle
            return NSAccessibilitySwitchSubrole;
        case 29: // tab_item
            return NSAccessibilityTabButtonSubrole;
        default:
            return nil;
    }
}

// -------------------------------------------------------
// AccessState bitmask constants (match AccessState enum)
// -------------------------------------------------------
enum {
    A11Y_STATE_EXPANDED  = 1,
    A11Y_STATE_SELECTED  = 2,
    A11Y_STATE_CHECKED   = 4,
    A11Y_STATE_REQUIRED  = 8,
    A11Y_STATE_INVALID   = 16,
    A11Y_STATE_BUSY      = 32,
    A11Y_STATE_READ_ONLY = 64,
    A11Y_STATE_MODAL     = 128,
};

// -------------------------------------------------------
// Forward declarations
// -------------------------------------------------------

@class GuiA11yElement;
static BOOL gui_a11y_dispatch_action(
    GuiA11yElement *elem, int action);

// -------------------------------------------------------
// GuiA11yElement — NSAccessibilityElement subclass
// -------------------------------------------------------

@interface GuiA11yElement : NSAccessibilityElement

@property (nonatomic, strong) NSAccessibilityRole a11yRole;
@property (nonatomic, strong) NSAccessibilitySubrole a11ySubrole;
@property (nonatomic, copy)   NSString *a11yLabel;
@property (nonatomic, copy)   NSString *a11yHelp;
@property (nonatomic, strong) id a11yValue;
@property (nonatomic, assign) NSRect frameInWindow;
@property (nonatomic, assign) int guiState;
@property (nonatomic, assign) int focusId;
@property (nonatomic, assign) int headingLevel;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, strong) NSMutableArray<GuiA11yElement *> *a11yChildren;
@property (nonatomic, weak)   id a11yParent;

@end

@implementation GuiA11yElement

- (NSAccessibilityRole)accessibilityRole {
    return self.a11yRole ?: NSAccessibilityGroupRole;
}

- (NSAccessibilitySubrole)accessibilitySubrole {
    return self.a11ySubrole;
}

- (NSString *)accessibilityLabel {
    return self.a11yLabel;
}

- (NSString *)accessibilityHelp {
    return self.a11yHelp;
}

- (id)accessibilityValue {
    return self.a11yValue;
}

- (NSRect)accessibilityFrame {
    // Convert window-local frame to screen coordinates.
    // Shape uses top-left origin; macOS screen uses bottom-left.
    NSWindow *win = nil;
    id parent = self.a11yParent;
    while (parent != nil) {
        if ([parent isKindOfClass:[NSView class]]) {
            win = [(NSView *)parent window];
            break;
        }
        if ([parent isKindOfClass:[GuiA11yElement class]]) {
            parent = [(GuiA11yElement *)parent a11yParent];
        } else {
            break;
        }
    }
    if (win == nil) {
        return self.frameInWindow;
    }

    // frameInWindow has top-left origin; flip to bottom-left
    // for window coords before converting to screen.
    NSRect contentRect = [[win contentView] frame];
    NSRect flipped = self.frameInWindow;
    flipped.origin.y =
        contentRect.size.height - flipped.origin.y - flipped.size.height;

    return [win convertRectToScreen:flipped];
}

- (id)accessibilityParent {
    return self.a11yParent;
}

- (NSArray *)accessibilityChildren {
    return self.a11yChildren;
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (BOOL)isAccessibilityFocused {
    return self.isFocused;
}

// State queries from guiState bitmask
- (BOOL)isAccessibilityExpanded {
    return (self.guiState & A11Y_STATE_EXPANDED) != 0;
}

- (BOOL)isAccessibilitySelected {
    return (self.guiState & A11Y_STATE_SELECTED) != 0;
}

- (BOOL)isAccessibilityRequired {
    return (self.guiState & A11Y_STATE_REQUIRED) != 0;
}

// Actions
- (NSArray<NSString *> *)accessibilityActionNames {
    NSMutableArray<NSString *> *actions =
        [NSMutableArray array];
    if (self.focusId > 0) {
        [actions addObject:NSAccessibilityPressAction];
        // Slider-like roles get increment/decrement
        NSAccessibilityRole role = self.a11yRole;
        if ([role isEqualToString:NSAccessibilitySliderRole] ||
            [role isEqualToString:
                NSAccessibilityProgressIndicatorRole]) {
            [actions addObject:
                NSAccessibilityIncrementAction];
            [actions addObject:
                NSAccessibilityDecrementAction];
        }
    }
    return actions;
}

- (BOOL)accessibilityPerformPress {
    return gui_a11y_dispatch_action(
        self, GUI_A11Y_ACTION_PRESS);
}

- (BOOL)accessibilityPerformIncrement {
    return gui_a11y_dispatch_action(
        self, GUI_A11Y_ACTION_INCREMENT);
}

- (BOOL)accessibilityPerformDecrement {
    return gui_a11y_dispatch_action(
        self, GUI_A11Y_ACTION_DECREMENT);
}

@end

// -------------------------------------------------------
// GuiA11yContainerView — transparent NSView subclass
// -------------------------------------------------------

@interface GuiA11yContainerView : NSView
@property (nonatomic, strong)
    NSMutableArray<GuiA11yElement *> *elements;
@end

@implementation GuiA11yContainerView

- (NSAccessibilityRole)accessibilityRole {
    return NSAccessibilityGroupRole;
}

- (NSArray *)accessibilityChildren {
    return self.elements;
}

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSView *)hitTest:(NSPoint)point {
    // Event-transparent: never intercept mouse events.
    return nil;
}

- (BOOL)acceptsFirstResponder {
    return NO;
}

@end

// -------------------------------------------------------
// Module-level state
// -------------------------------------------------------

static GuiA11yContainerView *g_container = nil;
static GuiA11yActionFn       g_action_fn = NULL;
static void                 *g_user_data = NULL;
static int                   g_prev_focused_id = -1;

static BOOL gui_a11y_dispatch_action(
        GuiA11yElement *elem, int action) {
    if (g_action_fn == NULL || elem.focusId <= 0) {
        return NO;
    }
    g_action_fn(action, elem.focusId, g_user_data);
    return YES;
}

// -------------------------------------------------------
// Public C API
// -------------------------------------------------------

void gui_a11y_init(
        void *ns_window,
        GuiA11yActionFn cb,
        void *user_data) {
    @autoreleasepool {
        if (g_container != nil) {
            return; // Already initialized
        }
        NSWindow *win = (__bridge NSWindow *)ns_window;
        if (win == nil) {
            return;
        }

        g_action_fn = cb;
        g_user_data = user_data;

        g_container = [[GuiA11yContainerView alloc]
            initWithFrame:[[win contentView] bounds]];
        g_container.autoresizingMask =
            NSViewWidthSizable | NSViewHeightSizable;
        g_container.elements =
            [NSMutableArray arrayWithCapacity:64];

        [[win contentView] addSubview:g_container];
    }
}

void gui_a11y_sync(
        GuiA11yNode *nodes,
        int count,
        int focused_idx) {
    if (g_container == nil || nodes == NULL || count <= 0) {
        return;
    }

    @autoreleasepool {
        // 1. Create elements for each node
        NSMutableArray<GuiA11yElement *> *elems =
            [NSMutableArray arrayWithCapacity:count];

        for (int i = 0; i < count; i++) {
            GuiA11yNode *n = &nodes[i];
            GuiA11yElement *e =
                [[GuiA11yElement alloc] init];

            e.a11yRole    = gui_a11y_map_role(n->role);
            e.a11ySubrole = gui_a11y_map_subrole(n->role);
            e.guiState    = n->state;
            e.focusId     = n->focus_id;
            e.headingLevel = n->heading_level;

            if (n->label != NULL && n->label[0] != '\0') {
                e.a11yLabel = [NSString
                    stringWithUTF8String:n->label];
            }
            if (n->description != NULL &&
                    n->description[0] != '\0') {
                e.a11yHelp = [NSString
                    stringWithUTF8String:n->description];
            }

            // Value: prefer text, fall back to numeric
            if (n->value_text != NULL &&
                    n->value_text[0] != '\0') {
                e.a11yValue = [NSString
                    stringWithUTF8String:n->value_text];
            } else if (n->value_min != n->value_max) {
                e.a11yValue = @(n->value_num);
            }

            e.frameInWindow = NSMakeRect(
                n->x, n->y, n->w, n->h);
            e.isFocused =
                (focused_idx >= 0 && focused_idx == i);

            e.a11yChildren =
                [NSMutableArray arrayWithCapacity:4];
            [elems addObject:e];
        }

        // 2. Build parent-child links
        for (int i = 0; i < count; i++) {
            int pi = nodes[i].parent_idx;
            if (pi >= 0 && pi < count) {
                GuiA11yElement *parent = elems[pi];
                GuiA11yElement *child  = elems[i];
                child.a11yParent = parent;
                [parent.a11yChildren addObject:child];
            } else {
                // Root-level: parent is container view
                elems[i].a11yParent = g_container;
            }
        }

        // 3. Assign root-level elements to container
        NSMutableArray<GuiA11yElement *> *roots =
            [NSMutableArray arrayWithCapacity:count];
        for (int i = 0; i < count; i++) {
            if (nodes[i].parent_idx < 0) {
                [roots addObject:elems[i]];
            }
        }
        g_container.elements = roots;

        // 4. Layout changed notification
        NSAccessibilityPostNotification(
            g_container,
            NSAccessibilityLayoutChangedNotification);

        // 5. Focus change notification
        int new_focused_id = -1;
        if (focused_idx >= 0 && focused_idx < count) {
            new_focused_id = nodes[focused_idx].focus_id;
        }
        if (new_focused_id != g_prev_focused_id) {
            g_prev_focused_id = new_focused_id;
            if (focused_idx >= 0 &&
                    focused_idx < count) {
                NSAccessibilityPostNotification(
                    elems[focused_idx],
                    NSAccessibilityFocusedUIElementChangedNotification);
            }
        }
    }
}

void gui_a11y_destroy(void) {
    @autoreleasepool {
        if (g_container != nil) {
            [g_container removeFromSuperview];
            g_container = nil;
        }
        g_action_fn = NULL;
        g_user_data = NULL;
        g_prev_focused_id = -1;
    }
}

void gui_a11y_announce(const char *msg) {
    if (msg == NULL || msg[0] == '\0') {
        return;
    }
    @autoreleasepool {
        NSString *text = [NSString stringWithUTF8String:msg];
        NSDictionary *info = @{
            NSAccessibilityAnnouncementKey: text,
            NSAccessibilityPriorityKey:
                @(NSAccessibilityPriorityHigh)
        };
        NSAccessibilityPostNotificationWithUserInfo(
            NSApp,
            NSAccessibilityAnnouncementRequestedNotification,
            info);
    }
}
