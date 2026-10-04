// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef RUNNER_NATIVE_COMMON_H_
#define RUNNER_NATIVE_COMMON_H_

#include <windows.h>
#include <cstdint>
#include <string>
#include <vector>

#include <flutter/encodable_value.h>

std::wstring Utf16FromUtf8(const std::string& s);
std::string PanelUtf8FromUtf16(const wchar_t* s);
std::wstring Utf16FromUtf8Inner(const std::string& s);
std::string Utf8FromUtf16Inner(const wchar_t* s);

const flutter::EncodableValue* FindArg(const flutter::EncodableMap* m, const char* key);
std::string ArgString(const flutter::EncodableMap* m, const char* key);
bool ArgBool(const flutter::EncodableMap* m, const char* key);
int ArgInt(const flutter::EncodableMap* m, const char* key);
int64_t ArgInt64(const flutter::EncodableMap* m, const char* key);
std::vector<uint8_t> ArgBytes(const flutter::EncodableMap* m, const char* key);

std::vector<uint8_t> PngEncode(uint32_t w, uint32_t h, const std::vector<uint8_t>& rgba);
std::string Base64Encode(const std::vector<uint8_t>& data);
uint64_t FnvHash(const std::vector<uint8_t>& data);

#endif  // RUNNER_NATIVE_COMMON_H_
