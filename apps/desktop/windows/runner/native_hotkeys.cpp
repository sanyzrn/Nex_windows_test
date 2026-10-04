// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_hotkeys.h"

void SendCombo(const std::vector<WORD>& combo) {
  std::vector<INPUT> inputs;
  for (WORD vk : combo) {
    INPUT down = {};
    down.type = INPUT_KEYBOARD;
    down.ki.wVk = vk;
    inputs.push_back(down);
  }
  for (auto it = combo.rbegin(); it != combo.rend(); ++it) {
    INPUT up = {};
    up.type = INPUT_KEYBOARD;
    up.ki.wVk = *it;
    up.ki.dwFlags = KEYEVENTF_KEYUP;
    inputs.push_back(up);
  }
  SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
}

std::vector<WORD> ComboFor(const std::string& name) {
  const WORD play = 0xB3, next = 0xB0, prev = 0xB1, mute = 0xAD,
            volup = 0xAF, voldown = 0xAE, lwin = 0x5B, d = 0x44;
  if (name == "play") return {play};
  if (name == "next") return {next};
  if (name == "prev") return {prev};
  if (name == "mute") return {mute};
  if (name == "volup") return {volup};
  if (name == "voldown") return {voldown};
  if (name == "desktop") return {lwin, d};
  return {};
}
