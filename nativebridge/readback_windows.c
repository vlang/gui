// readback_windows.c — D3D11 GPU texture readback.
// Mirrors the Metal readback pattern: create a staging
// texture, CopyResource, Map, copy rows, Unmap.
// Returns malloc'd BGRA buffer. Caller must free().

#ifdef _WIN32

#include <d3d11.h>
#include <stdlib.h>
#include <string.h>
#include "readback_bridge.h"

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

    ID3D11Texture2D* src = (ID3D11Texture2D*)texture_ptr;
    ID3D11Device* device = (ID3D11Device*)device_ptr;
    ID3D11DeviceContext* ctx = (ID3D11DeviceContext*)context_ptr;

    // Describe staging texture matching the render target.
    D3D11_TEXTURE2D_DESC desc;
    ID3D11Texture2D_GetDesc(src, &desc);
    desc.Width = (UINT)width;
    desc.Height = (UINT)height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
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

    // Copy pixel data row by row (pitch may differ).
    size_t row_bytes = (size_t)width * 4;
    size_t size = row_bytes * (size_t)height;
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
