import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Transparent full-size title bar so Flutter can draw title on the
    // traffic-light row (Baomihua style).
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    // Main library window: light vibrancy sidebar.
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

    RegisterGeneratedPlugins(registry: flutterViewController)
    FilmlyWindowBootstrap.registerChannels(for: flutterViewController)

    // Every secondary window (player) gets its own Flutter engine — register
    // plugins + our VLC / window channels for that engine too.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      FilmlyWindowBootstrap.registerChannels(for: controller)
      // Player windows: black chrome, no library vibrancy.
      if let window = controller.view.window {
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        var f = window.frame
        f.size = CGSize(width: 1100, height: 640)
        window.setFrame(f, display: true)
        window.center()
      }
    }

    super.awakeFromNib()
  }
}

/// Shared bootstrap so the main window and every multi-window engine get
/// the same VLC platform-view factory + window method channel.
enum FilmlyWindowBootstrap {
  static func registerChannels(for controller: FlutterViewController) {
    let registry = VlcPlayerRegistry()
    let messenger = controller.engine.binaryMessenger

    controller.registrar(forPlugin: "OpenFilmlyVlcPlayer").register(
      VlcPlayerViewFactory(registry: registry),
      withId: "open_filmly/vlc_player_view"
    )

    let vlcChannel = FlutterMethodChannel(
      name: "com.openfilmly.vlc_player",
      binaryMessenger: messenger
    )
    vlcChannel.setMethodCallHandler { call, result in
      registry.handle(call: call, result: result)
    }

    let windowChannel = FlutterMethodChannel(
      name: "com.openfilmly.window",
      binaryMessenger: messenger
    )
    windowChannel.setMethodCallHandler { call, result in
      // Always use the key window so the player (secondary) window fullscreens.
      guard let window = NSApp.keyWindow ?? controller.view.window else {
        result(
          FlutterError(
            code: "UNAVAILABLE",
            message: "Window is not available",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "toggleFullScreen":
        window.toggleFullScreen(nil)
        result(nil)
      case "maximize":
        window.zoom(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
