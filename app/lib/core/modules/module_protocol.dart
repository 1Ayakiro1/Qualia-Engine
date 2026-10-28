/// Middle API (module ↔ engine) wire contract, shared by stdio and TCP.
///
/// Internal API (module ↔ module) input/output rides over this channel, but only
/// the host router selects recipients from workspace links. This is not the
/// external AI/service API. See docs/API_LAYERS.md and the SDK api_layers.json.
///
/// Frames are UTF-8 JSON objects terminated by LF. The limit is applied to
/// the encoded frame, not to the Dart string length.
class ModuleProtocol {
  static const version = 1;
  static const capabilities = ['port-schemas-v1', 'host-logic-v1'];
  static const maxFrameBytes = 1024 * 1024;
  static const maxQueuedFrames = 128;
  static const maxFramesPerSecond = 1000;

  const ModuleProtocol._();
}
