#include "JPEGStructureParser.h"

#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

namespace {

struct Segment {
    std::string name;
    std::string markerHex;
    size_t offset;
    size_t length;
    size_t payloadOffset;
    size_t payloadLength;
};

std::string jsonEscape(const std::string &value) {
    std::ostringstream stream;
    for (char ch : value) {
        switch (ch) {
        case '\\':
            stream << "\\\\";
            break;
        case '"':
            stream << "\\\"";
            break;
        case '\n':
            stream << "\\n";
            break;
        default:
            stream << ch;
            break;
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
    case 0xD8:
        return "SOI";
    case 0xD9:
        return "EOI";
    case 0xDA:
        return "SOS";
    case 0xDB:
        return "DQT";
    case 0xC4:
        return "DHT";
    case 0xC0:
        return "SOF0";
    case 0xC1:
        return "SOF1";
    case 0xC2:
        return "SOF2";
    case 0xC3:
        return "SOF3";
    case 0xC5:
        return "SOF5";
    case 0xC6:
        return "SOF6";
    case 0xC7:
        return "SOF7";
    case 0xC9:
        return "SOF9";
    case 0xCA:
        return "SOF10";
    case 0xCB:
        return "SOF11";
    case 0xCD:
        return "SOF13";
    case 0xCE:
        return "SOF14";
    case 0xCF:
        return "SOF15";
    case 0xDD:
        return "DRI";
    case 0xFE:
        return "COM";
    default:
        if (marker >= 0xE0 && marker <= 0xEF) {
            return "APP" + std::to_string(marker - 0xE0);
        }
        if (marker >= 0xD0 && marker <= 0xD7) {
            return "RST" + std::to_string(marker - 0xD0);
        }
        return "UNKNOWN";
    }
}

bool hasDeclaredLength(uint8_t marker) {
    if (marker == 0xD8 || marker == 0xD9) {
        return false;
    }
    if (marker >= 0xD0 && marker <= 0xD7) {
        return false;
    }
    if (marker == 0x01) {
        return false;
    }
    return true;
}

uint16_t readBE16(const uint8_t *bytes, size_t offset) {
    return static_cast<uint16_t>((bytes[offset] << 8) | bytes[offset + 1]);
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
        while (index < length && bytes[index] == 0xFF) {
            index += 1;
        }
        if (index >= length) {
            return false;
        }

        uint8_t marker = bytes[index];
        if (marker == 0x00) {
            index += 1;
            continue;
        }
        if (marker >= 0xD0 && marker <= 0xD7) {
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

std::string parseToJSON(const uint8_t *bytes, size_t length) {
    if (length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
        return R"({"ok":false,"error":"Not a JPEG file"})";
    }

    std::vector<Segment> segments;
    segments.push_back({"SOI", "0xFFD8", 0, 2, 2, 0});

    size_t cursor = 2;
    while (cursor < length) {
        if (bytes[cursor] != 0xFF) {
            std::ostringstream err;
            err << R"({"ok":false,"error":"Expected marker prefix at offset )" << cursor << R"("})";
            return err.str();
        }

        size_t markerOffset = cursor;
        cursor += 1;
        while (cursor < length && bytes[cursor] == 0xFF) {
            cursor += 1;
        }
        if (cursor >= length) {
            return R"({"ok":false,"error":"Unexpected EOF while reading marker"})";
        }

        uint8_t marker = bytes[cursor];
        cursor += 1;

        if (marker == 0xD9) {
            segments.push_back({"EOI", "0xFFD9", markerOffset, 2, markerOffset + 2, 0});
            break;
        }

        if (!hasDeclaredLength(marker)) {
            segments.push_back({markerName(marker), markerHex(marker), markerOffset, 2, markerOffset + 2, 0});
            continue;
        }

        if (cursor + 1 >= length) {
            return R"({"ok":false,"error":"Unexpected EOF while reading segment length"})";
        }
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
            segments.push_back({"SOS", "0xFFDA", markerOffset, totalLength, payloadOffset, payloadLength});
            segments.push_back({"EOI", "0xFFD9", eoiOffset, 2, eoiOffset + 2, 0});
            break;
        }

        const size_t totalLength = static_cast<size_t>(declaredLength) + 2;
        if (markerOffset + totalLength > length) {
            std::ostringstream err;
            err << R"({"ok":false,"error":"Segment exceeds file length at offset )" << markerOffset << R"("})";
            return err.str();
        }

        segments.push_back({
            markerName(marker),
            markerHex(marker),
            markerOffset,
            totalLength,
            payloadOffset,
            static_cast<size_t>(declaredLength - 2),
        });
        cursor = markerOffset + totalLength;
    }

    std::ostringstream stream;
    stream << "{\n";
    stream << "  \"ok\" : true,\n";
    stream << "  \"fileLength\" : " << length << ",\n";
    stream << "  \"segmentCount\" : " << segments.size() << ",\n";
    stream << "  \"segments\" : [\n";
    for (size_t i = 0; i < segments.size(); ++i) {
        const Segment &segment = segments[i];
        stream << "    {\n";
        stream << "      \"name\" : \"" << jsonEscape(segment.name) << "\",\n";
        stream << "      \"markerHex\" : \"" << segment.markerHex << "\",\n";
        stream << "      \"offset\" : " << segment.offset << ",\n";
        stream << "      \"length\" : " << segment.length << ",\n";
        stream << "      \"payloadOffset\" : " << segment.payloadOffset << ",\n";
        stream << "      \"payloadLength\" : " << segment.payloadLength << "\n";
        stream << "    }";
        if (i + 1 < segments.size()) {
            stream << ",";
        }
        stream << "\n";
    }
    stream << "  ]\n";
    stream << "}\n";
    return stream.str();
}

} // namespace

const char *ParseJPEGStructure(const uint8_t *bytes, size_t length) {
    const std::string json = parseToJSON(bytes, length);
    char *buffer = static_cast<char *>(std::malloc(json.size() + 1));
    if (buffer == nullptr) {
        return nullptr;
    }
    std::memcpy(buffer, json.c_str(), json.size() + 1);
    return buffer;
}

void FreeJPEGStructureString(const char *value) {
    std::free(const_cast<char *>(value));
}
