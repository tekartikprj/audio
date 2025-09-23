#!/usr/bin/env dart

library;

import 'dart:io';

import 'package:tekartik_wav/wav_file.dart';

void main(List<String> args) async {
  for (var arg in args) {
    var file = File(arg);
    if (file.existsSync()) {
      //List<int> data = file.readAsBytesSync();
      //      FileParser parser = new FileParser(new MidiParser(data));
      //      parser.parseFile();
      //      parser.file.dump();
      var wavFile = WavFile();
      await wavFile.read(file.openRead());

      wavFile.dump();
      //        expect(wavFile.soundBuffers[0].length, equals(215424));
      //
    }
  }
}
