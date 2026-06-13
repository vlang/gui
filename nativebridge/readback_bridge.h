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
// Returned buffer must be released with gui_readback_buffer_free.
// Returns NULL on failure.
uint8_t* gui_readback_metal_texture(
    void* mtl_texture,
    void* mtl_device,
    int width,
    int height
);

// Read RGBA pixels from an OpenGL framebuffer via
// glReadPixels. Rows are flipped to top-down order.
// Returned buffer must be released with gui_readback_buffer_free.
// Returns NULL on failure.
uint8_t* gui_readback_gl_framebuffer(
    uint32_t framebuffer,
    int width,
    int height
);

// Read BGRA pixels from a D3D11 render-target texture via
// staging texture copy. Supports single-sample BGRA8 textures
// (DXGI_FORMAT_B8G8R8A8_UNORM or _SRGB), one mip and one array
// slice. Dimensions must match the source texture. Unsupported
// formats, MSAA textures and unsafe row/size layouts fail by
// returning NULL. Returned buffer must be released with
// gui_readback_buffer_free. Windows only.
uint8_t* gui_readback_d3d11_texture(
    void* d3d11_texture,
    void* d3d11_device,
    void* d3d11_context,
    int width,
    int height
);

// Releases buffers returned by readback functions using the backend C allocator.
void gui_readback_buffer_free(uint8_t* buffer);

#ifdef __cplusplus
}
#endif

#endif
