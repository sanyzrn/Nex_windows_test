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

std::wstring EscapeXml(const std::wstring& s) {
  std::wstring out;
  for (wchar_t c : s) {
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
  try {
    using namespace winrt::Windows::Data::Xml::Dom;
    using namespace winrt::Windows::UI::Notifications;
    using namespace winrt::Windows::Foundation;

    const std::wstring wideId = Utf16FromUtf8(id);
    const std::wstring wideNoteId = Utf16FromUtf8(noteId);
    const std::wstring wideTitle = EscapeXml(Utf16FromUtf8(title.empty() ? "Nex Reminder" : title));
    const std::wstring wideBody = EscapeXml(Utf16FromUtf8(body));

    std::wstring xml =
        L"<toast launch=\"action=open&amp;noteId=" + wideNoteId + L"\">"
        L"<visual><binding template=\"ToastGeneric\">"
        L"<text>" + wideTitle + L"</text>"
        L"<text>" + wideBody + L"</text>"
        L"</binding></visual>"
        L"<actions>"
        L"<action content=\"Done\" arguments=\"action=done&amp;noteId=" + wideNoteId + L"\" activationType=\"foreground\"/>"
        L"<action content=\"Snooze 10m\" arguments=\"action=snooze&amp;noteId=" + wideNoteId + L"\" activationType=\"foreground\"/>"
        L"</actions></toast>";

    XmlDocument doc;
    doc.LoadXml(xml);

    auto fireTime = winrt::clock::from_time_t(fireAtEpochMs / 1000);
    // Add remaining milliseconds
    fireTime += std::chrono::milliseconds(fireAtEpochMs % 1000);

    ScheduledToastNotification scheduled(doc, fireTime);
    scheduled.Id(wideId);

    auto notifier = ToastNotificationManager::CreateToastNotifier(kAppUserModelId);
    notifier.AddToSchedule(scheduled);
    return true;
  } catch (...) {
    return false;
  }
}

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
    return false;
  } catch (...) {
    return false;
  }
}

bool ShowImmediateToast(const std::string& id,
                        const std::string& noteId,
                        const std::string& title,
                        const std::string& body) {
  try {
    using namespace winrt::Windows::Data::Xml::Dom;
    using namespace winrt::Windows::UI::Notifications;

    const std::wstring wideNoteId = Utf16FromUtf8(noteId);
    const std::wstring wideTitle = EscapeXml(Utf16FromUtf8(title.empty() ? "Nex (Overdue)" : title));
    const std::wstring wideBody = EscapeXml(Utf16FromUtf8(body));

    std::wstring xml =
        L"<toast launch=\"action=open&amp;noteId=" + wideNoteId + L"\">"
        L"<visual><binding template=\"ToastGeneric\">"
        L"<text>" + wideTitle + L"</text>"
        L"<text>" + wideBody + L"</text>"
        L"</binding></visual>"
        L"<actions>"
        L"<action content=\"Done\" arguments=\"action=done&amp;noteId=" + wideNoteId + L"\" activationType=\"foreground\"/>"
        L"<action content=\"Snooze 10m\" arguments=\"action=snooze&amp;noteId=" + wideNoteId + L"\" activationType=\"foreground\"/>"
        L"</actions></toast>";

    XmlDocument doc;
    doc.LoadXml(xml);

    ToastNotification toast(doc);
    if (!id.empty()) {
      toast.Tag(Utf16FromUtf8(id));
    }

    auto notifier = ToastNotificationManager::CreateToastNotifier(kAppUserModelId);
    notifier.Show(toast);
    return true;
  } catch (...) {
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
