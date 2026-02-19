#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <stdlib.h>
#include <string.h>
#include "readback_bridge.h"

uint8_t* gui_readback_gl_framebuffer(
    uint32_t framebuffer, int width, int height
) {
    if (width <= 0 || height <= 0) {
        return NULL;
    }
    GLint prev_fbo = 0;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &prev_fbo);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, framebuffer);

    size_t row_bytes = (size_t)width * 4;
    size_t size = row_bytes * (size_t)height;
    uint8_t* buf = (uint8_t*)malloc(size);
    if (buf == NULL) {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)prev_fbo);
        return NULL;
    }
    glReadPixels(0, 0, width, height,
                 GL_RGBA, GL_UNSIGNED_BYTE, buf);

    // Flip rows vertically: GL is bottom-up, PDF is top-down.
    uint8_t* tmp = (uint8_t*)malloc(row_bytes);
    if (tmp != NULL) {
        for (int y = 0; y < height / 2; y++) {
            uint8_t* top = buf + y * row_bytes;
            uint8_t* bot = buf + (height - 1 - y) * row_bytes;
            memcpy(tmp, top, row_bytes);
            memcpy(top, bot, row_bytes);
            memcpy(bot, tmp, row_bytes);
        }
        free(tmp);
    }

    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)prev_fbo);
    return buf;
}
