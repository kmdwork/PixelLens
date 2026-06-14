#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DPIEngineImageInfo {
    int width;
    int height;
    double tiffDpiX;
    double tiffDpiY;
    double exifDpiX;
    double exifDpiY;
    double jfifDpiX;
    double jfifDpiY;
} DPIEngineImageInfo;

typedef struct DPIEnginePrintSize {
    double widthCm;
    double heightCm;
} DPIEnginePrintSize;

DPIEnginePrintSize DPIEngineComputePrintSizeCm(DPIEngineImageInfo info);
const char *DPIEngineParseJPEGStructure(const uint8_t *bytes, size_t length);
void DPIEngineFreeString(const char *value);

#ifdef __cplusplus
}
#endif
