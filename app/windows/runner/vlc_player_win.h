#ifndef RUNNER_VLC_PLAYER_WIN_H_
#define RUNNER_VLC_PLAYER_WIN_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

#include <memory>

class VlcPlayerWin {
 public:
  VlcPlayerWin(const VlcPlayerWin&) = delete;
  VlcPlayerWin& operator=(const VlcPlayerWin&) = delete;
  virtual ~VlcPlayerWin() = default;

 protected:
  VlcPlayerWin() = default;
};

std::unique_ptr<VlcPlayerWin> RegisterVlcPlayerWin(
    flutter::BinaryMessenger* messenger,
    HWND parent_window);

#endif  // RUNNER_VLC_PLAYER_WIN_H_
