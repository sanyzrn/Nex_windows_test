// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef RUNNER_NATIVE_HOTKEYS_H_
#define RUNNER_NATIVE_HOTKEYS_H_

#include <windows.h>
#include <string>
#include <vector>

void SendCombo(const std::vector<WORD>& combo);
std::vector<WORD> ComboFor(const std::string& name);

#endif  // RUNNER_NATIVE_HOTKEYS_H_
