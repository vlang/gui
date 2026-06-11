#ifndef GUI_READBACK_D3D11_WARP_TEST_H
#define GUI_READBACK_D3D11_WARP_TEST_H

#ifdef _WIN32

#ifndef COBJMACROS
#define COBJMACROS
#endif

#include <d3d11.h>
#include <stdint.h>
#include <string.h>

uint8_t* gui_readback_d3d11_texture(
    void* d3d11_texture,
    void* d3d11_device,
    void* d3d11_context,
    int width,
    int height
);
void gui_readback_buffer_free(uint8_t* buffer);

static int gui_readback_d3d11_create_warp(
    ID3D11Device** out_device,
    ID3D11DeviceContext** out_context
) {
    static const D3D_FEATURE_LEVEL levels[] = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    };
    D3D_FEATURE_LEVEL feature_level;
    HRESULT hr = D3D11CreateDevice(
        NULL,
        D3D_DRIVER_TYPE_WARP,
        NULL,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        levels,
        sizeof(levels) / sizeof(levels[0]),
        D3D11_SDK_VERSION,
        out_device,
        &feature_level,
        out_context);
    return SUCCEEDED(hr) && *out_device != NULL && *out_context != NULL;
}

static void gui_readback_d3d11_release_all(
    ID3D11Texture2D* texture,
    ID3D11DeviceContext* context,
    ID3D11Device* device
) {
    if (texture != NULL) {
        ID3D11Texture2D_Release(texture);
    }
    if (context != NULL) {
        ID3D11DeviceContext_Release(context);
    }
    if (device != NULL) {
        ID3D11Device_Release(device);
    }
}

static int gui_readback_d3d11_create_texture(
    ID3D11Device* device,
    DXGI_FORMAT format,
    UINT sample_count,
    const uint8_t* pixels,
    ID3D11Texture2D** out_texture
) {
    D3D11_TEXTURE2D_DESC desc;
    memset(&desc, 0, sizeof(desc));
    desc.Width = 2;
    desc.Height = 2;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = format;
    desc.SampleDesc.Count = sample_count;
    desc.SampleDesc.Quality = 0;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_RENDER_TARGET;
    desc.CPUAccessFlags = 0;
    desc.MiscFlags = 0;

    D3D11_SUBRESOURCE_DATA data;
    D3D11_SUBRESOURCE_DATA* data_ptr = NULL;
    if (pixels != NULL) {
        memset(&data, 0, sizeof(data));
        data.pSysMem = pixels;
        data.SysMemPitch = 2 * 4;
        data_ptr = &data;
    }

    HRESULT hr = ID3D11Device_CreateTexture2D(
        device,
        &desc,
        data_ptr,
        out_texture);
    return SUCCEEDED(hr) && *out_texture != NULL;
}

static int gui_readback_d3d11_warp_roundtrip_test(void) {
    ID3D11Device* device = NULL;
    ID3D11DeviceContext* context = NULL;
    ID3D11Texture2D* texture = NULL;
    static const uint8_t expected[] = {
        0x01, 0x02, 0x03, 0xff,
        0x10, 0x20, 0x30, 0xff,
        0x40, 0x50, 0x60, 0xff,
        0x70, 0x80, 0x90, 0xff,
    };

    if (!gui_readback_d3d11_create_warp(&device, &context)) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 0;
    }
    if (!gui_readback_d3d11_create_texture(
            device,
            DXGI_FORMAT_B8G8R8A8_UNORM,
            1,
            expected,
            &texture)) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 0;
    }

    uint8_t* actual = gui_readback_d3d11_texture(
        texture,
        device,
        context,
        2,
        2);
    if (actual == NULL) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 0;
    }

    int ok = memcmp(actual, expected, sizeof(expected)) == 0;
    gui_readback_buffer_free(actual);
    gui_readback_d3d11_release_all(texture, context, device);
    return ok ? 1 : 0;
}

static int gui_readback_d3d11_rejects_unsupported_format_test(void) {
    ID3D11Device* device = NULL;
    ID3D11DeviceContext* context = NULL;
    ID3D11Texture2D* texture = NULL;
    static const uint8_t pixels[] = {
        0x01, 0x02, 0x03, 0xff,
        0x10, 0x20, 0x30, 0xff,
        0x40, 0x50, 0x60, 0xff,
        0x70, 0x80, 0x90, 0xff,
    };

    if (!gui_readback_d3d11_create_warp(&device, &context)) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 0;
    }
    if (!gui_readback_d3d11_create_texture(
            device,
            DXGI_FORMAT_R8G8B8A8_UNORM,
            1,
            pixels,
            &texture)) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 0;
    }

    uint8_t* actual = gui_readback_d3d11_texture(
        texture,
        device,
        context,
        2,
        2);
    int ok = actual == NULL;
    if (actual != NULL) {
        gui_readback_buffer_free(actual);
    }
    gui_readback_d3d11_release_all(texture, context, device);
    return ok ? 1 : 0;
}

static int gui_readback_d3d11_rejects_msaa_test(void) {
    ID3D11Device* device = NULL;
    ID3D11DeviceContext* context = NULL;
    ID3D11Texture2D* texture = NULL;
    UINT quality_levels = 0;

    if (!gui_readback_d3d11_create_warp(&device, &context)) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 0;
    }

    HRESULT hr = ID3D11Device_CheckMultisampleQualityLevels(
        device,
        DXGI_FORMAT_B8G8R8A8_UNORM,
        2,
        &quality_levels);
    if (FAILED(hr) || quality_levels == 0) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 1;
    }

    if (!gui_readback_d3d11_create_texture(
            device,
            DXGI_FORMAT_B8G8R8A8_UNORM,
            2,
            NULL,
            &texture)) {
        gui_readback_d3d11_release_all(texture, context, device);
        return 0;
    }

    uint8_t* actual = gui_readback_d3d11_texture(
        texture,
        device,
        context,
        2,
        2);
    int ok = actual == NULL;
    if (actual != NULL) {
        gui_readback_buffer_free(actual);
    }
    gui_readback_d3d11_release_all(texture, context, device);
    return ok ? 1 : 0;
}

#endif

#endif
