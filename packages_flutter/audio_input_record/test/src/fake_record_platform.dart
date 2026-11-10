import 'dart:async';
import 'dart:typed_data';

import 'package:record_platform_interface/record_platform_interface.dart';

/// A record platform without any device: the permission is answered after
/// [permissionDelay], a started stream gives nothing until stopped.
class FakeRecordPlatform extends RecordPlatform {
  /// How long the permission takes (a dialog).
  final Duration permissionDelay;

  /// True while a stream is recorded.
  var recording = false;

  StreamController<Uint8List>? _controller;

  /// A platform answering the permission after [permissionDelay].
  FakeRecordPlatform({this.permissionDelay = const Duration(milliseconds: 50)});

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    await Future<void>.delayed(permissionDelay);
    return true;
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    recording = true;
    return (_controller = StreamController<Uint8List>()).stream;
  }

  @override
  Future<String?> stop(String recorderId) async {
    recording = false;
    var controller = _controller;
    _controller = null;
    unawaited(controller?.close());
    return null;
  }

  @override
  Future<void> dispose(String recorderId) => stop(recorderId);

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();

  // The other members are not used by AudioInputMicrophone.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
