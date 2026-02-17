#ifndef GUI_READBACK_BRIDGE_H
#define GUI_READBACK_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Read BGRA pixels from a Metal render-target texture.
// Uses a blit to a shared staging texture for reliable
// readback from private-storage render targets.
// command_queue must be the same queue the render was
// submitted on (for ordering).
// Caller must free returned buffer. Returns NULL on failure.
uint8_t* gui_readback_metal_texture(
    void* mtl_texture,
    void* command_queue,
    int width,
    int height
);

#ifdef __cplusplus
}
#endif

#endif
