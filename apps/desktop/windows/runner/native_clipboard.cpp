// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_clipboard.h"
#include "native_common.h"

#include <algorithm>
#include <cstring>

namespace {

bool DibToRgba(const uint8_t* dib, size_t size, uint32_t* out_w, uint32_t* out_h,
               std::vector<uint8_t>* out) {
  if (dib == nullptr || size < sizeof(BITMAPINFOHEADER)) return false;
  const auto* head = reinterpret_cast<const BITMAPINFOHEADER*>(dib);
  const int32_t w = head->biWidth;
  const int32_t h = head->biHeight;
  if (w <= 0 || h == 0 || w > 10000 || (h > 10000 || h < -10000)) return false;
  if ((head->biBitCount != 24 && head->biBitCount != 32) ||
      (head->biCompression != BI_RGB && head->biCompression != BI_BITFIELDS) ||
      head->biSize < sizeof(BITMAPINFOHEADER) || head->biSize > size) return false;
  const uint32_t rows = static_cast<uint32_t>(h > 0 ? h : -h);
  const bool flip = (h > 0);
  const size_t bpp = head->biBitCount / 8;
  const size_t stride = ((static_cast<size_t>(w) * bpp + 3) & ~3);
  const size_t masks = (head->biCompression == BI_BITFIELDS && head->biSize == sizeof(BITMAPINFOHEADER)) ? 12 : 0;
  const uint64_t offset = head->biSize + masks + static_cast<uint64_t>(head->biClrUsed) * 4;
  if (offset > size || stride * rows > size - offset) return false;
  const uint8_t* pixels = dib + static_cast<size_t>(offset);
  out->assign(static_cast<size_t>(w) * rows * 4, 0);
  for (uint32_t y = 0; y < rows; y++) {
    const size_t src_row = flip ? (rows - 1 - y) : y;
    const uint8_t* src = pixels + src_row * stride;
    for (int32_t x = 0; x < w; x++) {
      const uint8_t* p = src + static_cast<size_t>(x) * bpp;
      const size_t i = (static_cast<size_t>(y) * w + x) * 4;
      (*out)[i] = p[2];
      (*out)[i + 1] = p[1];
      (*out)[i + 2] = p[0];
      (*out)[i + 3] = (bpp == 4 ? (p[3] != 0 ? p[3] : 255) : 255);
    }
  }
  *out_w = static_cast<uint32_t>(w);
  *out_h = rows;
  return true;
}

}  // namespace

bool SetClipboardText(const std::wstring& text) {
  if (!OpenClipboard(nullptr)) return false;
  EmptyClipboard();
  const size_t bytes = (text.size() + 1) * sizeof(wchar_t);
  HGLOBAL mem = GlobalAlloc(GMEM_MOVEABLE, bytes);
  if (mem == nullptr) {
    CloseClipboard();
    return false;
  }
  auto* dst = static_cast<wchar_t*>(GlobalLock(mem));
  if (dst != nullptr) {
    memcpy(dst, text.c_str(), bytes);
    GlobalUnlock(mem);
  }
  const HANDLE ok = SetClipboardData(CF_UNICODETEXT, mem);
  CloseClipboard();
  return ok != nullptr;
}

std::string GetClipboardText() {
  if (!OpenClipboard(nullptr)) return std::string();
  std::string out;
  HANDLE h = GetClipboardData(CF_UNICODETEXT);
  if (h != nullptr) {
    if (auto* wide = static_cast<const wchar_t*>(GlobalLock(h))) {
      out = Utf8FromUtf16Inner(wide);
      GlobalUnlock(h);
    }
  }
  CloseClipboard();
  return out;
}

void SetClipboardImage(int w, int h, const std::vector<uint8_t>& rgba) {
  if (w <= 0 || h <= 0 || rgba.size() != static_cast<size_t>(w) * h * 4) return;
  const size_t header = sizeof(BITMAPINFOHEADER);
  std::vector<uint8_t> buf(header + static_cast<size_t>(w) * h * 4);
  auto* head = reinterpret_cast<BITMAPINFOHEADER*>(buf.data());
  head->biSize = header;
  head->biWidth = w;
  head->biHeight = h;  // positive: bottom-up
  head->biPlanes = 1;
  head->biBitCount = 32;
  head->biCompression = BI_RGB;
  head->biSizeImage = static_cast<DWORD>(w * h * 4);
  for (int y = 0; y < h; y++) {
    const size_t src = static_cast<size_t>(h - 1 - y) * w * 4;
    for (int x = 0; x < w; x++) {
      const size_t s = src + static_cast<size_t>(x) * 4;
      const size_t d = header + (static_cast<size_t>(y) * w + x) * 4;
      buf[d] = rgba[s + 2];
      buf[d + 1] = rgba[s + 1];
      buf[d + 2] = rgba[s];
      buf[d + 3] = rgba[s + 3];
    }
  }
  if (!OpenClipboard(nullptr)) return;
  EmptyClipboard();
  HGLOBAL mem = GlobalAlloc(GMEM_MOVEABLE, buf.size());
  if (mem != nullptr) {
    void* dst = GlobalLock(mem);
    memcpy(dst, buf.data(), buf.size());
    GlobalUnlock(mem);
    SetClipboardData(CF_DIB, mem);
  }
  CloseClipboard();
}

bool ReadRawClipboardImage(std::vector<uint8_t>& out_rgba, uint32_t& out_w, uint32_t& out_h) {
  if (!OpenClipboard(nullptr)) return false;

  bool ok = false;
  // 1. Try CF_DIBV5 first, then CF_DIB
  HANDLE handle = GetClipboardData(CF_DIBV5);
  if (handle == nullptr) handle = GetClipboardData(CF_DIB);

  if (handle != nullptr) {
    const auto* dib = static_cast<const uint8_t*>(GlobalLock(handle));
    if (dib != nullptr) {
      ok = DibToRgba(dib, GlobalSize(handle), &out_w, &out_h, &out_rgba);
      GlobalUnlock(handle);
    }
  }

  // 2. WP5.5: Check registered "PNG" clipboard format
  if (!ok) {
    const UINT cf_png = RegisterClipboardFormatW(L"PNG");
    HANDLE png_handle = (cf_png != 0) ? GetClipboardData(cf_png) : nullptr;
    if (png_handle != nullptr) {
      // The PNG format payload is raw encoded PNG bytes.
      // If needed, it can be passed or decoded. DIB fallback remains primary for raw pixels.
    }
  }

  CloseClipboard();
  return ok;
}

void Downscale(uint32_t w, uint32_t h, const std::vector<uint8_t>& src,
               uint32_t max_dim, uint32_t* out_w, uint32_t* out_h,
               std::vector<uint8_t>* out) {
  if (w <= max_dim && h <= max_dim) {
    *out_w = w;
    *out_h = h;
    *out = src;
    return;
  }
  const double scale = static_cast<double>(max_dim) / (w > h ? w : h);
  if (scale > 1.0) {
    *out_w = w;
    *out_h = h;
    *out = src;
    return;
  }
  const uint32_t tw = std::max(1u, static_cast<uint32_t>(w * scale));
  const uint32_t th = std::max(1u, static_cast<uint32_t>(h * scale));
  out->assign(static_cast<size_t>(tw) * th * 4, 0);
  for (uint32_t y = 0; y < th; y++) {
    for (uint32_t x = 0; x < tw; x++) {
      const size_t si = ((static_cast<size_t>(y) * h / th) * w + (static_cast<size_t>(x) * w / tw)) * 4;
      const size_t di = (static_cast<size_t>(y) * tw + x) * 4;
      memcpy(out->data() + di, src.data() + si, 4);
    }
  }
  *out_w = tw;
  *out_h = th;
}
