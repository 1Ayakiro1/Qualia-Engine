/// Limits shared by the host-side module transports.
///
/// Frames are UTF-8 JSON objects terminated by LF. The limit is applied to
/// the encoded frame, not to the Dart string length.
class ModuleProtocol {
  static const maxFrameBytes = 1024 * 1024;
  static const maxQueuedFrames = 128;
  static const maxFramesPerSecond = 1000;

  const ModuleProtocol._();
}
