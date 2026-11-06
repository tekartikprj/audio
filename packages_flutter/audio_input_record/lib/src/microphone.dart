import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:tekartik_audio_input/audio_input.dart';

/// The microphone of the device as an [AudioInput], through the `record`
/// package (an AudioWorklet on the web, parecord on Linux, the native
/// recorders elsewhere): mono 16 bit PCM turned to floats, with no
/// automatic gain, echo cancellation or noise suppression (they eat held
/// notes).
///
/// The host app declares the permission: `RECORD_AUDIO` on Android,
/// `NSMicrophoneUsageDescription` on iOS and macOS (plus the
/// `com.apple.security.device.audio-input` entitlement on macOS).
class AudioInputMicrophone implements AudioInput {
  @override
  final int sampleRate;

  /// The device used, the default one when null ([listDevices]).
  final AudioInputDevice? device;

  final double? _latency;

  AudioRecorder? _recorder;
  final _decoder = AudioInputPcm16Decoder();

  /// The microphone [device] (the default one when null) at [sampleRate]
  /// Hz, [latency] seconds late (by default 0.05 on the web, 0.12
  /// elsewhere).
  AudioInputMicrophone({this.sampleRate = 44100, this.device, this._latency});

  @override
  double get latency => _latency ?? (kIsWeb ? 0.05 : 0.12);

  AudioRecorder get _activeRecorder => _recorder ??= AudioRecorder();

  /// The input devices (after the permission is granted, labels may be
  /// empty before on the web); throws [AudioInputUnavailable] when the
  /// platform cannot tell.
  Future<List<AudioInputDevice>> listDevices() async {
    try {
      return [
        for (var device in await _activeRecorder.listInputDevices())
          AudioInputDevice(device.id, device.label),
      ];
    } catch (e) {
      throw AudioInputUnavailable('$e');
    }
  }

  /// True when the microphone is allowed; asks the user when [request].
  Future<bool> hasPermission({bool request = true}) async {
    try {
      return await _activeRecorder.hasPermission(request: request);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Stream<Float32List>> start() async {
    var recorder = _activeRecorder;
    bool allowed;
    try {
      allowed = await recorder.hasPermission();
    } catch (e) {
      throw AudioInputUnavailable('$e');
    }
    if (!allowed) {
      throw const AudioInputDenied();
    }
    _decoder.reset();
    var device = this.device;
    try {
      var bytes = await recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          device: device == null
              ? null
              : InputDevice(id: device.id, label: device.label),
        ),
      );
      return bytes.map(_decoder.convert);
    } catch (e) {
      throw AudioInputUnavailable('$e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _recorder?.stop();
    } catch (e) {
      // Already stopped.
    }
  }

  /// Stops and frees the recorder (a new one is made when started again).
  Future<void> dispose() async {
    await stop();
    var recorder = _recorder;
    _recorder = null;
    await recorder?.dispose();
  }
}
