#ifndef GUI_A11Y_BRIDGE_H
#define GUI_A11Y_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GuiA11yNode {
    int parent_idx;    /* -1 for root-level */
    int role;          /* AccessRole ordinal */
    int state;         /* AccessState bitmask */
    float x, y, w, h; /* window-local coords */
    const char* label;
    const char* description;
    const char* value_text;
    float value_num;
    float value_min;
    float value_max;
    int focus_id;      /* id_focus for action routing */
    int heading_level;
} GuiA11yNode;

/* Action constants for the callback */
enum {
    GUI_A11Y_ACTION_PRESS     = 0,
    GUI_A11Y_ACTION_INCREMENT = 1,
    GUI_A11Y_ACTION_DECREMENT = 2,
    GUI_A11Y_ACTION_CONFIRM   = 3,
    GUI_A11Y_ACTION_CANCEL    = 4
};

typedef void (*GuiA11yActionFn)(
    int action, int focus_id, void* user_data);

void gui_a11y_init(
    void* ns_window, GuiA11yActionFn cb, void* user_data);

void gui_a11y_sync(
    GuiA11yNode* nodes, int count, int focused_idx);

void gui_a11y_destroy(void);

void gui_a11y_announce(const char* msg);

#ifdef __cplusplus
}
#endif

#endif
