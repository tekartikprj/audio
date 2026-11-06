/// The main of the pitch worker script (web only), built by the setup step
/// (`dart run tekartik_pitch_web_worker:setup`).
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:tekartik_pitch/pitch.dart';
import 'package:web/web.dart' as web;

import 'js_message.dart';
import 'protocol.dart';

/// The worker script main.
void main() => pitchWorkerMain();

/// Runs the sessions the page opens: a runner each, its steps sent back.
void pitchWorkerMain() {
  var scope = globalContext as web.DedicatedWorkerGlobalScope;
  var runners = <int, PitchRunner>{};
  scope.onmessage = (web.MessageEvent event) {
    var message = event.data as PitchWorkerJsMessage?;
    var id = message?.id;
    if (message == null || id == null) {
      return;
    }
    try {
      switch (message.type) {
        case pitchWorkerMessageOpen:
          runners[id] = PitchRunner.fromJson(
            (jsonDecode(message.runner!) as Map).cast<String, Object?>(),
          );
        case pitchWorkerMessageChunk:
          var steps = runners[id]?.add(message.samples!.toDart);
          if (steps != null && steps.isNotEmpty) {
            scope.postMessage(
              PitchWorkerJsMessage(
                type: pitchWorkerMessageSteps,
                id: id,
                steps: jsonEncode([for (var step in steps) step.toJson()]),
              ),
            );
          }
        case pitchWorkerMessageAnalyses:
          runners[id]?.analyses = [
            for (var analysis in jsonDecode(message.analyses!) as List)
              PitchAnalysis.fromJson((analysis as Map).cast<String, Object?>()),
          ];
        case pitchWorkerMessageClose:
          runners.remove(id);
      }
    } catch (e) {
      scope.postMessage(
        PitchWorkerJsMessage(
          type: pitchWorkerMessageError,
          id: id,
          error: '$e',
        ),
      );
    }
  }.toJS;
  scope.postMessage(
    PitchWorkerJsMessage(
      type: pitchWorkerMessageReady,
      version: pitchWorkerProtocolVersion,
    ),
  );
}
