#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *ParseJPEGStructure(const uint8_t *bytes, size_t length);
void FreeJPEGStructureString(const char *value);

#ifdef __cplusplus
}
#endif
