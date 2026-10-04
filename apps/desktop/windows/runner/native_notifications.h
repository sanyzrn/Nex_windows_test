// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef RUNNER_NATIVE_NOTIFICATIONS_H_
#define RUNNER_NATIVE_NOTIFICATIONS_H_

#include <string>
#include <vector>
#include <cstdint>

bool ScheduleToastNotification(const std::string& id,
                               const std::string& noteId,
                               const std::string& title,
                               const std::string& body,
                               int64_t fireAtEpochMs);

bool CancelScheduledToastNotification(const std::string& id);

bool ShowImmediateToast(const std::string& id,
                        const std::string& noteId,
                        const std::string& title,
                        const std::string& body);

std::vector<std::string> ListScheduledToastIds();

#endif  // RUNNER_NATIVE_NOTIFICATIONS_H_
