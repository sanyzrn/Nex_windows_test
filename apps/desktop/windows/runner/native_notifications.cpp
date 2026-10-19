// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_notifications.h"
#include "native_common.h"

#include <windows.h>
#include <chrono>
#include <iostream>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.UI.Notifications.h>

namespace {

const wchar_t kAppUserModelId[] = L"Nex.Desktop.App";
std::string last_reminder_error;

bool NotificationsEnabledOrUnknown(
    const winrt::Windows::UI::Notifications::ToastNotifier& notifier) {
  try {
    return notifier.Setting() ==
        winrt::Windows::UI::Notifications::NotificationSetting::Enabled;
  } catch (const winrt::hresult_error& error) {
    // Unpackaged desktop apps may schedule successfully while this optional
    // property reports ERROR_NOT_FOUND. Honor real blocks; let AddToSchedule
    // determine success when Windows cannot report the setting.
    if (error.code() == HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) return true;
    throw;
  }
}

// One tag per occurrence: "id@seconds". A scheduled toast carries it, so the
// toast Windows delivers and the one Nex would show as a fallback are the same
// notification to the Action Center.
std::wstring OccurrenceTag(const std::wstring& id, int64_t epochMs) {
  if (epochMs <= 0) return id;
  return id + L"@" + std::to_wstring(epochMs / 1000);
}

bool AlreadyDelivered(const std::wstring& tag) {
  try {
    using namespace winrt::Windows::UI::Notifications;
    for (auto const& shown :
         ToastNotificationManager::History().GetHistory(kAppUserModelId)) {
      if (shown.Tag() == tag) return true;
    }
  } catch (...) {
    // No history to read: behave as if nothing was delivered.
  }
  return false;
}

std::wstring EscapeXml(const std::wstring& s) {
  std::wstring out;
  for (wchar_t c : s) {
    if (c < 0x20 && c != L'\n' && c != L'\r' && c != L'\t') continue;
    switch (c) {
      case L'&': out += L"&amp;"; break;
      case L'<': out += L"&lt;"; break;
      case L'>': out += L"&gt;"; break;
      case L'"': out += L"&quot;"; break;
      case L'\'': out += L"&apos;"; break;
      default: out += c; break;
    }
  }
  return out;
}

}  // namespace

bool ScheduleToastNotification(const std::string& id,
                               const std::string& noteId,
                               const std::string& title,
                               const std::string& body,
                               int64_t fireAtEpochMs) {
  last_reminder_error.clear();
  const char* stage = "xml";
  try {
    using namespace winrt::Windows::Data::Xml::Dom;
    using namespace winrt::Windows::UI::Notifications;
    using namespace winrt::Windows::Foundation;

    const std::wstring wideId = Utf16FromUtf8(id);
    const std::wstring wideNoteId = Utf16FromUtf8(noteId);
    const std::wstring wideTitle = EscapeXml(Utf16FromUtf8(title.empty() ? "Nex Reminder" : title));
    const std::wstring wideBody = EscapeXml(Utf16FromUtf8(body));

    std::wstring xml =
        L"<toast activationType=\"protocol\" launch=\"nex-win://note/" + EscapeXml(wideNoteId) + L"\">"
        L"<visual><binding template=\"ToastGeneric\">"
        L"<text>" + wideTitle + L"</text>"
        L"<text>" + wideBody + L"</text>"
        L"</binding></visual>"
        L"<actions>"
        L"<action content=\"\" arguments=\"dismiss\" activationType=\"system\"/>"
        L"</actions></toast>";

    XmlDocument doc;
    doc.LoadXml(xml);

    auto fireTime = winrt::clock::from_time_t(fireAtEpochMs / 1000);
    // Add remaining milliseconds
    fireTime += std::chrono::milliseconds(fireAtEpochMs % 1000);

    stage = "constructor";
    ScheduledToastNotification scheduled(doc, fireTime);
    stage = "id";
    scheduled.Id(wideId);
    stage = "tag";
    scheduled.Tag(OccurrenceTag(wideId, fireAtEpochMs));

    stage = "notifier";
    auto notifier = ToastNotificationManager::CreateToastNotifier(kAppUserModelId);
    stage = "setting";
    if (!NotificationsEnabledOrUnknown(notifier)) {
      last_reminder_error = "NotificationSetting=" + std::to_string(static_cast<int>(notifier.Setting()));
      return false;
    }
    stage = "list";
    for (auto const& old : notifier.GetScheduledToastNotifications()) {
      if (old.Id() == wideId) notifier.RemoveFromSchedule(old);
    }
    stage = "add";
    notifier.AddToSchedule(scheduled);
    return true;
  } catch (const winrt::hresult_error& error) {
    last_reminder_error = std::string(stage) + ": " + std::to_string(static_cast<int32_t>(error.code())) + ": " +
        PanelUtf8FromUtf16(error.message().c_str());
    return false;
  } catch (...) {
    last_reminder_error = "Unknown schedule failure";
    return false;
  }
}

std::string ReminderDiagnosticError() { return last_reminder_error; }

bool CancelScheduledToastNotification(const std::string& id) {
  try {
    using namespace winrt::Windows::UI::Notifications;
    const std::wstring wideId = Utf16FromUtf8(id);

    auto notifier = ToastNotificationManager::CreateToastNotifier(kAppUserModelId);
    auto scheduledList = notifier.GetScheduledToastNotifications();
    for (auto const& item : scheduledList) {
      if (item.Id() == wideId) {
        notifier.RemoveFromSchedule(item);
        return true;
      }
    }
    return true;
  } catch (...) {
    return false;
  }
}

bool ShowImmediateToast(const std::string& id,
                        const std::string& noteId,
                        const std::string& title,
                        const std::string& body,
                        int64_t occurrenceEpochMs) {
  last_reminder_error.clear();
  try {
    using namespace winrt::Windows::Data::Xml::Dom;
    using namespace winrt::Windows::UI::Notifications;

    const std::wstring wideNoteId = Utf16FromUtf8(noteId);
    const std::wstring wideTitle = EscapeXml(Utf16FromUtf8(title.empty() ? "Nex (Overdue)" : title));
    const std::wstring wideBody = EscapeXml(Utf16FromUtf8(body));

    std::wstring xml =
        L"<toast activationType=\"protocol\" launch=\"nex-win://note/" + EscapeXml(wideNoteId) + L"\">"
        L"<visual><binding template=\"ToastGeneric\">"
        L"<text>" + wideTitle + L"</text>"
        L"<text>" + wideBody + L"</text>"
        L"</binding></visual>"
        L"<actions>"
        L"<action content=\"\" arguments=\"dismiss\" activationType=\"system\"/>"
        L"</actions></toast>";

    XmlDocument doc;
    doc.LoadXml(xml);

    ToastNotification toast(doc);
    const std::wstring tag = OccurrenceTag(Utf16FromUtf8(id), occurrenceEpochMs);
    if (!tag.empty()) {
      if (occurrenceEpochMs > 0 && AlreadyDelivered(tag)) return true;
      toast.Tag(tag);
    }

    auto notifier = ToastNotificationManager::CreateToastNotifier(kAppUserModelId);
    if (!NotificationsEnabledOrUnknown(notifier)) {
      last_reminder_error = "NotificationSetting=" +
          std::to_string(static_cast<int>(notifier.Setting()));
      return false;
    }
    notifier.Show(toast);
    return true;
  } catch (const winrt::hresult_error& error) {
    last_reminder_error = "show: " +
        std::to_string(static_cast<int32_t>(error.code())) + ": " +
        PanelUtf8FromUtf16(error.message().c_str());
    return false;
  } catch (...) {
    last_reminder_error = "Unknown show failure";
    return false;
  }
}

std::vector<std::string> ListScheduledToastIds() {
  std::vector<std::string> out;
  try {
    using namespace winrt::Windows::UI::Notifications;
    auto notifier = ToastNotificationManager::CreateToastNotifier(kAppUserModelId);
    auto scheduledList = notifier.GetScheduledToastNotifications();
    for (auto const& item : scheduledList) {
      out.push_back(PanelUtf8FromUtf16(item.Id().c_str()));
    }
  } catch (...) {
    // If winrt fails (e.g. notifications disabled or mock environment), return empty
  }
  return out;
}

std::vector<std::pair<std::string, int64_t>> ListScheduledToastDetails() {
  std::vector<std::pair<std::string, int64_t>> out;
  try {
    using namespace winrt::Windows::UI::Notifications;
    auto notifier = ToastNotificationManager::CreateToastNotifier(kAppUserModelId);
    for (auto const& item : notifier.GetScheduledToastNotifications()) {
      const auto at = item.DeliveryTime();
      const int64_t epoch_ms = winrt::clock::to_time_t(at) * 1000LL +
          std::chrono::duration_cast<std::chrono::milliseconds>(at.time_since_epoch()).count() % 1000;
      out.emplace_back(PanelUtf8FromUtf16(item.Id().c_str()), epoch_ms);
    }
  } catch (...) {}
  return out;
}
