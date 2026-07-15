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

    // Register the platform view before Flutter finishes launching. Calling
    // super first lets Dart build AppKitView while its view type is still
    // unknown, which leaves the player permanently at 00:00.
    super.applicationDidFinishLaunching(notification)

    mainFlutterWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
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
#if DEBUG
    NSLog("[FilmlyVLC] registered view id=%lld", id)
#endif
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
#if DEBUG
      NSLog("[FilmlyVLC] channel open view=%lld uri=%@", viewId, uri)
#endif
      if let message = view.open(uri: uri, httpHeaders: headers, startMs: startMs) {
        result(FlutterError(code: "OPEN_FAILED", message: message, details: nil))
      } else {
        result(nil)
      }
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
    case "addSubtitleTrack":
      guard let uri = args["uri"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing subtitle URI", details: nil))
        return
      }
      result(view.addSubtitleTrack(uri: uri))
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
  private var isNetworkMedia = false
  private var lastError: String?

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

  func open(uri: String, httpHeaders: [String: String], startMs: Int) -> String? {
    guard let url = makeURL(from: uri) else {
#if DEBUG
      NSLog("[FilmlyVLC] invalid URI: %@", uri)
#endif
      let message = "媒体地址无效"
      lastError = message
      return message
    }

#if DEBUG
    let exists = url.isFileURL ? FileManager.default.fileExists(atPath: url.path) : true
    NSLog("[FilmlyVLC] open url=%@ file=%d exists=%d", url.absoluteString, url.isFileURL, exists)
#endif

    if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) {
      let message = "找不到媒体文件，请确认外置磁盘或网络共享已挂载"
      lastError = message
      return message
    }

    lastError = nil
    didSelectPreferredSubtitle = false
    let isHttpMedia = uri.hasPrefix("http://") || uri.hasPrefix("https://")
    let volumeValues = try? url.resourceValues(forKeys: [.volumeIsLocalKey])
    let isRemoteVolume = url.isFileURL && volumeValues?.volumeIsLocal == false
    isNetworkMedia = isHttpMedia || isRemoteVolume
    mediaPlayer.stop()

    let media = VLCMedia(url: url)
    let fileCacheMs = isRemoteVolume ? 8000 : 1500
    let networkCacheMs = isHttpMedia ? 8000 : 3000
    media.addOptions([
      "network-caching": networkCacheMs,
      "file-caching": fileCacheMs,
      "live-caching": 3000,
      "sout-mux-caching": 1500,
      "avcodec-hw": "videotoolbox",
      "sub-autodetect-file": true,
      "subsdec-encoding": "UTF-8",
    ])

#if DEBUG
    NSLog(
      "[FilmlyVLC] source http=%d remoteVolume=%d fileCache=%d networkCache=%d hw=videotoolbox",
      isHttpMedia,
      isRemoteVolume,
      fileCacheMs,
      networkCacheMs
    )
#endif

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
    return nil
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

  func addSubtitleTrack(uri: String) -> Bool {
    guard let url = makeURL(from: uri) else { return false }
    didSelectPreferredSubtitle = true
    return mediaPlayer.addPlaybackSlave(
      url,
      type: .subtitle,
      enforce: true
    ) == 0
  }

  func status() -> [String: Any] {
    let positionMs = mediaPlayer.time.value?.intValue ?? 0
    let durationMs = mediaPlayer.media?.length.value?.intValue ?? 0
    let state = mediaPlayer.state
    // VLCKit can keep reporting `.buffering` while decoded frames are already
    // playing. In that case showing a spinner on top of the movie is wrong.
    let buffering = state == .opening ||
      (state == .buffering && !mediaPlayer.isPlaying)
    let bufferMs = isNetworkMedia ? positionMs : durationMs
    let error = lastError ?? (state == .error ? "VLC 无法解码或读取当前媒体" : "")
    return [
      "positionMs": max(0, positionMs),
      "durationMs": max(0, durationMs),
      "playing": mediaPlayer.isPlaying,
      "completed": mediaPlayer.state == .ended,
      "volume": mediaPlayer.audio?.volume ?? 100,
      "rate": Double(mediaPlayer.rate),
      "bufferMs": max(0, bufferMs),
      "buffering": buffering,
      "error": error,
    ]
  }

  func tracks() -> [String: Any] {
    let audioTracks = trackMaps(
      ids: mediaPlayer.audioTrackIndexes as NSArray,
      names: mediaPlayer.audioTrackNames as NSArray,
      fallback: "Audio",
      trackType: VLCMediaTracksInformationTypeAudio,
      selectedId: Int(mediaPlayer.currentAudioTrackIndex)
    )
    let subtitleTracks = trackMaps(
      ids: mediaPlayer.videoSubTitlesIndexes as NSArray,
      names: mediaPlayer.videoSubTitlesNames as NSArray,
      fallback: "Subtitle",
      trackType: VLCMediaTracksInformationTypeText,
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
#if DEBUG
    NSLog(
      "[FilmlyVLC] state=%d time=%@ length=%@",
      mediaPlayer.state.rawValue,
      mediaPlayer.time.stringValue,
      mediaPlayer.media?.length.stringValue ?? "nil"
    )
#endif
    if mediaPlayer.state == .error {
      lastError = "VLC 无法解码或读取当前媒体"
    }
    if mediaPlayer.state == .esAdded {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        self?.selectPreferredSubtitleIfNeeded()
      }
    }
  }

  private func selectPreferredSubtitleIfNeeded() {
    guard !didSelectPreferredSubtitle else { return }

    let ids = trackIds(from: mediaPlayer.videoSubTitlesIndexes as NSArray)
    let names = (mediaPlayer.videoSubTitlesNames as NSArray).compactMap { $0 as? String }
    guard !ids.isEmpty else { return }

#if DEBUG
    NSLog("[FilmlyVLC] subtitle tracks ids=%@ names=%@", ids, names)
#endif

    let preferredWords = [
      "zh", "chi", "zho", "chs", "cht", "chinese",
      "simplified", "traditional", "cn", "sc", "tc",
    ]

    for (index, id) in ids.enumerated() where id >= 0 {
      let name = index < names.count ? names[index].lowercased() : ""
      if preferredWords.contains(where: { name.contains($0) }) {
        mediaPlayer.currentVideoSubTitleIndex = id
        didSelectPreferredSubtitle = true
#if DEBUG
        NSLog("[FilmlyVLC] selected preferred subtitle id=%d name=%@", id, name)
#endif
        return
      }
    }

    if mediaPlayer.currentVideoSubTitleIndex < 0,
       let first = ids.first(where: { $0 >= 0 }) {
      mediaPlayer.currentVideoSubTitleIndex = first
      didSelectPreferredSubtitle = true
#if DEBUG
      NSLog("[FilmlyVLC] selected fallback subtitle id=%d", first)
#endif
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
    trackType: String,
    selectedId: Int
  ) -> [[String: Any]] {
    let trackIds = trackIds(from: ids)
    let trackNames = names.compactMap { $0 as? String }
    let metadata = trackMetadata(type: trackType)
    return trackIds.enumerated().map { index, trackId in
      let id = Int(trackId)
      let info = metadata[id]
      let name = info?.title ?? (
        index < trackNames.count ? trackNames[index] : "\(fallback) \(id)"
      )
      return [
        "id": "\(id)",
        "title": id < 0 ? "Disabled" : name,
        "language": info?.language ?? extractLanguage(from: name) ?? "",
        "selected": id == selectedId,
      ]
    }
  }

  private func trackIds(from values: NSArray) -> [Int32] {
    values.compactMap { value in
      if let number = value as? NSNumber { return number.int32Value }
      if let value = value as? Int32 { return value }
      if let value = value as? Int { return Int32(value) }
      return nil
    }
  }

  private func trackMetadata(type: String) -> [Int: (title: String?, language: String?)] {
    guard let information = mediaPlayer.media?.tracksInformation as? [[String: Any]] else {
      return [:]
    }
    var result: [Int: (title: String?, language: String?)] = [:]
    for track in information {
      guard let trackType = track[VLCMediaTracksInformationType] as? String,
            trackType == type else { continue }
      let id: Int?
      if let value = track[VLCMediaTracksInformationId] as? NSNumber {
        id = value.intValue
      } else {
        id = track[VLCMediaTracksInformationId] as? Int
      }
      guard let id else { continue }
      let title = track[VLCMediaTracksInformationDescription] as? String
      let language = track[VLCMediaTracksInformationLanguage] as? String
      result[id] = (title: title, language: language)
    }
    return result
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
