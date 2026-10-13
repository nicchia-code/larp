import AVFoundation
import Cocoa
import FlutterMacOS
import ScreenCaptureKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.setContentSize(NSSize(width: 480, height: 240))

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger
    let channel = FlutterMethodChannel(
      name: "call_to_record/audio_sources", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "missingSources":
        MainFlutterWindow.missingSources(completion: result)
      case "startCapture":
        MainFlutterWindow.startCapture(call.arguments, completion: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    for (name, capture) in MainFlutterWindow.captures {
      FlutterEventChannel(
        name: "call_to_record/audio_pcm/\(name)", binaryMessenger: messenger
      ).setStreamHandler(capture)
    }

    super.awakeFromNib()
  }

  /// Names ("microphone", "pcAudio") of the sources that cannot be captured now.
  private static func missingSources(completion: @escaping FlutterResult) {
    microphoneAvailable { microphone in
      var missing: [String] = []
      if !microphone { missing.append("microphone") }
      if !pcAudioAvailable() { missing.append("pcAudio") }
      DispatchQueue.main.async { completion(missing) }
    }
  }

  /// The default microphone exists and its permission is granted. Asks for the permission once, when undecided.
  private static func microphoneAvailable(completion: @escaping (Bool) -> Void) {
    guard AVCaptureDevice.default(for: .audio) != nil else {
      completion(false)
      return
    }
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      completion(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    default:
      completion(false)
    }
  }

  /// PC audio is captured with ScreenCaptureKit, which needs the Screen Recording permission.
  /// When it is missing, the system prompt is shown; the grant may need an app restart.
  private static func pcAudioAvailable() -> Bool {
    if CGPreflightScreenCaptureAccess() { return true }
    _ = CGRequestScreenCaptureAccess()
    return false
  }

  /// One capture per source, each streaming on its own event channel.
  private static let captures: [String: SourceCapture] = {
    var captures: [String: SourceCapture] = ["microphone": MicrophoneCapture()]
    if #available(macOS 13.0, *) { captures["pcAudio"] = PcAudioCapture() }
    return captures
  }()

  /// Starts the capture named by the argument; answers an error when it cannot start.
  private static func startCapture(_ arguments: Any?, completion: @escaping FlutterResult) {
    guard let name = arguments as? String, let capture = captures[name] else {
      completion(FlutterError(code: "unknown_source", message: "Unknown audio source", details: nil))
      return
    }
    capture.start { error in
      if let error {
        completion(FlutterError(code: "unavailable", message: error.localizedDescription, details: nil))
      } else {
        completion(nil)
      }
    }
  }
}

/// Streams one source to Dart as 16 kHz mono 16-bit PCM on the event channel
/// `call_to_record/audio_pcm/<name>`. Cancelling the channel stops the capture; a capture
/// that ends by itself closes the channel, which Dart reads as the source lost.
class SourceCapture: NSObject, FlutterStreamHandler {
  private var events: FlutterEventSink?
  private var running = false
  private let converter = PcmConverter()

  /// Starts the platform capture; [completion] is called on the main thread with the error, if any.
  func startSource(completion: @escaping (Error?) -> Void) {
    fatalError("subclasses implement startSource")
  }

  /// Ends the platform capture. Pending buffers are dropped by [emit].
  func stopSource() {}

  /// Called on the main thread.
  func start(completion: @escaping (Error?) -> Void) {
    guard !running else {
      completion(CaptureError.alreadyRunning)
      return
    }
    running = true
    startSource { error in
      DispatchQueue.main.async {
        if error != nil {
          self.running = false
          self.stopSource()
        }
        completion(error)
      }
    }
  }

  /// Dart cancelled the channel: stop on purpose, no end event.
  func stop() {
    guard running else { return }
    running = false
    stopSource()
  }

  /// The capture ended by itself: close the channel so Dart sees the source lost. Main thread.
  func lost() {
    guard running else { return }
    running = false
    stopSource()
    events?(FlutterEndOfEventStream)
  }

  /// Converts a buffer and sends it to Dart. Called on the capture's own thread.
  func emit(_ buffer: AVAudioPCMBuffer) {
    guard let data = converter.convert(buffer) else { return }
    DispatchQueue.main.async {
      guard self.running, let events = self.events else { return }
      events(FlutterStandardTypedData(bytes: data))
    }
  }

  func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.events = events
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    stop()
    events = nil
    return nil
  }
}

/// Microphone: the default input device through AVAudioEngine (Microphone permission).
final class MicrophoneCapture: SourceCapture {
  private var engine: AVAudioEngine?
  private var configObserver: NSObjectProtocol?

  override func startSource(completion: @escaping (Error?) -> Void) {
    guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
      completion(CaptureError.permissionDenied)
      return
    }
    let engine = AVAudioEngine()
    engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
      self?.emit(buffer)
    }
    do {
      try engine.start()
    } catch {
      engine.inputNode.removeTap(onBus: 0)
      completion(error)
      return
    }
    self.engine = engine
    // The input device went away or changed: the engine stopped, so the source is lost.
    configObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
    ) { [weak self] _ in
      self?.lost()
    }
    completion(nil)
  }

  override func stopSource() {
    if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
    configObserver = nil
    engine?.inputNode.removeTap(onBus: 0)
    engine?.stop()
    engine = nil
  }
}

/// PC audio: the audio of the main display through ScreenCaptureKit (macOS 13+, Screen Recording permission).
@available(macOS 13.0, *)
final class PcAudioCapture: SourceCapture, SCStreamOutput, SCStreamDelegate {
  private var stream: SCStream?
  private let queue = DispatchQueue(label: "call_to_record.pc_audio")

  override func startSource(completion: @escaping (Error?) -> Void) {
    guard CGPreflightScreenCaptureAccess() else {
      completion(CaptureError.permissionDenied)
      return
    }
    SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
      guard let display = content?.displays.first else {
        completion(error ?? CaptureError.noDisplay)
        return
      }
      let config = SCStreamConfiguration()
      config.capturesAudio = true
      config.excludesCurrentProcessAudio = true
      config.sampleRate = 48000
      config.channelCount = 2
      // Only audio is used: the video is kept minimal, and its frames are dropped.
      config.width = 2
      config.height = 2
      config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
      let stream = SCStream(
        filter: SCContentFilter(display: display, excludingWindows: []),
        configuration: config, delegate: self)
      do {
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.queue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.queue)
      } catch {
        completion(error)
        return
      }
      self.stream = stream
      stream.startCapture { error in completion(error) }
    }
  }

  override func stopSource() {
    stream?.stopCapture { _ in }
    stream = nil
  }

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType
  ) {
    guard type == .audio, let buffer = Self.pcmBuffer(sampleBuffer) else { return }
    emit(buffer)
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    DispatchQueue.main.async { self.lost() }
  }

  private static func pcmBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
    guard sampleBuffer.isValid, let description = CMSampleBufferGetFormatDescription(sampleBuffer)
    else { return nil }
    let format = AVAudioFormat(cmAudioFormatDescription: description)
    let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
    guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
    else { return nil }
    buffer.frameLength = frames
    let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
      sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList)
    return status == noErr ? buffer : nil
  }
}

/// Converts captured buffers to 16 kHz mono signed 16-bit little-endian PCM, as Dart expects.
final class PcmConverter {
  private static let target = AVAudioFormat(
    commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
  private var converter: AVAudioConverter?
  private var source: AVAudioFormat?

  func convert(_ input: AVAudioPCMBuffer) -> Data? {
    if source != input.format {
      source = input.format
      converter = AVAudioConverter(from: input.format, to: Self.target)
    }
    guard let converter else { return nil }
    let capacity =
      AVAudioFrameCount(Double(input.frameLength) * Self.target.sampleRate / input.format.sampleRate)
      + 16
    guard let output = AVAudioPCMBuffer(pcmFormat: Self.target, frameCapacity: capacity) else {
      return nil
    }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      if supplied {
        inputStatus.pointee = .noDataNow
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return input
    }
    guard status != .error, let samples = output.int16ChannelData else { return nil }
    return Data(bytes: samples[0], count: Int(output.frameLength) * MemoryLayout<Int16>.size)
  }
}

enum CaptureError: LocalizedError {
  case permissionDenied, noDisplay, alreadyRunning

  var errorDescription: String? {
    switch self {
    case .permissionDenied: return "permission denied"
    case .noDisplay: return "no display to capture"
    case .alreadyRunning: return "already capturing"
    }
  }
}
