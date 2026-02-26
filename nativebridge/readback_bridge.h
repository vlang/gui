#ifndef GUI_READBACK_BRIDGE_H
#define GUI_READBACK_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Read BGRA pixels from a Metal render-target texture.
// Uses a blit to a shared staging texture for reliable
// readback from private-storage render targets.
// mtl_device is used to create a transient command queue.
// Caller must free returned buffer. Returns NULL on failure.
uint8_t* gui_readback_metal_texture(
    void* mtl_texture,
    void* mtl_device,
    int width,
    int height
);

// Read RGBA pixels from an OpenGL framebuffer via
// glReadPixels. Rows are flipped to top-down order.
// Caller must free returned buffer. Returns NULL on failure.
uint8_t* gui_readback_gl_framebuffer(
    uint32_t framebuffer,
    int width,
    int height
);

// Read BGRA pixels from a D3D11 render-target texture via
// staging texture copy. Caller must free returned buffer.
// Returns NULL on failure. Windows only.
uint8_t* gui_readback_d3d11_texture(
    void* d3d11_texture,
    void* d3d11_device,
    void* d3d11_context,
    int width,
    int height
);

#ifdef __cplusplus
}
#endif

#endif
