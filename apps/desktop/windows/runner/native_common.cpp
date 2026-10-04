// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_common.h"

#include <algorithm>
#include <cmath>

using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring Utf16FromUtf8Inner(const std::string& s) {
  if (s.empty()) return std::wstring();
  int len = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
  std::wstring out(len, 0);
  MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), len);
  return out;
}

std::string Utf8FromUtf16Inner(const wchar_t* s) {
  if (s == nullptr) return std::string();
  int len = WideCharToMultiByte(CP_UTF8, 0, s, -1, nullptr, 0, nullptr, nullptr);
  if (len <= 1) return std::string();
  std::string out(len - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, s, -1, out.data(), len, nullptr, nullptr);
  return out;
}

std::wstring Utf16FromUtf8(const std::string& s) {
  return Utf16FromUtf8Inner(s);
}

std::string PanelUtf8FromUtf16(const wchar_t* s) {
  return Utf8FromUtf16Inner(s);
}

const EncodableValue* FindArg(const EncodableMap* m, const char* key) {
  if (m == nullptr) return nullptr;
  auto it = m->find(EncodableValue(key));
  return it == m->end() ? nullptr : &it->second;
}

std::string ArgString(const EncodableMap* m, const char* key) {
  const auto* v = FindArg(m, key);
  const auto* s = v ? std::get_if<std::string>(v) : nullptr;
  return s ? *s : std::string();
}

bool ArgBool(const EncodableMap* m, const char* key) {
  const auto* v = FindArg(m, key);
  if (!v) return false;
  if (const auto* b = std::get_if<bool>(v)) return *b;
  if (const auto* i = std::get_if<int32_t>(v)) return *i != 0;
  if (const auto* l = std::get_if<int64_t>(v)) return *l != 0;
  return false;
}

int ArgInt(const EncodableMap* m, const char* key) {
  const auto* v = FindArg(m, key);
  if (!v) return 0;
  if (const auto* i = std::get_if<int32_t>(v)) return *i;
  if (const auto* l = std::get_if<int64_t>(v)) return static_cast<int>(*l);
  if (const auto* d = std::get_if<double>(v)) return static_cast<int>(*d);
  return 0;
}

int64_t ArgInt64(const EncodableMap* m, const char* key) {
  const auto* v = FindArg(m, key);
  if (!v) return 0;
  if (const auto* l = std::get_if<int64_t>(v)) return *l;
  if (const auto* i = std::get_if<int32_t>(v)) return static_cast<int64_t>(*i);
  if (const auto* d = std::get_if<double>(v)) return static_cast<int64_t>(*d);
  return 0;
}

std::vector<uint8_t> ArgBytes(const EncodableMap* m, const char* key) {
  const auto* v = FindArg(m, key);
  const auto* b = v ? std::get_if<std::vector<uint8_t>>(v) : nullptr;
  return b ? *b : std::vector<uint8_t>();
}

namespace {

void WriteBE32(std::vector<uint8_t>* out, uint32_t v) {
  out->push_back(static_cast<uint8_t>((v >> 24) & 0xff));
  out->push_back(static_cast<uint8_t>((v >> 16) & 0xff));
  out->push_back(static_cast<uint8_t>((v >> 8) & 0xff));
  out->push_back(static_cast<uint8_t>(v & 0xff));
}

uint32_t Crc32(const uint8_t* data, size_t len) {
  uint32_t c = ~0u;
  for (size_t i = 0; i < len; i++) {
    c ^= data[i];
    for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xedb88320u & -(int)(c & 1));
  }
  return ~c;
}

void AppendChunk(std::vector<uint8_t>* out, const char* kind, const uint8_t* data, size_t len) {
  WriteBE32(out, static_cast<uint32_t>(len));
  std::vector<uint8_t> body(kind, kind + 4);
  if (data != nullptr && len > 0) {
    body.insert(body.end(), data, data + len);
  }
  out->insert(out->end(), body.begin(), body.end());
  WriteBE32(out, Crc32(body.data(), body.size()));
}

}  // namespace

std::vector<uint8_t> PngEncode(uint32_t w, uint32_t h,
                               const std::vector<uint8_t>& rgba) {
  std::vector<uint8_t> raw;
  raw.reserve(static_cast<size_t>(h) * (static_cast<size_t>(w) * 4 + 1));
  for (uint32_t y = 0; y < h; y++) {
    raw.push_back(0);
    raw.insert(raw.end(), rgba.begin() + static_cast<size_t>(y) * w * 4,
               rgba.begin() + static_cast<size_t>(y + 1) * w * 4);
  }
  std::vector<uint8_t> z{0x78, 0x01};
  const size_t chunk = 65535;
  const size_t blocks = (raw.size() + chunk - 1) / chunk;
  for (size_t i = 0; i < blocks; i++) {
    const size_t start = i * chunk;
    const size_t len = std::min(chunk, raw.size() - start);
    const bool last = (i == blocks - 1);
    z.push_back(last ? 1 : 0);
    z.push_back(static_cast<uint8_t>(len & 0xff));
    z.push_back(static_cast<uint8_t>((len >> 8) & 0xff));
    const uint16_t nlen = static_cast<uint16_t>(~static_cast<uint16_t>(len));
    z.push_back(static_cast<uint8_t>(nlen & 0xff));
    z.push_back(static_cast<uint8_t>((nlen >> 8) & 0xff));
    z.insert(z.end(), raw.begin() + start, raw.begin() + start + len);
  }
  uint32_t a = 1, b = 0;
  for (uint8_t byte : raw) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  WriteBE32(&z, (b << 16) | a);

  std::vector<uint8_t> out{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'};
  std::vector<uint8_t> ihdr;
  WriteBE32(&ihdr, w);
  WriteBE32(&ihdr, h);
  ihdr.insert(ihdr.end(), {8, 6, 0, 0, 0});
  AppendChunk(&out, "IHDR", ihdr.data(), ihdr.size());
  AppendChunk(&out, "IDAT", z.data(), z.size());
  AppendChunk(&out, "IEND", nullptr, 0);
  return out;
}

std::string Base64Encode(const std::vector<uint8_t>& data) {
  static const char* table =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string s;
  s.reserve(data.size() * 4 / 3 + 4);
  for (size_t i = 0; i < data.size(); i += 3) {
    const uint32_t n = (static_cast<uint32_t>(data[i]) << 16) |
                       (i + 1 < data.size() ? (static_cast<uint32_t>(data[i + 1]) << 8) : 0) |
                       (i + 2 < data.size() ? static_cast<uint32_t>(data[i + 2]) : 0);
    const size_t have = std::min(static_cast<size_t>(3), data.size() - i);
    for (int k = 0; k < 4; k++) {
      if (static_cast<size_t>(k) <= have) {
        s.push_back(table[(n >> (18 - 6 * k)) & 63]);
      } else {
        s.push_back('=');
      }
    }
  }
  return s;
}

uint64_t FnvHash(const std::vector<uint8_t>& data) {
  uint64_t h = 0xcbf29ce484222325ULL;
  for (uint8_t byte : data) {
    h = (h ^ byte) * 0x100000001b3ULL;
  }
  return h ^ data.size();
}
