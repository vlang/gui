// readback_windows.c — D3D11 GPU texture readback.
// Mirrors the Metal readback pattern: create a staging
// texture, CopyResource, Map, copy rows, Unmap.
// Returns malloc'd BGRA buffer owned by the readback bridge.

#ifdef _WIN32

#ifndef COBJMACROS
#define COBJMACROS
#endif

#include <d3d11.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "readback_bridge.h"

enum {
    gui_d3d11_readback_bytes_per_pixel = 4,
};

static int gui_d3d11_readback_format_supported(DXGI_FORMAT format) {
    return format == DXGI_FORMAT_B8G8R8A8_UNORM
        || format == DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
}

static int gui_d3d11_readback_size_checked(
    int width,
    int height,
    size_t* out_row_bytes,
    size_t* out_size
) {
    if (width <= 0 || height <= 0) return 0;
    size_t w = (size_t)width;
    size_t h = (size_t)height;
    if (w > SIZE_MAX / gui_d3d11_readback_bytes_per_pixel) {
        return 0;
    }
    size_t row_bytes = w * gui_d3d11_readback_bytes_per_pixel;
    if (h > SIZE_MAX / row_bytes) {
        return 0;
    }
    size_t size = row_bytes * h;
    if (size > (size_t)INT_MAX) {
        return 0;
    }
    *out_row_bytes = row_bytes;
    *out_size = size;
    return 1;
}

void gui_readback_buffer_free(uint8_t* buffer) {
    free(buffer);
}

uint8_t* gui_readback_d3d11_texture(
    void* texture_ptr,
    void* device_ptr,
    void* context_ptr,
    int width,
    int height
) {
    if (texture_ptr == NULL || device_ptr == NULL
        || context_ptr == NULL
        || width <= 0 || height <= 0) {
        return NULL;
    }

    size_t row_bytes = 0;
    size_t size = 0;
    if (!gui_d3d11_readback_size_checked(
            width, height, &row_bytes, &size)) {
        return NULL;
    }

    ID3D11Texture2D* src = (ID3D11Texture2D*)texture_ptr;
    ID3D11Device* device = (ID3D11Device*)device_ptr;
    ID3D11DeviceContext* ctx = (ID3D11DeviceContext*)context_ptr;

    // This bridge returns BGRA bytes for the common Sokol/D3D11 render-target
    // path. Other formats need an explicit conversion path before support.
    D3D11_TEXTURE2D_DESC desc;
    ID3D11Texture2D_GetDesc(src, &desc);
    if (desc.Width != (UINT)width || desc.Height != (UINT)height
        || desc.MipLevels != 1 || desc.ArraySize != 1
        || desc.SampleDesc.Count != 1
        || !gui_d3d11_readback_format_supported(desc.Format)) {
        return NULL;
    }

    // Describe staging texture matching the validated render target.
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    desc.MiscFlags = 0;

    ID3D11Texture2D* staging = NULL;
    HRESULT hr = ID3D11Device_CreateTexture2D(
        device, &desc, NULL, &staging);
    if (FAILED(hr) || staging == NULL) {
        return NULL;
    }

    // Copy render target to staging.
    ID3D11DeviceContext_CopyResource(
        ctx,
        (ID3D11Resource*)staging,
        (ID3D11Resource*)src);

    // Map staging texture for CPU read.
    D3D11_MAPPED_SUBRESOURCE mapped;
    hr = ID3D11DeviceContext_Map(
        ctx, (ID3D11Resource*)staging, 0,
        D3D11_MAP_READ, 0, &mapped);
    if (FAILED(hr)) {
        ID3D11Texture2D_Release(staging);
        return NULL;
    }

    if (mapped.pData == NULL || mapped.RowPitch < row_bytes) {
        ID3D11DeviceContext_Unmap(
            ctx, (ID3D11Resource*)staging, 0);
        ID3D11Texture2D_Release(staging);
        return NULL;
    }

    // Copy pixel data row by row (pitch may differ).
    uint8_t* buf = (uint8_t*)malloc(size);
    if (buf != NULL) {
        const uint8_t* src_data = (const uint8_t*)mapped.pData;
        for (int y = 0; y < height; y++) {
            memcpy(
                buf + y * row_bytes,
                src_data + y * mapped.RowPitch,
                row_bytes);
        }
    }

    ID3D11DeviceContext_Unmap(
        ctx, (ID3D11Resource*)staging, 0);
    ID3D11Texture2D_Release(staging);
    return buf;
}

#endif // _WIN32
