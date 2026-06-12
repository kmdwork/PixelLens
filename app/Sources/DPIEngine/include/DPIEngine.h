#pragma once

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

#ifdef __cplusplus
}
#endif
