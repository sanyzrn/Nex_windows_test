// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef RUNNER_NATIVE_CLIPBOARD_H_
#define RUNNER_NATIVE_CLIPBOARD_H_

#include <windows.h>
#include <cstdint>
#include <string>
#include <vector>

bool SetClipboardText(const std::wstring& text);
std::string GetClipboardText();
void SetClipboardImage(int w, int h, const std::vector<uint8_t>& rgba);
bool ReadRawClipboardImage(std::vector<uint8_t>& out_rgba, uint32_t& out_w, uint32_t& out_h);
void Downscale(uint32_t w, uint32_t h, const std::vector<uint8_t>& src,
               uint32_t max_dim, uint32_t* out_w, uint32_t* out_h,
               std::vector<uint8_t>* out);

#endif  // RUNNER_NATIVE_CLIPBOARD_H_
