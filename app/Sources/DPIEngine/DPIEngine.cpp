#include "DPIEngine.h"

#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

namespace {
constexpr double kCmPerInch = 2.54;

struct Node {
    std::string name;
    std::string kind;
    std::string markerHex;
    size_t offset;
    size_t length;
    size_t payloadOffset;
    size_t payloadLength;
    std::string decodedValue;
    std::string editValueType;
    std::string byteOrder;
    size_t maxEditableLength;
    std::vector<Node> children;
};

std::string jsonEscape(const std::string &value) {
    std::ostringstream stream;
    for (char ch : value) {
        switch (ch) {
        case '\\': stream << "\\\\"; break;
        case '"': stream << "\\\""; break;
        case '\n': stream << "\\n"; break;
        default: stream << ch; break;
        }
    }
    return stream.str();
}

std::string markerHex(uint8_t marker) {
    std::ostringstream stream;
    stream << "0xFF" << std::uppercase << std::hex << std::setw(2) << std::setfill('0')
           << static_cast<int>(marker);
    return stream.str();
}

std::string markerName(uint8_t marker) {
    switch (marker) {
    case 0xD8: return "SOI";
    case 0xD9: return "EOI";
    case 0xDA: return "SOS";
    case 0xDB: return "DQT";
    case 0xC4: return "DHT";
    case 0xC0: return "SOF0";
    case 0xC1: return "SOF1";
    case 0xC2: return "SOF2";
    case 0xC3: return "SOF3";
    case 0xC5: return "SOF5";
    case 0xC6: return "SOF6";
    case 0xC7: return "SOF7";
    case 0xC9: return "SOF9";
    case 0xCA: return "SOF10";
    case 0xCB: return "SOF11";
    case 0xCD: return "SOF13";
    case 0xCE: return "SOF14";
    case 0xCF: return "SOF15";
    case 0xDD: return "DRI";
    case 0xFE: return "COM";
    default:
        if (marker >= 0xE0 && marker <= 0xEF) return "APP" + std::to_string(marker - 0xE0);
        if (marker >= 0xD0 && marker <= 0xD7) return "RST" + std::to_string(marker - 0xD0);
        return "UNKNOWN";
    }
}

bool hasDeclaredLength(uint8_t marker) {
    if (marker == 0xD8 || marker == 0xD9) return false;
    if (marker >= 0xD0 && marker <= 0xD7) return false;
    if (marker == 0x01) return false;
    return true;
}

uint16_t readBE16(const uint8_t *bytes, size_t offset) {
    return static_cast<uint16_t>((bytes[offset] << 8) | bytes[offset + 1]);
}

uint16_t readU16(const uint8_t *bytes, size_t offset, bool littleEndian) {
    if (littleEndian) {
        return static_cast<uint16_t>(bytes[offset] | (bytes[offset + 1] << 8));
    }
    return static_cast<uint16_t>((bytes[offset] << 8) | bytes[offset + 1]);
}

uint32_t readU32(const uint8_t *bytes, size_t offset, bool littleEndian) {
    if (littleEndian) {
        return static_cast<uint32_t>(bytes[offset]) |
               (static_cast<uint32_t>(bytes[offset + 1]) << 8) |
               (static_cast<uint32_t>(bytes[offset + 2]) << 16) |
               (static_cast<uint32_t>(bytes[offset + 3]) << 24);
    }
    return (static_cast<uint32_t>(bytes[offset]) << 24) |
           (static_cast<uint32_t>(bytes[offset + 1]) << 16) |
           (static_cast<uint32_t>(bytes[offset + 2]) << 8) |
           static_cast<uint32_t>(bytes[offset + 3]);
}

size_t tiffTypeSize(uint16_t type) {
    switch (type) {
    case 1:
    case 2:
    case 6:
    case 7:
        return 1;
    case 3:
    case 8:
        return 2;
    case 4:
    case 9:
    case 11:
        return 4;
    case 5:
    case 10:
    case 12:
        return 8;
    default:
        return 1;
    }
}

std::string densityUnitName(uint8_t unit) {
    switch (unit) {
    case 0: return "none";
    case 1: return "dpi";
    case 2: return "dpcm";
    default: return "unknown";
    }
}

std::string tiffTagName(uint16_t tag) {
    switch (tag) {
    case 0x010F: return "Make";
    case 0x0110: return "Model";
    case 0x011A: return "XResolution";
    case 0x011B: return "YResolution";
    case 0x0128: return "ResolutionUnit";
    case 0x0131: return "Software";
    case 0x0132: return "DateTime";
    case 0x8769: return "ExifIFDPointer";
    case 0x829A: return "ExposureTime";
    case 0x829D: return "FNumber";
    case 0x8827: return "ISOSpeedRatings";
    case 0x9000: return "ExifVersion";
    case 0x9003: return "DateTimeOriginal";
    case 0x920A: return "FocalLength";
    case 0xA001: return "ColorSpace";
    case 0xA002: return "PixelXDimension";
    case 0xA003: return "PixelYDimension";
    default: {
        std::ostringstream stream;
        stream << "Tag 0x" << std::uppercase << std::hex << std::setw(4) << std::setfill('0') << tag;
        return stream.str();
    }
    }
}

std::string tiffTypeName(uint16_t type) {
    switch (type) {
    case 1: return "BYTE";
    case 2: return "ASCII";
    case 3: return "SHORT";
    case 4: return "LONG";
    case 5: return "RATIONAL";
    default: return "TYPE " + std::to_string(type);
    }
}

bool isPrintableAscii(const uint8_t *bytes, size_t offset, size_t length) {
    for (size_t index = 0; index < length; ++index) {
        uint8_t value = bytes[offset + index];
        if (value == 0) continue;
        if (value < 32 || value > 126) return false;
    }
    return true;
}

std::string asciiValue(const uint8_t *bytes, size_t offset, size_t length) {
    std::string value;
    value.reserve(length);
    for (size_t index = 0; index < length; ++index) {
        uint8_t current = bytes[offset + index];
        if (current == 0) break;
        value.push_back(static_cast<char>(current));
    }
    return value;
}

bool findEOIAfterSOS(const uint8_t *bytes, size_t length, size_t start, size_t &eoiOffset) {
    size_t index = start;
    while (index + 1 < length) {
        if (bytes[index] != 0xFF) {
            index += 1;
            continue;
        }
        size_t markerIndex = index;
        index += 1;
        while (index < length && bytes[index] == 0xFF) index += 1;
        if (index >= length) return false;
        uint8_t marker = bytes[index];
        if (marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7)) {
            index += 1;
            continue;
        }
        if (marker == 0xD9) {
            eoiOffset = markerIndex;
            return true;
        }
        return false;
    }
    return false;
}

std::string rationalString(const uint8_t *bytes, size_t offset, bool littleEndian) {
    uint32_t numerator = readU32(bytes, offset, littleEndian);
    uint32_t denominator = readU32(bytes, offset + 4, littleEndian);
    std::ostringstream stream;
    stream << numerator << "/" << denominator;
    if (denominator != 0) {
        stream << " (" << std::fixed << std::setprecision(2)
               << (static_cast<double>(numerator) / static_cast<double>(denominator)) << ")";
    }
    return stream.str();
}

std::string decodeTIFFValue(
    const uint8_t *bytes,
    size_t fileLength,
    size_t tiffOffset,
    size_t entryOffset,
    uint16_t tag,
    uint16_t type,
    uint32_t count,
    size_t valueOffset,
    size_t safeValueSize,
    bool littleEndian
) {
    std::ostringstream decoded;

    if ((tag == 0x011A || tag == 0x011B || tag == 0x829A || tag == 0x829D || tag == 0x920A) && safeValueSize >= 8) {
        decoded << rationalString(bytes, valueOffset, littleEndian);
        return decoded.str();
    }

    if (tag == 0x0128 && safeValueSize >= 2) {
        uint16_t unit = readU16(bytes, valueOffset, littleEndian);
        decoded << unit << " (" << (unit == 2 ? "inch" : unit == 3 ? "centimeter" : "unknown") << ")";
        return decoded.str();
    }

    if (tag == 0x8769 && safeValueSize >= 4) {
        uint32_t exifIfdOffset = readU32(bytes, entryOffset + 8, littleEndian);
        decoded << "offset " << exifIfdOffset;
        return decoded.str();
    }

    if ((type == 2 || tag == 0x9000) && safeValueSize > 0 && isPrintableAscii(bytes, valueOffset, safeValueSize)) {
        decoded << asciiValue(bytes, valueOffset, safeValueSize);
        return decoded.str();
    }

    if ((type == 3 || type == 4) && count == 1) {
        if (safeValueSize >= 2 && type == 3) {
            decoded << readU16(bytes, valueOffset, littleEndian);
            return decoded.str();
        }
        if (safeValueSize >= 4 && type == 4) {
            decoded << readU32(bytes, valueOffset, littleEndian);
            return decoded.str();
        }
    }

    if ((tag == 0xA002 || tag == 0xA003) && safeValueSize >= 4) {
        decoded << readU32(bytes, valueOffset, littleEndian) << " px";
        return decoded.str();
    }

    if (tag == 0xA001 && safeValueSize >= 2) {
        uint16_t colorSpace = readU16(bytes, valueOffset, littleEndian);
        decoded << colorSpace << " (" << (colorSpace == 1 ? "sRGB" : colorSpace == 65535 ? "uncalibrated" : "other") << ")";
        return decoded.str();
    }

    decoded << tiffTypeName(type) << " x " << count;
    return decoded.str();
}

bool appendIFDNode(
    Node &parentNode,
    const std::string &name,
    const uint8_t *bytes,
    size_t fileLength,
    size_t tiffOffset,
    size_t tiffLength,
    uint32_t relativeIFDOffset,
    bool littleEndian
) {
    if (relativeIFDOffset >= tiffLength) return false;

    size_t ifdOffset = tiffOffset + relativeIFDOffset;
    if (ifdOffset + 2 > fileLength) return false;

    uint16_t entryCount = readU16(bytes, ifdOffset, littleEndian);
    size_t ifdLength = 2 + (static_cast<size_t>(entryCount) * 12) + 4;
    if (ifdOffset + ifdLength > fileLength) return false;

    Node ifdNode{
        name,
        "ifd",
        "",
        ifdOffset,
        ifdLength,
        ifdOffset + 2,
        static_cast<size_t>(entryCount) * 12,
        std::to_string(entryCount) + " entries",
        "",
        littleEndian ? "le" : "be",
        0,
        {}
    };

    uint32_t exifIfdPointer = 0;

    for (uint16_t i = 0; i < entryCount; ++i) {
        size_t entryOffset = ifdOffset + 2 + (static_cast<size_t>(i) * 12);
        uint16_t tag = readU16(bytes, entryOffset, littleEndian);
        uint16_t type = readU16(bytes, entryOffset + 2, littleEndian);
        uint32_t count = readU32(bytes, entryOffset + 4, littleEndian);
        size_t valueSize = tiffTypeSize(type) * static_cast<size_t>(count);
        size_t valueOffset = entryOffset + 8;
        if (valueSize > 4) {
            uint32_t relativeOffset = readU32(bytes, entryOffset + 8, littleEndian);
            if (relativeOffset >= tiffLength) continue;
            valueOffset = tiffOffset + relativeOffset;
        }
        if (valueOffset >= fileLength) continue;
        size_t safeValueSize = std::min(valueSize, fileLength - valueOffset);

        std::string decodedValue = decodeTIFFValue(
            bytes,
            fileLength,
            tiffOffset,
            entryOffset,
            tag,
            type,
            count,
            valueOffset,
            safeValueSize,
            littleEndian
        );

        std::string editValueType;
        if (tag == 0x011A || tag == 0x011B || tag == 0x829A || tag == 0x829D || tag == 0x920A) {
            editValueType = "tiff-rational";
        } else if (type == 2 || tag == 0x9000) {
            editValueType = "ascii";
        } else if (type == 3) {
            editValueType = "tiff-short";
        } else if (type == 4) {
            editValueType = "tiff-long";
        }

        ifdNode.children.push_back(Node{
            tiffTagName(tag),
            "tiff-tag",
            "",
            entryOffset,
            12,
            valueOffset,
            safeValueSize,
            decodedValue,
            editValueType,
            littleEndian ? "le" : "be",
            safeValueSize,
            {}
        });

        if (tag == 0x8769 && safeValueSize >= 4) {
            exifIfdPointer = readU32(bytes, entryOffset + 8, littleEndian);
        }
    }

    parentNode.children.push_back(ifdNode);

    if (name == "IFD0" && exifIfdPointer != 0) {
        appendIFDNode(parentNode, "Exif IFD", bytes, fileLength, tiffOffset, tiffLength, exifIfdPointer, littleEndian);
    }

    return true;
}

void appendTIFFChildren(
    Node &app1Node,
    const uint8_t *bytes,
    size_t fileLength,
    size_t tiffOffset,
    size_t tiffLength
) {
    if (tiffLength < 8 || tiffOffset + tiffLength > fileLength) return;

    bool littleEndian = false;
    if (bytes[tiffOffset] == 'I' && bytes[tiffOffset + 1] == 'I') littleEndian = true;
    else if (!(bytes[tiffOffset] == 'M' && bytes[tiffOffset + 1] == 'M')) return;

    Node tiffHeader{
        "TIFF Header",
        "tiff-header",
        "",
        tiffOffset,
        8,
        tiffOffset + 4,
        4,
        littleEndian ? "Little Endian" : "Big Endian",
        "",
        littleEndian ? "le" : "be",
        0,
        {}
    };

    app1Node.children.push_back(tiffHeader);
    uint32_t firstIFDOffset = readU32(bytes, tiffOffset + 4, littleEndian);
    appendIFDNode(app1Node, "IFD0", bytes, fileLength, tiffOffset, tiffLength, firstIFDOffset, littleEndian);
}

void appendAppChildren(Node &node, const uint8_t *bytes, size_t fileLength) {
    if (node.name == "APP0" && node.payloadLength >= 14 && node.payloadOffset + 14 <= fileLength) {
        const uint8_t *payload = bytes + node.payloadOffset;
        if (std::memcmp(payload, "JFIF\0", 5) == 0) {
            uint8_t densityUnit = payload[7];
            uint16_t xDensity = static_cast<uint16_t>((payload[8] << 8) | payload[9]);
            uint16_t yDensity = static_cast<uint16_t>((payload[10] << 8) | payload[11]);

            node.children.push_back({"Identifier", "jfif-field", "", node.payloadOffset, 5, node.payloadOffset, 5, "JFIF", "", "be", 0, {}});
            node.children.push_back({"Version", "jfif-field", "", node.payloadOffset + 5, 2, node.payloadOffset + 5, 2,
                                     std::to_string(payload[5]) + "." + std::to_string(payload[6]), "", "be", 0, {}});
            node.children.push_back({"DensityUnit", "jfif-field", "", node.payloadOffset + 7, 1, node.payloadOffset + 7, 1,
                                     densityUnitName(densityUnit), "jfif-u8", "be", 1, {}});
            node.children.push_back({"XDensity", "jfif-field", "", node.payloadOffset + 8, 2, node.payloadOffset + 8, 2,
                                     std::to_string(xDensity), "jfif-u16", "be", 2, {}});
            node.children.push_back({"YDensity", "jfif-field", "", node.payloadOffset + 10, 2, node.payloadOffset + 10, 2,
                                     std::to_string(yDensity), "jfif-u16", "be", 2, {}});
            node.decodedValue = "JFIF";
        }
    }

    if (node.name == "APP1" && node.payloadLength >= 6 && node.payloadOffset + 6 <= fileLength) {
        const uint8_t *payload = bytes + node.payloadOffset;
        if (std::memcmp(payload, "Exif\0\0", 6) == 0) {
            node.decodedValue = "Exif";
            node.children.push_back({"Exif Header", "exif-header", "", node.payloadOffset, 6, node.payloadOffset, 6, "Exif\\0\\0", "", "be", 0, {}});
            appendTIFFChildren(node, bytes, fileLength, node.payloadOffset + 6, node.payloadLength - 6);
        }
    }
}

void writeNodeJSON(std::ostringstream &stream, const Node &node, int indent) {
    const std::string pad(indent, ' ');
    stream << pad << "{\n";
    stream << pad << "  \"name\" : \"" << jsonEscape(node.name) << "\",\n";
    stream << pad << "  \"kind\" : \"" << jsonEscape(node.kind) << "\",\n";
    stream << pad << "  \"markerHex\" : \"" << jsonEscape(node.markerHex) << "\",\n";
    stream << pad << "  \"offset\" : " << node.offset << ",\n";
    stream << pad << "  \"length\" : " << node.length << ",\n";
    stream << pad << "  \"payloadOffset\" : " << node.payloadOffset << ",\n";
    stream << pad << "  \"payloadLength\" : " << node.payloadLength << ",\n";
    stream << pad << "  \"decodedValue\" : \"" << jsonEscape(node.decodedValue) << "\",\n";
    stream << pad << "  \"editValueType\" : \"" << jsonEscape(node.editValueType) << "\",\n";
    stream << pad << "  \"byteOrder\" : \"" << jsonEscape(node.byteOrder) << "\",\n";
    stream << pad << "  \"maxEditableLength\" : " << node.maxEditableLength << ",\n";
    stream << pad << "  \"children\" : [\n";
    for (size_t i = 0; i < node.children.size(); ++i) {
        writeNodeJSON(stream, node.children[i], indent + 4);
        if (i + 1 < node.children.size()) stream << ",";
        stream << "\n";
    }
    stream << pad << "  ]\n";
    stream << pad << "}";
}

std::string parseToJSON(const uint8_t *bytes, size_t length) {
    if (length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
        return R"({"ok":false,"error":"Not a JPEG file"})";
    }

    std::vector<Node> segments;
    segments.push_back({"SOI", "marker", "0xFFD8", 0, 2, 2, 0, "", "", "be", 0, {}});

    size_t cursor = 2;
    while (cursor < length) {
        if (bytes[cursor] != 0xFF) {
            std::ostringstream err;
            err << R"({"ok":false,"error":"Expected marker prefix at offset )" << cursor << R"("})";
            return err.str();
        }

        size_t markerOffset = cursor;
        cursor += 1;
        while (cursor < length && bytes[cursor] == 0xFF) cursor += 1;
        if (cursor >= length) return R"({"ok":false,"error":"Unexpected EOF while reading marker"})";

        uint8_t marker = bytes[cursor];
        cursor += 1;

        if (marker == 0xD9) {
            segments.push_back({"EOI", "marker", "0xFFD9", markerOffset, 2, markerOffset + 2, 0, "", "", "be", 0, {}});
            break;
        }

        if (!hasDeclaredLength(marker)) {
            segments.push_back({markerName(marker), "marker", markerHex(marker), markerOffset, 2, markerOffset + 2, 0, "", "", "be", 0, {}});
            continue;
        }

        if (cursor + 1 >= length) return R"({"ok":false,"error":"Unexpected EOF while reading segment length"})";
        uint16_t declaredLength = readBE16(bytes, cursor);
        if (declaredLength < 2) {
            std::ostringstream err;
            err << R"({"ok":false,"error":"Invalid segment length at offset )" << markerOffset << R"("})";
            return err.str();
        }

        const size_t payloadOffset = cursor + 2;
        if (marker == 0xDA) {
            size_t eoiOffset = 0;
            if (!findEOIAfterSOS(bytes, length, payloadOffset + declaredLength - 2, eoiOffset)) {
                return R"({"ok":false,"error":"Failed to locate EOI after SOS"})";
            }
            const size_t totalLength = eoiOffset - markerOffset;
            const size_t payloadLength = totalLength - 4;
            segments.push_back({"SOS", "segment", "0xFFDA", markerOffset, totalLength, payloadOffset, payloadLength, "", "", "be", 0, {}});
            segments.push_back({"EOI", "marker", "0xFFD9", eoiOffset, 2, eoiOffset + 2, 0, "", "", "be", 0, {}});
            break;
        }

        const size_t totalLength = static_cast<size_t>(declaredLength) + 2;
        if (markerOffset + totalLength > length) {
            std::ostringstream err;
            err << R"({"ok":false,"error":"Segment exceeds file length at offset )" << markerOffset << R"("})";
            return err.str();
        }

        Node node{markerName(marker), "segment", markerHex(marker), markerOffset, totalLength, payloadOffset,
                  static_cast<size_t>(declaredLength - 2), "", "", "be", 0, {}};
        appendAppChildren(node, bytes, length);
        segments.push_back(node);
        cursor = markerOffset + totalLength;
    }

    std::ostringstream stream;
    stream << "{\n";
    stream << "  \"ok\" : true,\n";
    stream << "  \"fileLength\" : " << length << ",\n";
    stream << "  \"segmentCount\" : " << segments.size() << ",\n";
    stream << "  \"segments\" : [\n";
    for (size_t i = 0; i < segments.size(); ++i) {
        writeNodeJSON(stream, segments[i], 4);
        if (i + 1 < segments.size()) stream << ",";
        stream << "\n";
    }
    stream << "  ]\n";
    stream << "}\n";
    return stream.str();
}
} // namespace

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

const char *DPIEngineParseJPEGStructure(const uint8_t *bytes, size_t length) {
    const std::string json = parseToJSON(bytes, length);
    char *buffer = static_cast<char *>(std::malloc(json.size() + 1));
    if (buffer == nullptr) return nullptr;
    std::memcpy(buffer, json.c_str(), json.size() + 1);
    return buffer;
}

void DPIEngineFreeString(const char *value) {
    std::free(const_cast<char *>(value));
}
