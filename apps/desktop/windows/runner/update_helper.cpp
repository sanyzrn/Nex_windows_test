// A standalone helper, copied outside the installation before it is run.
// No Flutter or plugin DLL is loaded; the installer can replace the full app.
#include <windows.h>
#include <bcrypt.h>
#include <shellapi.h>

#include <algorithm>
#include <array>
#include <cwctype>
#include <string>
#include <vector>

namespace {
struct Handle {
  HANDLE value = INVALID_HANDLE_VALUE;
  explicit Handle(HANDLE h) : value(h) {}
  ~Handle() { if (value != nullptr && value != INVALID_HANDLE_VALUE) CloseHandle(value); }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
};

bool IsHash(const std::wstring& hash) {
  return hash.size() == 64 && std::all_of(hash.begin(), hash.end(), [](wchar_t c) {
    return (c >= L'0' && c <= L'9') || (c >= L'a' && c <= L'f');
  });
}

bool Verify(HANDLE file, const std::wstring& expected) {
  if (file == INVALID_HANDLE_VALUE || !IsHash(expected)) return false;
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file, &size) || size.QuadPart < 2 || size.QuadPart > 256LL * 1024 * 1024) return false;
  LARGE_INTEGER zero{};
  if (!SetFilePointerEx(file, zero, nullptr, FILE_BEGIN)) return false;
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  bool valid = false;
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0) return false;
  if (BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) >= 0) {
    std::array<UCHAR, 65536> buffer{};
    DWORD count = 0;
    bool first = true, ok = true;
    for (;;) {
      if (!ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &count, nullptr)) { ok = false; break; }
      if (count == 0) break;
      if (first && (count < 2 || buffer[0] != 'M' || buffer[1] != 'Z')) { ok = false; break; }
      first = false;
      if (BCryptHashData(hash, buffer.data(), count, 0) < 0) { ok = false; break; }
    }
    std::array<UCHAR, 32> digest{};
    if (ok && !first && BCryptFinishHash(hash, digest.data(), static_cast<ULONG>(digest.size()), 0) >= 0) {
      const wchar_t hex[] = L"0123456789abcdef";
      std::wstring actual;
      for (const auto byte : digest) { actual += hex[byte >> 4]; actual += hex[byte & 15]; }
      valid = actual == expected;
    }
    BCryptDestroyHash(hash);
  }
  BCryptCloseAlgorithmProvider(algorithm, 0);
  return valid;
}

bool Write(const std::wstring& path, const std::string& text) {
  const auto temporary = path + L".tmp";
  {
    Handle file(CreateFileW(temporary.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr));
    if (file.value == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    if (!WriteFile(file.value, text.data(), static_cast<DWORD>(text.size()), &written, nullptr) || written != text.size()) return false;
    if (!FlushFileBuffers(file.value)) return false;
  }
  return MoveFileExW(temporary.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != FALSE;
}

// Every path is passed through the Windows command-line quoting algorithm.
std::wstring Quote(const std::wstring& text) {
  std::wstring result = L"\"";
  size_t slashes = 0;
  for (const auto c : text) {
    if (c == L'\\') { slashes++; continue; }
    if (c == L'\"') result.append(slashes * 2 + 1, L'\\');
    else result.append(slashes, L'\\');
    slashes = 0;
    result += c;
  }
  result.append(slashes * 2, L'\\');
  return result + L"\"";
}

bool Launch(const std::wstring& exe, const std::wstring& arguments,
            const std::wstring& directory, bool wait, DWORD* exit_code) {
  std::wstring command = Quote(exe) + L" " + arguments;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(exe.c_str(), command.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, directory.c_str(), &startup, &process)) return false;
  Handle thread(process.hThread), child(process.hProcess);
  if (wait) {
    if (WaitForSingleObject(child.value, INFINITE) != WAIT_OBJECT_0) return false;
    if (!GetExitCodeProcess(child.value, exit_code)) return false;
  }
  return true;
}

int Apply(const std::vector<std::wstring>& args) {
  // --apply-update <parent pid> <installer> <sha256> <installed exe> <nonce> <language>
  if (args.size() != 7 || !IsHash(args[3]) || args[5].size() != 36 ||
      (args[6] != L"english" && args[6] != L"farsi")) return 2;
  if (!std::all_of(args[1].begin(), args[1].end(), [](wchar_t c) { return c >= L'0' && c <= L'9'; })) return 2;
  wchar_t* end = nullptr;
  const auto process_id = wcstoul(args[1].c_str(), &end, 10);
  if (process_id == 0 || end == nullptr || *end != L'\0') return 2;
  const auto& setup = args[2];
  const auto& target = args[4];
  if (target.size() < 16 || target.substr(target.size() - 15) != L"nex_desktop.exe" ||
      setup.size() < 4 || setup.substr(setup.size() - 4) != L".exe") return 2;
  const auto split = target.find_last_of(L"\\/");
  if (split == std::wstring::npos) return 2;
  const auto directory = target.substr(0, split);
  Handle parent(OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id));
  if (parent.value == nullptr) return 3;
  std::wstring image(32768, L'\0');
  DWORD image_size = static_cast<DWORD>(image.size());
  if (!QueryFullProcessImageNameW(parent.value, 0, image.data(), &image_size)) return 3;
  image.resize(image_size);
  if (_wcsicmp(image.c_str(), target.c_str()) != 0) return 3;
  // Deny modification/deletion for the entire hash/wait/start handoff.
  Handle file(CreateFileW(setup.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                          OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
  if (!Verify(file.value, args[3])) return 4;
  const auto ready = setup + L".ready";
  const std::string nonce(args[5].begin(), args[5].end());
  if (!Write(ready, nonce)) return 5;
  // A failed save keeps Nex running. Nothing is installed until it has exited.
  if (WaitForSingleObject(parent.value, 120000) != WAIT_OBJECT_0) return 6;
  if (!Verify(file.value, args[3])) return 4;
  DWORD result = 1;
  const auto command = L"/SILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /NEXUPDATE=1 " +
      Quote(L"/DIR=" + directory) + L" " + Quote(L"/LANG=" + args[6]) +
      L" " + Quote(L"/LOG=" + setup + L".log");
  const bool launched = Launch(setup, command, directory, true, &result);
  if (!launched) result = 1;
  Write(setup + L".result", std::to_string(result));
  // On install failure the existing app remains usable and can offer Retry.
  DWORD ignored = 0;
  Launch(target, L"", directory, false, &ignored);
  return launched && (result == 0 || result == 3010) ? 0 : 7;
}
}  // namespace

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, wchar_t*, int) {
  int argc = 0;
  auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv == nullptr) return 2;
  std::vector<std::wstring> args;
  for (int i = 1; i < argc; i++) args.emplace_back(argv[i]);
  LocalFree(argv);
  if (args.size() == 3 && args[0] == L"--verify-update") {
    Handle file(CreateFileW(args[1].c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
    return Verify(file.value, args[2]) ? 0 : 4;
  }
  if (!args.empty() && args[0] == L"--apply-update") return Apply(args);
  return 2;
}
