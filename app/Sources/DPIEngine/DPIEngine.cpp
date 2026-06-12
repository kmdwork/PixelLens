#include "DPIEngine.h"

namespace {
constexpr double kCmPerInch = 2.54;
}

DPIEnginePrintSize DPIEngineComputePrintSizeCm(DPIEngineImageInfo info) {
    DPIEnginePrintSize result{0.0, 0.0};
    if (info.tiffDpiX > 0.0) {
        result.widthCm = (static_cast<double>(info.width) / info.tiffDpiX) * kCmPerInch;
    }
    if (info.tiffDpiY > 0.0) {
        result.heightCm = (static_cast<double>(info.height) / info.tiffDpiY) * kCmPerInch;
    }
    return result;
}
