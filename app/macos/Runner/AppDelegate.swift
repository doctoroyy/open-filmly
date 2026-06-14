import Cocoa
import FlutterMacOS
import VLCKit

@main
class AppDelegate: FlutterAppDelegate {
  private let vlcRegistry = VlcPlayerRegistry()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let windowChannel = FlutterMethodChannel(name: "com.openfilmly.window", binaryMessenger: controller.engine.binaryMessenger)
    let vlcChannel = FlutterMethodChannel(name: "com.openfilmly.vlc_player", binaryMessenger: controller.engine.binaryMessenger)

    controller.registrar(forPlugin: "OpenFilmlyVlcPlayer").register(
      VlcPlayerViewFactory(registry: vlcRegistry),
      withId: "open_filmly/vlc_player_view"
    )
    
    windowChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let window = self?.mainFlutterWindow else {
        result(FlutterError(code: "UNAVAILABLE", message: "Window is not available", details: nil))
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

    vlcChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      self?.vlcRegistry.handle(call: call, result: result)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

private final class VlcPlayerRegistry {
  private var views: [Int64: VlcPlayerNativeView] = [:]

  func register(view: VlcPlayerNativeView, id: Int64) {
    views[id] = view
  }

  func unregister(id: Int64) {
    views.removeValue(forKey: id)
  }

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let viewId = int64Value(args["viewId"]) else {
      result(FlutterError(code: "BAD_ARGS", message: "Missing VLC viewId", details: nil))
      return
    }

    guard let view = views[viewId] else {
      result(FlutterError(code: "NOT_FOUND", message: "VLC view is not attached", details: nil))
      return
    }

    switch call.method {
    case "open":
      guard let uri = args["uri"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing media URI", details: nil))
        return
      }
      let headers = args["httpHeaders"] as? [String: String] ?? [:]
      let startMs = intValue(args["startMs"]) ?? 0
      view.open(uri: uri, httpHeaders: headers, startMs: startMs)
      result(nil)
    case "playOrPause":
      view.playOrPause()
      result(nil)
    case "seek":
      view.seek(toMilliseconds: intValue(args["positionMs"]) ?? 0)
      result(nil)
    case "setVolume":
      view.setVolume(intValue(args["volume"]) ?? 100)
      result(nil)
    case "setRate":
      view.setRate(doubleValue(args["rate"]) ?? 1.0)
      result(nil)
    case "setAudioTrack":
      view.setAudioTrack(id: intValue(args["trackId"]) ?? -1)
      result(nil)
    case "setSubtitleTrack":
      view.setSubtitleTrack(id: intValue(args["trackId"]) ?? -1)
      result(nil)
    case "status":
      result(view.status())
    case "tracks":
      result(view.tracks())
    case "dispose":
      view.dispose()
      unregister(id: viewId)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? NSNumber { return value.int64Value }
    if let value = value as? String { return Int64(value) }
    return nil
  }

  private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? Int64 { return Int(value) }
    if let value = value as? NSNumber { return value.intValue }
    if let value = value as? Double { return Int(value) }
    if let value = value as? String { return Int(value) }
    return nil
  }

  private func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Float { return Double(value) }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? String { return Double(value) }
    return nil
  }
}

private final class VlcPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var registry: VlcPlayerRegistry?

  init(registry: VlcPlayerRegistry) {
    self.registry = registry
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    let view = VlcPlayerNativeView(frame: .zero)
    registry?.register(view: view, id: viewId)
    return view
  }

  func createArgsCodec() -> (NSObjectProtocol & FlutterMessageCodec)? {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class VlcPlayerNativeView: NSView, VLCMediaPlayerDelegate {
  private let mediaPlayer = VLCMediaPlayer()
  private var didSelectPreferredSubtitle = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
    let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
    doubleClick.numberOfClicksRequired = 2
    addGestureRecognizer(doubleClick)
    mediaPlayer.delegate = self
    mediaPlayer.drawable = self
    mediaPlayer.audio?.volume = 100
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override var acceptsFirstResponder: Bool { true }

  @objc private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
    guard recognizer.state == .ended else { return }
    window?.toggleFullScreen(nil)
  }

  func open(uri: String, httpHeaders: [String: String], startMs: Int) {
    guard let url = makeURL(from: uri) else { return }

    didSelectPreferredSubtitle = false
    mediaPlayer.stop()

    let media = VLCMedia(url: url)
    media.addOptions([
      "network-caching": 3000,
      "file-caching": 1500,
      "live-caching": 3000,
      "sout-mux-caching": 1500,
      "sub-autodetect-file": true,
      "subsdec-encoding": "UTF-8",
    ])

    for (key, value) in httpHeaders {
      if key.lowercased() == "user-agent" {
        media.addOption(":http-user-agent=\(value)")
      } else {
        media.addOption(":http-header=\(key): \(value)")
      }
    }

    if startMs > 0 {
      media.addOption(":start-time=\(Double(startMs) / 1000.0)")
    }

    mediaPlayer.media = media
    mediaPlayer.play()

    if startMs > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        self?.mediaPlayer.time = VLCTime(int: Int32(startMs))
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.selectPreferredSubtitleIfNeeded()
    }
  }

  func playOrPause() {
    if mediaPlayer.isPlaying {
      mediaPlayer.pause()
    } else {
      mediaPlayer.play()
    }
  }

  func seek(toMilliseconds milliseconds: Int) {
    mediaPlayer.time = VLCTime(int: Int32(max(0, milliseconds)))
  }

  func setVolume(_ volume: Int) {
    mediaPlayer.audio?.volume = Int32(max(0, min(100, volume)))
  }

  func setRate(_ rate: Double) {
    mediaPlayer.rate = Float(max(0.25, min(4.0, rate)))
  }

  func setAudioTrack(id: Int) {
    mediaPlayer.currentAudioTrackIndex = Int32(id)
  }

  func setSubtitleTrack(id: Int) {
    didSelectPreferredSubtitle = true
    mediaPlayer.currentVideoSubTitleIndex = Int32(id)
  }

  func status() -> [String: Any] {
    let positionMs = mediaPlayer.time.value?.intValue ?? 0
    let durationMs = mediaPlayer.media?.length.value?.intValue ?? 0
    return [
      "positionMs": max(0, positionMs),
      "durationMs": max(0, durationMs),
      "playing": mediaPlayer.isPlaying,
      "completed": mediaPlayer.state == .ended,
      "volume": mediaPlayer.audio?.volume ?? 100,
      "rate": Double(mediaPlayer.rate),
    ]
  }

  func tracks() -> [String: Any] {
    let audioTracks = trackMaps(
      ids: mediaPlayer.audioTrackIndexes as NSArray,
      names: mediaPlayer.audioTrackNames as NSArray,
      fallback: "Audio",
      selectedId: Int(mediaPlayer.currentAudioTrackIndex)
    )
    let subtitleTracks = trackMaps(
      ids: mediaPlayer.videoSubTitlesIndexes as NSArray,
      names: mediaPlayer.videoSubTitlesNames as NSArray,
      fallback: "Subtitle",
      selectedId: Int(mediaPlayer.currentVideoSubTitleIndex)
    )
    return [
      "audio": audioTracks,
      "subtitle": subtitleTracks,
      "currentAudio": Int(mediaPlayer.currentAudioTrackIndex),
      "currentSubtitle": Int(mediaPlayer.currentVideoSubTitleIndex),
    ]
  }

  func dispose() {
    mediaPlayer.stop()
    mediaPlayer.delegate = nil
    mediaPlayer.drawable = nil
  }

  func mediaPlayerStateChanged(_ aNotification: Notification) {
    if mediaPlayer.state == .esAdded {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        self?.selectPreferredSubtitleIfNeeded()
      }
    }
  }

  private func selectPreferredSubtitleIfNeeded() {
    guard !didSelectPreferredSubtitle else { return }

    let ids = mediaPlayer.videoSubTitlesIndexes as? [Int32] ?? []
    let names = mediaPlayer.videoSubTitlesNames as? [String] ?? []
    guard !ids.isEmpty else { return }

    let preferredWords = [
      "zh", "chi", "zho", "chs", "cht", "chinese",
      "simplified", "traditional", "cn", "sc", "tc",
    ]

    for (index, id) in ids.enumerated() where id >= 0 {
      let name = index < names.count ? names[index].lowercased() : ""
      if preferredWords.contains(where: { name.contains($0) }) {
        mediaPlayer.currentVideoSubTitleIndex = id
        didSelectPreferredSubtitle = true
        return
      }
    }

    if mediaPlayer.currentVideoSubTitleIndex < 0,
       let first = ids.first(where: { $0 >= 0 }) {
      mediaPlayer.currentVideoSubTitleIndex = first
      didSelectPreferredSubtitle = true
    }
  }

  private func makeURL(from uri: String) -> URL? {
    if uri.hasPrefix("http://") || uri.hasPrefix("https://") || uri.hasPrefix("file://") {
      return URL(string: uri)
    }
    return URL(fileURLWithPath: uri)
  }

  private func trackMaps(
    ids: NSArray,
    names: NSArray,
    fallback: String,
    selectedId: Int
  ) -> [[String: Any]] {
    let trackIds = ids as? [Int32] ?? []
    let trackNames = names as? [String] ?? []
    return trackIds.enumerated().map { index, trackId in
      let id = Int(trackId)
      let name = index < trackNames.count ? trackNames[index] : "\(fallback) \(id)"
      return [
        "id": "\(id)",
        "title": id < 0 ? "Disabled" : name,
        "language": extractLanguage(from: name) ?? "",
        "selected": id == selectedId,
      ]
    }
  }

  private func extractLanguage(from name: String) -> String? {
    let patterns = [
      "\\(([A-Za-z]{2,3})\\)",
      "\\[([A-Za-z]{2,3})\\]",
    ]

    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern),
         let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
         let range = Range(match.range(at: 1), in: name) {
        return String(name[range])
      }
    }

    return nil
  }
}
