/// The messages between the page and the pitch worker, as JS objects (web
/// only).
library;

import 'dart:js_interop';
import 'dart:typed_data';

/// A message, a plain JS object (see the types in `protocol.dart`).
extension type PitchWorkerJsMessage._(JSObject _) implements JSObject {
  /// A message with the given fields only.
  external factory PitchWorkerJsMessage({
    String type,
    int id,
    int version,
    String runner,
    JSFloat32Array samples,
    String analyses,
    String steps,
    String error,
  });

  /// The message type.
  external String? get type;

  /// The session id.
  external int? get id;

  /// The protocol version (ready).
  external int? get version;

  /// The JSON runner (open).
  external String? get runner;

  /// The samples (chunk).
  external JSFloat32Array? get samples;

  /// The JSON analyses (analyses).
  external String? get analyses;

  /// The JSON steps (steps).
  external String? get steps;

  /// The error (error).
  external String? get error;
}

/// The `buffer` of a JS typed array, for the transfer list of
/// `postMessage`.
extension PitchJSTypedArrayBuffer on JSTypedArray {
  /// The ArrayBuffer of this view.
  external JSArrayBuffer get buffer;
}

/// [samples] in a JS array whose buffer can be moved to the other thread:
/// [samples] itself when it has a buffer of its own (it is then detached),
/// a copy otherwise.
JSFloat32Array jsTransferableSamples(Float32List samples) {
  var ownBuffer =
      samples.offsetInBytes == 0 &&
      samples.lengthInBytes == samples.buffer.lengthInBytes;
  return (ownBuffer ? samples : Float32List.fromList(samples)).toJS;
}
