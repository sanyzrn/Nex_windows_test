// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef RUNNER_NATIVE_NOTIFICATIONS_H_
#define RUNNER_NATIVE_NOTIFICATIONS_H_

#include <string>
#include <vector>
#include <cstdint>
#include <utility>

bool ScheduleToastNotification(const std::string& id,
                               const std::string& noteId,
                               const std::string& title,
                               const std::string& body,
                               int64_t fireAtEpochMs,
                               int64_t revision = -1);

bool CancelScheduledToastNotification(const std::string& id, bool clearDelivered = false);

// [occurrenceEpochMs] names the occurrence being delivered (0 when it does not
// matter). A toast already delivered for the same occurrence — Windows' own
// scheduled one — is not shown a second time.
bool ShowImmediateToast(const std::string& id,
                        const std::string& noteId,
                        const std::string& title,
                        const std::string& body,
                        int64_t occurrenceEpochMs = 0,
                        int64_t revision = -1);

void SetReminderLabels(const std::string& snooze, const std::string& done);

std::vector<std::string> ListScheduledToastIds();
std::vector<std::pair<std::string, int64_t>> ListScheduledToastDetails();
std::string ReminderDiagnosticError();
// Parse synthetic action XML with the same WinRT DOM used by the queue.
bool VerifyReminderActionMarkup();

#endif  // RUNNER_NATIVE_NOTIFICATIONS_H_
