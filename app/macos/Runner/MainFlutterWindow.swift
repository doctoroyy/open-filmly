import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Transparent, full-height title bar so the Flutter sidebar can extend to
    // the very top of the window for a native, premium macOS look. The traffic
    // lights stay visible and the content draws underneath them.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    // Force light vibrancy appearance so that even if the host macOS system
    // is in dark mode, the window and its visual effect view render as a
    // premium, translucent light/vibrant sidebar, matching NetEase 爆米花.
    self.appearance = NSAppearance(named: .vibrantLight)

    // Add native visual effect view (frosted glass vibrancy background)
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = .sidebar
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    if let contentView = self.contentView {
      visualEffectView.frame = contentView.bounds
      visualEffectView.autoresizingMask = [.width, .height]
      contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
    }

    // Set a standard premium desktop size (1280x800) to ensure all inputs and buttons are within bounds
    var frame = self.frame
    frame.size = CGSize(width: 1280, height: 800)
    self.setFrame(frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
