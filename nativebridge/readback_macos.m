#import <Metal/Metal.h>
#include <stdlib.h>
#include "readback_bridge.h"

uint8_t* gui_readback_metal_texture(
    void* mtl_texture,
    void* command_queue,
    int width,
    int height
) {
    if (mtl_texture == NULL || command_queue == NULL
        || width <= 0 || height <= 0) {
        return NULL;
    }
    id<MTLTexture> src =
        (__bridge id<MTLTexture>)mtl_texture;
    id<MTLCommandQueue> queue =
        (__bridge id<MTLCommandQueue>)command_queue;

    // Create a shared-storage staging texture that the CPU
    // can read reliably (private render targets may use
    // lossless compression that getBytes can't decode
    // directly on some drivers).
    MTLTextureDescriptor* desc =
        [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:src.pixelFormat
            width:(NSUInteger)width
            height:(NSUInteger)height
            mipmapped:NO];
    desc.storageMode = MTLStorageModeShared;
    desc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> staging =
        [src.device newTextureWithDescriptor:desc];
    if (staging == nil) {
        return NULL;
    }

    // Blit from private render target to shared staging.
    // Using the SAME command queue as the render ensures
    // the blit executes after the render completes.
    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blit =
        [cmdBuf blitCommandEncoder];
    [blit copyFromTexture:src
              sourceSlice:0
              sourceLevel:0
             sourceOrigin:MTLOriginMake(0, 0, 0)
               sourceSize:MTLSizeMake(
                   (NSUInteger)width,
                   (NSUInteger)height, 1)
                toTexture:staging
         destinationSlice:0
         destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blit endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    // Read pixels from the shared staging texture.
    NSUInteger bpr = (NSUInteger)width * 4;
    NSUInteger size = bpr * (NSUInteger)height;
    uint8_t* buf = (uint8_t*)malloc(size);
    if (buf == NULL) {
        return NULL;
    }
    MTLRegion region = MTLRegionMake2D(
        0, 0, (NSUInteger)width, (NSUInteger)height);
    [staging getBytes:buf
          bytesPerRow:bpr
           fromRegion:region
          mipmapLevel:0];
    return buf;
}
