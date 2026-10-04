// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_pickers.h"
#include "native_common.h"

#include <commctrl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <algorithm>
#include <cctype>
#include <vector>

std::string IconDataUriFor(const std::string& path) {
  const std::wstring wide = Utf16FromUtf8(path);
  HICON icon = nullptr;
  std::string lower = path;
  std::transform(lower.begin(), lower.end(), lower.begin(),
    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  if (lower.size() > 4 && lower.substr(lower.size() - 4) == ".exe") {
    UINT id = 0;
    PrivateExtractIconsW(wide.c_str(), 0, 64, 64, &icon, &id, 1, 0);
  }
  if (icon == nullptr) {
    SHFILEINFOW info = {};
    SHGetFileInfoW(wide.c_str(), FILE_ATTRIBUTE_NORMAL, &info, sizeof(info),
                   SHGFI_SYSICONINDEX);
    // {46EB5926-582E-4017-9FDF-E8998DAA0950} = IID_IImageList
    const CLSID iid_iimagelist = {0x46eb5926, 0x582e, 0x4017,
                                  {0x9f, 0xdf, 0xe8, 0x99, 0x8d, 0xaa, 0x09, 0x50}};
    void* list = nullptr;
    if (SHGetImageList(SHIL_EXTRALARGE, iid_iimagelist, &list) >= 0 && list != nullptr) {
      icon = ImageList_GetIcon((HIMAGELIST)list, info.iIcon, ILD_TRANSPARENT);
      reinterpret_cast<IUnknown*>(list)->Release();
    }
  }
  if (icon == nullptr) return std::string();
  ICONINFO ii = {};
  GetIconInfo(icon, &ii);
  std::string out;
  if (ii.hbmColor != nullptr) {
    BITMAP bm = {};
    GetObjectW(ii.hbmColor, sizeof(bm), &bm);
    if (bm.bmWidth > 0 && bm.bmHeight > 0) {
      BITMAPINFO bi = {};
      bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
      bi.bmiHeader.biWidth = bm.bmWidth;
      bi.bmiHeader.biHeight = -bm.bmHeight;
      bi.bmiHeader.biPlanes = 1;
      bi.bmiHeader.biBitCount = 32;
      bi.bmiHeader.biCompression = BI_RGB;
      const size_t px_count = static_cast<size_t>(bm.bmWidth) * bm.bmHeight;
      std::vector<uint8_t> px(px_count * 4);
      HDC dc = CreateCompatibleDC(nullptr);
      if (GetDIBits(dc, ii.hbmColor, 0, bm.bmHeight, px.data(), &bi,
                    DIB_RGB_COLORS) != 0) {
        bool has_alpha = false;
        for (size_t i = 3; i < px.size(); i += 4) {
          if (px[i] != 0) {
            has_alpha = true;
            break;
          }
        }
        for (size_t i = 0; i < px.size(); i += 4) {
          std::swap(px[i], px[i + 2]);  // BGRA -> RGBA
          if (!has_alpha) px[i + 3] = 255;
        }
        const auto png = PngEncode(static_cast<uint32_t>(bm.bmWidth),
                                   static_cast<uint32_t>(bm.bmHeight), px);
        out = "data:image/png;base64," + Base64Encode(png);
      }
      DeleteDC(dc);
    }
  }
  if (ii.hbmMask != nullptr) DeleteObject(ii.hbmMask);
  if (ii.hbmColor != nullptr) DeleteObject(ii.hbmColor);
  DestroyIcon(icon);
  return out;
}
