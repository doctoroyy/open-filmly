#include "vlc_player_win.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <windows.h>

#include <cctype>
#include <cstdint>
#include <cstdio>
#include <map>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {

struct libvlc_instance_t;
struct libvlc_media_t;
struct libvlc_media_player_t;

struct libvlc_track_description_t {
  int i_id;
  char* psz_name;
  libvlc_track_description_t* p_next;
};

using LibVlcNew = libvlc_instance_t* (__cdecl*)(int, const char* const*);
using LibVlcRelease = void(__cdecl*)(libvlc_instance_t*);
using LibVlcMediaNewLocation =
    libvlc_media_t* (__cdecl*)(libvlc_instance_t*, const char*);
using LibVlcMediaNewPath =
    libvlc_media_t* (__cdecl*)(libvlc_instance_t*, const char*);
using LibVlcMediaAddOption = void(__cdecl*)(libvlc_media_t*, const char*);
using LibVlcMediaRelease = void(__cdecl*)(libvlc_media_t*);
using LibVlcMediaPlayerNewFromMedia =
    libvlc_media_player_t* (__cdecl*)(libvlc_media_t*);
using LibVlcMediaPlayerRelease = void(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerSetHwnd =
    void(__cdecl*)(libvlc_media_player_t*, void*);
using LibVlcMediaPlayerPlay = int(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerPause = void(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerStop = void(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerIsPlaying = int(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerGetTime = int64_t(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerSetTime =
    void(__cdecl*)(libvlc_media_player_t*, int64_t);
using LibVlcMediaPlayerGetLength = int64_t(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerGetState = int(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerGetRate = float(__cdecl*)(libvlc_media_player_t*);
using LibVlcMediaPlayerSetRate =
    int(__cdecl*)(libvlc_media_player_t*, float);
using LibVlcAudioGetVolume = int(__cdecl*)(libvlc_media_player_t*);
using LibVlcAudioSetVolume = int(__cdecl*)(libvlc_media_player_t*, int);
using LibVlcAudioGetTrack = int(__cdecl*)(libvlc_media_player_t*);
using LibVlcAudioSetTrack = int(__cdecl*)(libvlc_media_player_t*, int);
using LibVlcAudioGetTrackDescription =
    libvlc_track_description_t* (__cdecl*)(libvlc_media_player_t*);
using LibVlcVideoGetSpu = int(__cdecl*)(libvlc_media_player_t*);
using LibVlcVideoSetSpu = int(__cdecl*)(libvlc_media_player_t*, int);
using LibVlcVideoGetSpuDescription =
    libvlc_track_description_t* (__cdecl*)(libvlc_media_player_t*);
using LibVlcTrackDescriptionListRelease =
    void(__cdecl*)(libvlc_track_description_t*);

constexpr int kLibVlcEndedState = 6;
constexpr int kDefaultViewId = 1;
constexpr const wchar_t kVlcVideoWindowClass[] =
    L"OpenFilmlyVlcVideoWindow";

using EncodableMap = flutter::EncodableMap;
using EncodableValue = flutter::EncodableValue;
using MethodChannel = flutter::MethodChannel<EncodableValue>;
using MethodResult = flutter::MethodResult<EncodableValue>;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(), size,
                      nullptr, nullptr);
  return result;
}

std::wstring GetExecutableDirectory() {
  std::wstring buffer(MAX_PATH, L'\0');
  DWORD length = GetModuleFileNameW(nullptr, buffer.data(),
                                    static_cast<DWORD>(buffer.size()));
  while (length == buffer.size()) {
    buffer.resize(buffer.size() * 2);
    length = GetModuleFileNameW(nullptr, buffer.data(),
                                static_cast<DWORD>(buffer.size()));
  }
  if (length == 0) {
    return std::wstring();
  }
  buffer.resize(length);
  const size_t slash = buffer.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return std::wstring();
  }
  return buffer.substr(0, slash);
}

std::wstring ParentDirectory(const std::wstring& path) {
  const size_t slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return std::wstring();
  }
  return path.substr(0, slash);
}

bool FileExists(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

bool DirectoryExists(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

bool IsUrl(const std::string& value) {
  return value.rfind("http://", 0) == 0 || value.rfind("https://", 0) == 0 ||
         value.rfind("file://", 0) == 0;
}

bool IsUnreservedUrlByte(unsigned char value) {
  return (value >= 'A' && value <= 'Z') || (value >= 'a' && value <= 'z') ||
         (value >= '0' && value <= '9') || value == '-' || value == '.' ||
         value == '_' || value == '~';
}

std::string PercentEncodeFileUrlPath(const std::string& value) {
  std::string result;
  result.reserve(value.size());
  for (const unsigned char ch : value) {
    if (IsUnreservedUrlByte(ch) || ch == '/' || ch == ':') {
      result.push_back(static_cast<char>(ch));
    } else {
      char encoded[4] = {};
      std::snprintf(encoded, sizeof(encoded), "%%%02X", ch);
      result.append(encoded);
    }
  }
  return result;
}

std::wstring NormalizeWindowsPathForFileUrl(const std::wstring& path) {
  if (path.rfind(L"\\\\?\\UNC\\", 0) == 0) {
    return L"\\\\" + path.substr(8);
  }
  if (path.rfind(L"\\\\?\\", 0) == 0) {
    return path.substr(4);
  }
  return path;
}

std::wstring AbsoluteWindowsPath(const std::wstring& path) {
  if (path.empty()) {
    return path;
  }
  const DWORD required =
      GetFullPathNameW(path.c_str(), 0, nullptr, nullptr);
  if (required == 0) {
    return path;
  }
  std::wstring result(static_cast<size_t>(required), L'\0');
  const DWORD length = GetFullPathNameW(
      path.c_str(), required, result.data(), nullptr);
  if (length == 0 || length >= required) {
    return path;
  }
  result.resize(length);
  return result;
}

std::string FileUrlFromPath(const std::string& path) {
  std::wstring wide_path = NormalizeWindowsPathForFileUrl(
      AbsoluteWindowsPath(Utf8ToWide(path)));
  for (wchar_t& ch : wide_path) {
    if (ch == L'\\') {
      ch = L'/';
    }
  }

  const std::string encoded_path =
      PercentEncodeFileUrlPath(WideToUtf8(wide_path));
  if (encoded_path.rfind("//", 0) == 0) {
    return "file:" + encoded_path;
  }
  if (encoded_path.rfind("/", 0) == 0) {
    return "file://" + encoded_path;
  }
  return "file:///" + encoded_path;
}

const EncodableMap* GetArguments(
    const flutter::MethodCall<EncodableValue>& call) {
  const EncodableValue* arguments = call.arguments();
  if (!arguments) {
    return nullptr;
  }
  return std::get_if<EncodableMap>(arguments);
}

std::optional<int64_t> GetInt(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(std::string(key)));
  if (it == map.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return static_cast<int64_t>(*value);
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<double>(&it->second)) {
    return static_cast<int64_t>(*value);
  }
  return std::nullopt;
}

std::optional<double> GetDouble(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(std::string(key)));
  if (it == map.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<double>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  return std::nullopt;
}

std::optional<std::string> GetString(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(std::string(key)));
  if (it == map.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return std::nullopt;
}

EncodableMap GetStringMap(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(std::string(key)));
  if (it == map.end()) {
    return EncodableMap();
  }
  if (const auto* value = std::get_if<EncodableMap>(&it->second)) {
    return *value;
  }
  return EncodableMap();
}

std::string ToLowerAscii(std::string value) {
  for (char& ch : value) {
    ch = static_cast<char>(::tolower(static_cast<unsigned char>(ch)));
  }
  return value;
}

bool LooksLikePreferredSubtitle(const std::string& name) {
  const std::string lower = ToLowerAscii(name);
  constexpr const char* preferred_words[] = {
      "zh",          "chi", "zho", "chs", "cht", "chinese",
      "simplified",  "traditional", "cn", "sc",  "tc",
  };
  for (const char* word : preferred_words) {
    if (lower.find(word) != std::string::npos) {
      return true;
    }
  }
  return false;
}

class LibVlc {
 public:
  LibVlc() = default;
  ~LibVlc() {
    if (instance_ && release_) {
      release_(instance_);
      instance_ = nullptr;
    }
    if (module_) {
      FreeLibrary(module_);
      module_ = nullptr;
    }
  }

  LibVlc(const LibVlc&) = delete;
  LibVlc& operator=(const LibVlc&) = delete;

  bool EnsureLoaded() {
    if (instance_) {
      return true;
    }
    if (!module_ && !LoadModule()) {
      return false;
    }
    return CreateInstance();
  }

  const std::wstring& last_error() const { return last_error_; }

  libvlc_instance_t* instance() const { return instance_; }
  LibVlcMediaNewLocation media_new_location = nullptr;
  LibVlcMediaNewPath media_new_path = nullptr;
  LibVlcMediaAddOption media_add_option = nullptr;
  LibVlcMediaRelease media_release = nullptr;
  LibVlcMediaPlayerNewFromMedia media_player_new_from_media = nullptr;
  LibVlcMediaPlayerRelease media_player_release = nullptr;
  LibVlcMediaPlayerSetHwnd media_player_set_hwnd = nullptr;
  LibVlcMediaPlayerPlay media_player_play = nullptr;
  LibVlcMediaPlayerPause media_player_pause = nullptr;
  LibVlcMediaPlayerStop media_player_stop = nullptr;
  LibVlcMediaPlayerIsPlaying media_player_is_playing = nullptr;
  LibVlcMediaPlayerGetTime media_player_get_time = nullptr;
  LibVlcMediaPlayerSetTime media_player_set_time = nullptr;
  LibVlcMediaPlayerGetLength media_player_get_length = nullptr;
  LibVlcMediaPlayerGetState media_player_get_state = nullptr;
  LibVlcMediaPlayerGetRate media_player_get_rate = nullptr;
  LibVlcMediaPlayerSetRate media_player_set_rate = nullptr;
  LibVlcAudioGetVolume audio_get_volume = nullptr;
  LibVlcAudioSetVolume audio_set_volume = nullptr;
  LibVlcAudioGetTrack audio_get_track = nullptr;
  LibVlcAudioSetTrack audio_set_track = nullptr;
  LibVlcAudioGetTrackDescription audio_get_track_description = nullptr;
  LibVlcVideoGetSpu video_get_spu = nullptr;
  LibVlcVideoSetSpu video_set_spu = nullptr;
  LibVlcVideoGetSpuDescription video_get_spu_description = nullptr;
  LibVlcTrackDescriptionListRelease track_description_list_release = nullptr;

 private:
  template <typename T>
  bool LoadFunction(T* target, const char* name) {
    FARPROC proc = GetProcAddress(module_, name);
    if (!proc) {
      std::wstring message = L"Missing libVLC symbol: ";
      message += Utf8ToWide(name);
      last_error_ = message;
      return false;
    }
    *target = reinterpret_cast<T>(proc);
    return true;
  }

  bool LoadModule() {
    const std::wstring exe_dir = GetExecutableDirectory();
    std::vector<std::wstring> candidates;
    if (!exe_dir.empty()) {
      candidates.push_back(exe_dir + L"\\vlc\\libvlc.dll");
      candidates.push_back(exe_dir + L"\\libvlc.dll");
    }
    candidates.push_back(L"C:\\Program Files\\VideoLAN\\VLC\\libvlc.dll");
    candidates.push_back(L"C:\\Program Files (x86)\\VideoLAN\\VLC\\libvlc.dll");
    candidates.push_back(L"libvlc.dll");

    for (const std::wstring& candidate : candidates) {
      if (candidate != L"libvlc.dll" && !FileExists(candidate)) {
        continue;
      }
      module_ = LoadLibraryW(candidate.c_str());
      if (!module_) {
        continue;
      }
      module_path_ = candidate;
      if (LoadFunctions()) {
        return true;
      }
      FreeLibrary(module_);
      module_ = nullptr;
    }

    last_error_ =
        L"Could not load libvlc.dll. Install VLC for Windows or place "
        L"libvlc.dll and the plugins directory under app\\vlc next to "
        L"open_filmly.exe.";
    return false;
  }

  bool LoadFunctions() {
    return LoadFunction(&new_, "libvlc_new") &&
           LoadFunction(&release_, "libvlc_release") &&
           LoadFunction(&media_new_location, "libvlc_media_new_location") &&
           LoadFunction(&media_new_path, "libvlc_media_new_path") &&
           LoadFunction(&media_add_option, "libvlc_media_add_option") &&
           LoadFunction(&media_release, "libvlc_media_release") &&
           LoadFunction(&media_player_new_from_media,
                        "libvlc_media_player_new_from_media") &&
           LoadFunction(&media_player_release, "libvlc_media_player_release") &&
           LoadFunction(&media_player_set_hwnd,
                        "libvlc_media_player_set_hwnd") &&
           LoadFunction(&media_player_play, "libvlc_media_player_play") &&
           LoadFunction(&media_player_pause, "libvlc_media_player_pause") &&
           LoadFunction(&media_player_stop, "libvlc_media_player_stop") &&
           LoadFunction(&media_player_is_playing,
                        "libvlc_media_player_is_playing") &&
           LoadFunction(&media_player_get_time, "libvlc_media_player_get_time") &&
           LoadFunction(&media_player_set_time, "libvlc_media_player_set_time") &&
           LoadFunction(&media_player_get_length,
                        "libvlc_media_player_get_length") &&
           LoadFunction(&media_player_get_state,
                        "libvlc_media_player_get_state") &&
           LoadFunction(&media_player_get_rate, "libvlc_media_player_get_rate") &&
           LoadFunction(&media_player_set_rate, "libvlc_media_player_set_rate") &&
           LoadFunction(&audio_get_volume, "libvlc_audio_get_volume") &&
           LoadFunction(&audio_set_volume, "libvlc_audio_set_volume") &&
           LoadFunction(&audio_get_track, "libvlc_audio_get_track") &&
           LoadFunction(&audio_set_track, "libvlc_audio_set_track") &&
           LoadFunction(&audio_get_track_description,
                        "libvlc_audio_get_track_description") &&
           LoadFunction(&video_get_spu, "libvlc_video_get_spu") &&
           LoadFunction(&video_set_spu, "libvlc_video_set_spu") &&
           LoadFunction(&video_get_spu_description,
                        "libvlc_video_get_spu_description") &&
           LoadFunction(&track_description_list_release,
                        "libvlc_track_description_list_release");
  }

  bool CreateInstance() {
    std::vector<std::string> arg_storage;
    arg_storage.push_back("--no-video-title-show");
    arg_storage.push_back("--quiet");

    const std::wstring module_dir = ParentDirectory(module_path_);
    const std::wstring plugins_dir = module_dir + L"\\plugins";
    if (DirectoryExists(plugins_dir)) {
      arg_storage.push_back("--plugin-path=" + WideToUtf8(plugins_dir));
    }

    std::vector<const char*> args;
    args.reserve(arg_storage.size());
    for (const std::string& arg : arg_storage) {
      args.push_back(arg.c_str());
    }

    instance_ = new_(static_cast<int>(args.size()), args.data());
    if (!instance_) {
      last_error_ = L"libvlc_new returned null.";
      return false;
    }
    return true;
  }

  HMODULE module_ = nullptr;
  std::wstring module_path_;
  std::wstring last_error_;
  libvlc_instance_t* instance_ = nullptr;
  LibVlcNew new_ = nullptr;
  LibVlcRelease release_ = nullptr;
};

class WindowFullscreenController {
 public:
  explicit WindowFullscreenController(HWND window) : window_(window) {}

  void ToggleFullscreen() {
    if (!window_) {
      return;
    }
    if (!fullscreen_) {
      EnterFullscreen();
    } else {
      ExitFullscreen();
    }
  }

  void Maximize() {
    if (window_) {
      ShowWindow(window_, SW_MAXIMIZE);
    }
  }

 private:
  void EnterFullscreen() {
    previous_style_ = GetWindowLongPtrW(window_, GWL_STYLE);
    previous_ex_style_ = GetWindowLongPtrW(window_, GWL_EXSTYLE);
    previous_placement_.length = sizeof(previous_placement_);
    GetWindowPlacement(window_, &previous_placement_);

    HMONITOR monitor = MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
    MONITORINFO monitor_info{};
    monitor_info.cbSize = sizeof(monitor_info);
    if (!GetMonitorInfoW(monitor, &monitor_info)) {
      return;
    }

    SetWindowLongPtrW(window_, GWL_STYLE,
                      previous_style_ & ~static_cast<LONG_PTR>(WS_OVERLAPPEDWINDOW));
    SetWindowLongPtrW(window_, GWL_EXSTYLE,
                      previous_ex_style_ & ~static_cast<LONG_PTR>(WS_EX_DLGMODALFRAME));
    SetWindowPos(window_, HWND_TOP, monitor_info.rcMonitor.left,
                 monitor_info.rcMonitor.top,
                 monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
                 monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    fullscreen_ = true;
  }

  void ExitFullscreen() {
    SetWindowLongPtrW(window_, GWL_STYLE, previous_style_);
    SetWindowLongPtrW(window_, GWL_EXSTYLE, previous_ex_style_);
    SetWindowPlacement(window_, &previous_placement_);
    SetWindowPos(window_, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    fullscreen_ = false;
  }

  HWND window_ = nullptr;
  bool fullscreen_ = false;
  LONG_PTR previous_style_ = 0;
  LONG_PTR previous_ex_style_ = 0;
  WINDOWPLACEMENT previous_placement_{sizeof(WINDOWPLACEMENT)};
};

class VlcPlayerView {
 public:
  VlcPlayerView(int64_t view_id,
                HWND parent_window,
                LibVlc* vlc,
                MethodChannel* channel)
      : view_id_(view_id),
        parent_window_(parent_window),
        vlc_(vlc),
        channel_(channel) {
    EnsureWindowClass();
    video_window_ = CreateWindowExW(
        0, kVlcVideoWindowClass, nullptr,
        WS_CHILD | WS_CLIPSIBLINGS | WS_CLIPCHILDREN, 0, 0, 1, 1,
        parent_window_, nullptr, GetModuleHandleW(nullptr), this);
    if (video_window_) {
      ShowWindow(video_window_, SW_HIDE);
    }
  }

  ~VlcPlayerView() {
    StopAndReleasePlayer();
    if (video_window_) {
      DestroyWindow(video_window_);
      video_window_ = nullptr;
    }
  }

  VlcPlayerView(const VlcPlayerView&) = delete;
  VlcPlayerView& operator=(const VlcPlayerView&) = delete;

  bool Open(const std::string& uri,
            const EncodableMap& http_headers,
            int64_t start_ms,
            std::wstring* error) {
    if (!vlc_->EnsureLoaded()) {
      *error = vlc_->last_error();
      return false;
    }
    if (!video_window_) {
      *error = L"VLC video window is not available.";
      return false;
    }

    StopAndReleasePlayer();
    did_select_preferred_subtitle_ = false;

    const std::string location = IsUrl(uri) ? uri : FileUrlFromPath(uri);
    libvlc_media_t* media =
        vlc_->media_new_location(vlc_->instance(), location.c_str());
    if (!media) {
      *error = L"Could not create VLC media.";
      return false;
    }

    AddOption(media, ":network-caching=3000");
    AddOption(media, ":file-caching=1500");
    AddOption(media, ":live-caching=3000");
    AddOption(media, ":sub-autodetect-file");
    AddOption(media, ":subsdec-encoding=UTF-8");

    for (const auto& entry : http_headers) {
      const auto* key = std::get_if<std::string>(&entry.first);
      const auto* value = std::get_if<std::string>(&entry.second);
      if (!key || !value) {
        continue;
      }
      std::string lower_key = *key;
      for (char& ch : lower_key) {
        ch = static_cast<char>(::tolower(static_cast<unsigned char>(ch)));
      }
      if (lower_key == "user-agent") {
        AddOption(media, ":http-user-agent=" + *value);
      } else {
        AddOption(media, ":http-header=" + *key + ": " + *value);
      }
    }

    if (start_ms > 0) {
      std::ostringstream option;
      option << ":start-time=" << (static_cast<double>(start_ms) / 1000.0);
      AddOption(media, option.str());
    }

    player_ = vlc_->media_player_new_from_media(media);
    vlc_->media_release(media);
    if (!player_) {
      *error = L"Could not create VLC media player.";
      return false;
    }

    vlc_->media_player_set_hwnd(player_, video_window_);
    const int play_result = vlc_->media_player_play(player_);
    if (play_result != 0) {
      *error = L"VLC failed to start playback.";
      return false;
    }
    if (start_ms > 0) {
      vlc_->media_player_set_time(player_, start_ms);
    }
    return true;
  }

  void PlayOrPause() {
    if (!player_) {
      return;
    }
    if (vlc_->media_player_is_playing(player_) != 0) {
      vlc_->media_player_pause(player_);
    } else {
      vlc_->media_player_play(player_);
    }
  }

  void Seek(int64_t position_ms) {
    if (player_) {
      vlc_->media_player_set_time(player_,
                                  position_ms < 0 ? 0 : position_ms);
    }
  }

  void SetVolume(int volume) {
    if (player_) {
      const int clamped = volume < 0 ? 0 : (volume > 100 ? 100 : volume);
      vlc_->audio_set_volume(player_, clamped);
    }
  }

  void SetRate(double rate) {
    if (player_) {
      const double clamped = rate < 0.25 ? 0.25 : (rate > 4.0 ? 4.0 : rate);
      vlc_->media_player_set_rate(player_, static_cast<float>(clamped));
    }
  }

  void SetAudioTrack(int id) {
    if (player_) {
      vlc_->audio_set_track(player_, id);
    }
  }

  void SetSubtitleTrack(int id) {
    if (player_) {
      did_select_preferred_subtitle_ = true;
      vlc_->video_set_spu(player_, id);
    }
  }

  EncodableMap Status() {
    EncodableMap status;
    status[EncodableValue("positionMs")] =
        EncodableValue(static_cast<int64_t>(
            player_ ? vlc_->media_player_get_time(player_) : 0));
    status[EncodableValue("durationMs")] =
        EncodableValue(static_cast<int64_t>(
            player_ ? vlc_->media_player_get_length(player_) : 0));
    status[EncodableValue("playing")] =
        EncodableValue(player_ && vlc_->media_player_is_playing(player_) != 0);
    status[EncodableValue("completed")] =
        EncodableValue(player_ &&
                       vlc_->media_player_get_state(player_) ==
                           kLibVlcEndedState);
    status[EncodableValue("volume")] =
        EncodableValue(static_cast<int32_t>(
            player_ ? vlc_->audio_get_volume(player_) : 100));
    status[EncodableValue("rate")] =
        EncodableValue(static_cast<double>(
            player_ ? vlc_->media_player_get_rate(player_) : 1.0));
    return status;
  }

  EncodableMap Tracks() {
    SelectPreferredSubtitleIfNeeded();

    EncodableMap tracks;
    tracks[EncodableValue("audio")] =
        EncodableValue(TrackList(player_ ? vlc_->audio_get_track_description(
                                              player_)
                                        : nullptr));
    tracks[EncodableValue("subtitle")] =
        EncodableValue(TrackList(player_ ? vlc_->video_get_spu_description(
                                              player_)
                                        : nullptr));
    tracks[EncodableValue("currentAudio")] =
        EncodableValue(static_cast<int32_t>(
            player_ ? vlc_->audio_get_track(player_) : -1));
    tracks[EncodableValue("currentSubtitle")] =
        EncodableValue(static_cast<int32_t>(
            player_ ? vlc_->video_get_spu(player_) : -1));
    return tracks;
  }

  void SetBounds(int x, int y, int width, int height) {
    if (!video_window_) {
      return;
    }
    if (width <= 1 || height <= 1) {
      ShowWindow(video_window_, SW_HIDE);
      return;
    }
    SetWindowPos(video_window_, HWND_TOP, x, y, width, height,
                 SWP_NOACTIVATE | SWP_SHOWWINDOW);
    InvalidateRect(video_window_, nullptr, TRUE);
  }

  void Dispose() { StopAndReleasePlayer(); }

 private:
  static void EnsureWindowClass() {
    static bool registered = false;
    if (registered) {
      return;
    }
    WNDCLASSW window_class{};
    window_class.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
    window_class.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    window_class.hInstance = GetModuleHandleW(nullptr);
    window_class.lpszClassName = kVlcVideoWindowClass;
    window_class.hbrBackground =
        reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    window_class.lpfnWndProc = &VlcPlayerView::WindowProc;
    RegisterClassW(&window_class);
    registered = true;
  }

  static LRESULT CALLBACK WindowProc(HWND hwnd,
                                     UINT message,
                                     WPARAM wparam,
                                     LPARAM lparam) {
    if (message == WM_NCCREATE) {
      CREATESTRUCTW* create_struct = reinterpret_cast<CREATESTRUCTW*>(lparam);
      SetWindowLongPtrW(
          hwnd, GWLP_USERDATA,
          reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams));
    }
    VlcPlayerView* view = reinterpret_cast<VlcPlayerView*>(
        GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (!view) {
      return DefWindowProcW(hwnd, message, wparam, lparam);
    }
    return view->HandleWindowMessage(hwnd, message, wparam, lparam);
  }

  LRESULT HandleWindowMessage(HWND hwnd,
                              UINT message,
                              WPARAM wparam,
                              LPARAM lparam) {
    switch (message) {
      case WM_LBUTTONDOWN:
        SendVideoEvent("videoTap");
        return 0;
      case WM_LBUTTONDBLCLK:
        SendVideoEvent("videoDoubleClick");
        return 0;
      case WM_ERASEBKGND:
        return 1;
      case WM_PAINT: {
        PAINTSTRUCT paint_struct;
        HDC dc = BeginPaint(hwnd, &paint_struct);
        RECT rect;
        GetClientRect(hwnd, &rect);
        FillRect(dc, &rect, reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));
        EndPaint(hwnd, &paint_struct);
        return 0;
      }
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
  }

  void SendVideoEvent(const std::string& method) {
    if (!channel_) {
      return;
    }
    EncodableMap args;
    args[EncodableValue("viewId")] = EncodableValue(view_id_);
    channel_->InvokeMethod(method, std::make_unique<EncodableValue>(args));
  }

  void AddOption(libvlc_media_t* media, const std::string& option) {
    if (media && vlc_->media_add_option) {
      vlc_->media_add_option(media, option.c_str());
    }
  }

  void SelectPreferredSubtitleIfNeeded() {
    if (!player_ || did_select_preferred_subtitle_) {
      return;
    }

    libvlc_track_description_t* head =
        vlc_->video_get_spu_description(player_);
    int first_subtitle_id = -1;
    int preferred_subtitle_id = -1;
    for (libvlc_track_description_t* item = head; item;
         item = item->p_next) {
      if (item->i_id < 0) {
        continue;
      }
      if (first_subtitle_id < 0) {
        first_subtitle_id = item->i_id;
      }
      if (preferred_subtitle_id < 0 && item->psz_name &&
          LooksLikePreferredSubtitle(item->psz_name)) {
        preferred_subtitle_id = item->i_id;
      }
    }
    if (head && vlc_->track_description_list_release) {
      vlc_->track_description_list_release(head);
    }

    const int current_subtitle_id = vlc_->video_get_spu(player_);
    const int subtitle_id =
        preferred_subtitle_id >= 0
            ? preferred_subtitle_id
            : (current_subtitle_id < 0 ? first_subtitle_id : -1);
    if (subtitle_id >= 0) {
      vlc_->video_set_spu(player_, subtitle_id);
      did_select_preferred_subtitle_ = true;
    }
  }

  flutter::EncodableList TrackList(libvlc_track_description_t* head) {
    flutter::EncodableList result;
    libvlc_track_description_t* item = head;
    while (item) {
      EncodableMap track;
      track[EncodableValue("id")] = EncodableValue(std::to_string(item->i_id));
      track[EncodableValue("title")] =
          EncodableValue(item->psz_name ? std::string(item->psz_name)
                                        : std::string());
      track[EncodableValue("language")] = EncodableValue(std::string());
      result.push_back(EncodableValue(track));
      item = item->p_next;
    }
    if (head && vlc_->track_description_list_release) {
      vlc_->track_description_list_release(head);
    }
    return result;
  }

  void StopAndReleasePlayer() {
    if (!player_) {
      return;
    }
    vlc_->media_player_stop(player_);
    vlc_->media_player_release(player_);
    player_ = nullptr;
  }

  int64_t view_id_ = kDefaultViewId;
  HWND parent_window_ = nullptr;
  HWND video_window_ = nullptr;
  LibVlc* vlc_ = nullptr;
  MethodChannel* channel_ = nullptr;
  libvlc_media_player_t* player_ = nullptr;
  bool did_select_preferred_subtitle_ = false;
};

class VlcPlayerWinImpl final : public VlcPlayerWin {
 public:
  VlcPlayerWinImpl(flutter::BinaryMessenger* messenger, HWND parent_window)
      : parent_window_(parent_window),
        fullscreen_(parent_window),
        vlc_channel_(std::make_unique<MethodChannel>(
            messenger,
            "com.openfilmly.vlc_player",
            &flutter::StandardMethodCodec::GetInstance())),
        window_channel_(std::make_unique<MethodChannel>(
            messenger,
            "com.openfilmly.window",
            &flutter::StandardMethodCodec::GetInstance())) {
    vlc_channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<EncodableValue>& call,
               std::unique_ptr<MethodResult> result) {
          HandleVlcMethodCall(call, std::move(result));
        });
    window_channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<EncodableValue>& call,
               std::unique_ptr<MethodResult> result) {
          HandleWindowMethodCall(call, std::move(result));
        });
  }

  ~VlcPlayerWinImpl() override {
    if (vlc_channel_) {
      vlc_channel_->SetMethodCallHandler(nullptr);
    }
    if (window_channel_) {
      window_channel_->SetMethodCallHandler(nullptr);
    }
  }

 private:
  VlcPlayerView* GetOrCreateView(int64_t view_id) {
    const auto it = views_.find(view_id);
    if (it != views_.end()) {
      return it->second.get();
    }
    auto view = std::make_unique<VlcPlayerView>(
        view_id, parent_window_, &vlc_, vlc_channel_.get());
    VlcPlayerView* raw = view.get();
    views_[view_id] = std::move(view);
    return raw;
  }

  void HandleVlcMethodCall(const flutter::MethodCall<EncodableValue>& call,
                           std::unique_ptr<MethodResult> result) {
    const EncodableMap* args = GetArguments(call);
    if (!args) {
      result->Error("BAD_ARGS", "Missing VLC method arguments.");
      return;
    }

    const int64_t view_id = GetInt(*args, "viewId").value_or(kDefaultViewId);
    VlcPlayerView* view = GetOrCreateView(view_id);
    const std::string& method = call.method_name();

    if (method == "open") {
      const std::optional<std::string> uri = GetString(*args, "uri");
      if (!uri || uri->empty()) {
        result->Error("BAD_ARGS", "Missing media URI.");
        return;
      }
      std::wstring error;
      const bool ok = view->Open(*uri, GetStringMap(*args, "httpHeaders"),
                                 GetInt(*args, "startMs").value_or(0), &error);
      if (!ok) {
        result->Error("VLC_ERROR", WideToUtf8(error));
        return;
      }
      result->Success();
      return;
    }

    if (method == "playOrPause") {
      view->PlayOrPause();
      result->Success();
    } else if (method == "seek") {
      view->Seek(GetInt(*args, "positionMs").value_or(0));
      result->Success();
    } else if (method == "setVolume") {
      view->SetVolume(static_cast<int>(GetInt(*args, "volume").value_or(100)));
      result->Success();
    } else if (method == "setRate") {
      view->SetRate(GetDouble(*args, "rate").value_or(1.0));
      result->Success();
    } else if (method == "setAudioTrack") {
      view->SetAudioTrack(
          static_cast<int>(GetInt(*args, "trackId").value_or(-1)));
      result->Success();
    } else if (method == "setSubtitleTrack") {
      view->SetSubtitleTrack(
          static_cast<int>(GetInt(*args, "trackId").value_or(-1)));
      result->Success();
    } else if (method == "status") {
      result->Success(EncodableValue(view->Status()));
    } else if (method == "tracks") {
      result->Success(EncodableValue(view->Tracks()));
    } else if (method == "setBounds") {
      view->SetBounds(static_cast<int>(GetInt(*args, "x").value_or(0)),
                      static_cast<int>(GetInt(*args, "y").value_or(0)),
                      static_cast<int>(GetInt(*args, "width").value_or(0)),
                      static_cast<int>(GetInt(*args, "height").value_or(0)));
      result->Success();
    } else if (method == "dispose") {
      view->Dispose();
      views_.erase(view_id);
      result->Success();
    } else {
      result->NotImplemented();
    }
  }

  void HandleWindowMethodCall(const flutter::MethodCall<EncodableValue>& call,
                              std::unique_ptr<MethodResult> result) {
    const std::string& method = call.method_name();
    if (method == "toggleFullScreen") {
      fullscreen_.ToggleFullscreen();
      result->Success();
    } else if (method == "maximize") {
      fullscreen_.Maximize();
      result->Success();
    } else {
      result->NotImplemented();
    }
  }

  HWND parent_window_ = nullptr;
  WindowFullscreenController fullscreen_;
  LibVlc vlc_;
  std::unique_ptr<MethodChannel> vlc_channel_;
  std::unique_ptr<MethodChannel> window_channel_;
  std::map<int64_t, std::unique_ptr<VlcPlayerView>> views_;
};

}  // namespace

std::unique_ptr<VlcPlayerWin> RegisterVlcPlayerWin(
    flutter::BinaryMessenger* messenger,
    HWND parent_window) {
  return std::make_unique<VlcPlayerWinImpl>(messenger, parent_window);
}
