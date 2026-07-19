import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Transparent, full-height title bar so Flutter can draw into the titlebar
    // row (Baomihua-style centered title next to traffic lights).
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    let isPlayer = ProcessInfo.processInfo.arguments.contains {
      $0.hasPrefix("--player-file=")
    }

    if isPlayer {
      // Standalone player window: pure black chrome, no library vibrancy.
      self.appearance = NSAppearance(named: .darkAqua)
      self.backgroundColor = .black
      var frame = self.frame
      frame.size = CGSize(width: 1280, height: 720)
      self.setFrame(frame, display: true)
    } else {
      // Library window: light vibrancy sidebar (爆米花 main UI).
      self.appearance = NSAppearance(named: .vibrantLight)
      let visualEffectView = NSVisualEffectView()
      visualEffectView.material = .sidebar
      visualEffectView.blendingMode = .behindWindow
      visualEffectView.state = .active
      if let contentView = self.contentView {
        visualEffectView.frame = contentView.bounds
        visualEffectView.autoresizingMask = [.width, .height]
        contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
      }
      var frame = self.frame
      frame.size = CGSize(width: 1280, height: 800)
      self.setFrame(frame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
