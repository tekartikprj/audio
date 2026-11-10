import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_file_picker/file_picker.dart';
import 'package:tekartik_pitch_flutter/pitch_flutter.dart';

import 'controller.dart';
import 'sounds.dart';

/// The views of the lab.
enum LabView {
  /// One note, its gauge.
  note('Note', Icons.speed),

  /// The strings of an instrument.
  strings('Strings', Icons.queue_music),

  /// The reeds of an accordion note.
  reeds('Reeds', Icons.graphic_eq),

  /// The notes played.
  notes('Notes', Icons.piano),

  /// The algorithms compared.
  compare('Compare', Icons.compare_arrows);

  /// The name shown.
  final String label;

  /// The icon.
  final IconData icon;

  const LabView(this.label, this.icon);
}

/// The lab: the source, A4, a view of the results.
class LabScreen extends StatefulWidget {
  /// The state of the lab.
  final PitchLabController controller;

  /// The lab of [controller].
  const LabScreen({super.key, required this.controller});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  var _view = LabView.note;

  PitchLabController get _controller => widget.controller;

  Future<void> _openFile() async {
    var file = await tekalyFilePicker.pickFile(
      type: TekalyPickFileType.custom,
      allowedExtensions: const ['wav'],
      dialogTitle: 'Open a WAV file (16 bit PCM)',
    );
    if (file == null) {
      return;
    }
    try {
      var bytes = await file.readAsBytes();
      await _controller.setSource(LabFile(file.name, bytes), start: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot read ${file.name}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        var listening = _controller.listening;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pitch lab'),
            actions: [
              ValueListenableBuilder<AudioLevel>(
                valueListenable: listening.level,
                builder: (context, level, _) => AudioLevelMic(level: level),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SourceCard(controller: _controller, onOpenFile: _openFile),
                  const SizedBox(height: 12),
                  _A4Row(controller: _controller),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var view in LabView.values)
                        ChoiceChip(
                          key: ValueKey('view_${view.name}'),
                          avatar: Icon(view.icon, size: 18),
                          label: Text(view.label),
                          selected: view == _view,
                          onSelected: (_) => setState(() => _view = view),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: switch (_view) {
                        LabView.note => _NoteView(controller: _controller),
                        LabView.strings => _StringsView(
                          controller: _controller,
                        ),
                        LabView.reeds => _ReedsView(controller: _controller),
                        LabView.notes => _NotesView(controller: _controller),
                        LabView.compare => _CompareView(
                          controller: _controller,
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  final PitchLabController controller;
  final VoidCallback onOpenFile;

  const _SourceCard({required this.controller, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    var source = controller.source;
    var intro = switch (source) {
      LabMicrophone() =>
        'Play or sing near the microphone: every algorithm listens at once.',
      LabTestSound(:var sound) => 'Test sound: ${sound.name}, looping.',
      LabFile(:var name) => 'File: $name, looping.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  key: const ValueKey('source_microphone'),
                  avatar: const Icon(Icons.mic, size: 18),
                  label: const Text('Microphone'),
                  selected: source is LabMicrophone,
                  // Tapped again when selected: nothing (the listening goes
                  // on).
                  onSelected: (selected) {
                    if (selected) {
                      unawaited(controller.setSource(const LabMicrophone()));
                    }
                  },
                ),
                DropdownButton<LabSound>(
                  key: const ValueKey('source_sound'),
                  hint: const Text('Test sound'),
                  value: source is LabTestSound ? source.sound : null,
                  items: [
                    for (var sound in labSounds)
                      DropdownMenuItem(value: sound, child: Text(sound.name)),
                  ],
                  onChanged: (sound) {
                    if (sound != null) {
                      unawaited(
                        controller.setSource(LabTestSound(sound), start: true),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  key: const ValueKey('source_file'),
                  icon: const Icon(Icons.audio_file_outlined),
                  label: const Text('WAV file'),
                  onPressed: onOpenFile,
                ),
              ],
            ),
            const SizedBox(height: 12),
            PitchListeningControl(
              listening: controller.listening,
              intro: intro,
              labels: const PitchListeningLabels(start: 'Listen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _A4Row extends StatelessWidget {
  final PitchLabController controller;

  const _A4Row({required this.controller});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        'A4 = ${controller.a4.toStringAsFixed(0)} Hz',
        key: const ValueKey('a4'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      Expanded(
        child: Slider(
          key: const ValueKey('a4_slider'),
          min: 430,
          max: 450,
          divisions: 20,
          value: controller.a4,
          onChanged: controller.setA4,
        ),
      ),
    ],
  );
}

String _cents(double cents) => '${pitchSignedCents(cents, decimals: 0)} cents';

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// One note: its name, the needle, its cents and frequency, how steady.
class _NoteView extends StatelessWidget {
  final PitchLabController controller;

  const _NoteView({required this.controller});

  @override
  Widget build(BuildContext context) {
    var colors = PitchColors.of(context);
    return ValueListenableBuilder<PitchReading?>(
      valueListenable: controller.note,
      builder: (context, reading, _) {
        var a4 = controller.a4;
        var cents = reading?.cents(a4: a4);
        var stable = reading?.stable() ?? false;
        var color = colors.forCents(cents);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              reading == null ? '–' : pitchNoteName(reading.note(a4: a4)),
              key: const ValueKey('note_name'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: reading == null ? colors.muted : colors.ink,
              ),
            ),
            PitchGauge(cents: cents),
            const SizedBox(height: 8),
            if (reading == null)
              const _Empty('Play or sing a note.')
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _cents(cents!),
                    key: const ValueKey('note_cents'),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  Text('${reading.frequency.toStringAsFixed(2)} Hz'),
                  Text(
                    '± ${reading.spread.toStringAsFixed(1)} cents',
                    style: TextStyle(color: colors.muted),
                  ),
                  Icon(
                    stable ? Icons.lock_outline : Icons.lock_open,
                    size: 18,
                    color: stable ? colors.inTune : colors.muted,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// The strings of an instrument, the notes found by peeling.
class _StringsView extends StatelessWidget {
  final PitchLabController controller;

  const _StringsView({required this.controller});

  @override
  Widget build(BuildContext context) {
    var tuning = controller.tuning;
    var targets = tuning.frequencies(a4: controller.a4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButton<PitchTuning>(
          key: const ValueKey('tuning'),
          isExpanded: true,
          value: tuning,
          items: [
            for (var tuning in pitchTunings)
              DropdownMenuItem(value: tuning, child: Text(tuning.name)),
          ],
          onChanged: (tuning) {
            if (tuning != null) {
              controller.setTuning(tuning);
            }
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<PitchReading?>>(
          valueListenable: controller.strings,
          builder: (context, readings, _) => PitchStringsView(
            strings: [
              for (var (index, name) in tuning.noteNames.indexed)
                () {
                  var reading = index < readings.length
                      ? readings[index]
                      : null;
                  return PitchStringState(
                    name,
                    cents: reading == null
                        ? null
                        : pitchCents(targets[index], reading.frequency),
                    stable: reading?.stable() ?? false,
                  );
                }(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<PitchStep?>(
          valueListenable: controller.listening.step,
          builder: (context, step, _) {
            var estimates =
                step?.result<PitchEstimates>(LabIds.peeling)?.estimates ??
                const <PitchEstimate>[];
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Notes found: '),
                if (estimates.isEmpty) const Text('–'),
                for (var estimate in estimates)
                  Chip(
                    label: Text(
                      '${pitchNoteName(estimate.note(a4: controller.a4))} '
                      '${pitchSignedCents(estimate.cents(a4: controller.a4), decimals: 0)}',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The reeds of the note held.
class _ReedsView extends StatelessWidget {
  final PitchLabController controller;

  const _ReedsView({required this.controller});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PitchReeds?>(
    valueListenable: controller.reeds,
    builder: (context, reeds, _) {
      if (reeds == null) {
        return const _Empty(
          'Hold a note: each reed that sounds shows here (an accordion '
          'musette or violin register), and how fast they beat.',
        );
      }
      // The rate of the input analyzed (a WAV file has its own).
      var sampleRate =
          controller.listening.input?.sampleRate ??
          PitchLabController.sampleRate;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${reeds.reeds.length} '
            '${reeds.reeds.length == 1 ? 'reed' : 'reeds'} · '
            '${pitchNoteName(reeds.pitch)}',
            key: const ValueKey('reeds_count'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          PitchReedsView(reeds: reeds),
          Text(
            [
              for (var reed in reeds.reeds)
                '${reed.frequency.toStringAsFixed(2)} Hz',
            ].join(' · '),
            textAlign: TextAlign.center,
          ),
          if (reeds.reeds.length > 2)
            Text(
              'Outer reeds: ${reeds.outerBeats.toStringAsFixed(1)} beats/s',
              textAlign: TextAlign.center,
            ),
          Text(
            '± ${reeds.uncertainty.toStringAsFixed(2)} cents, '
            '${reeds.harmonics} harmonics, '
            '${(reeds.size / sampleRate * 1000).round()} ms',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    },
  );
}

/// The notes played: the largest shares of the sound.
class _NotesView extends StatelessWidget {
  final PitchLabController controller;

  const _NotesView({required this.controller});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PitchStep?>(
    valueListenable: controller.listening.step,
    builder: (context, step, _) {
      var shares = step?.result<PitchShares>(LabIds.notes);
      if (shares == null || shares.loudest == null) {
        return const _Empty('Play one or more notes.');
      }
      var pitches = [
        for (
          var pitch = shares.firstPitch + 2;
          pitch <= shares.lastPitch - 2;
          pitch++
        )
          pitch,
      ]..sort((a, b) => shares.share(b).compareTo(shares.share(a)));
      var colors = PitchColors.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var pitch in pitches.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      pitchNoteName(pitch),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: shares.share(pitch),
                      minHeight: 8,
                      color: shares.hears(pitch, octaves: false)
                          ? colors.inTune
                          : colors.muted,
                      backgroundColor: colors.line,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${(shares.share(pitch) * 100).round()} %',
                      textAlign: TextAlign.end,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: shares.hears(pitch, octaves: false)
                        ? Icon(Icons.check, size: 18, color: colors.inTune)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// The algorithms side by side, what each one took, the sound.
class _CompareView extends StatelessWidget {
  final PitchLabController controller;

  const _CompareView({required this.controller});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        key: const ValueKey('worker'),
        contentPadding: EdgeInsets.zero,
        title: const Text(kIsWeb ? 'In a web worker' : 'In an isolate'),
        subtitle: ValueListenableBuilder<PitchStep?>(
          valueListenable: controller.listening.step,
          builder: (context, step, _) => Text(
            step == null
                ? 'Off the main thread when on'
                : controller.processor.offThread
                ? 'The analyses run off the main thread'
                : 'The analyses run on the main thread',
          ),
        ),
        value: controller.worker,
        onChanged: (worker) => unawaited(controller.setWorker(worker)),
      ),
      ValueListenableBuilder<PitchStep?>(
        valueListenable: controller.listening.step,
        builder: (context, step, _) => step == null
            ? const _Empty('Start listening to compare the algorithms.')
            : _results(context, step),
      ),
    ],
  );

  Widget _results(BuildContext context, PitchStep step) {
    {
      var a4 = controller.a4;
      var muted = TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
      String ms(String id) {
        // The reeds use the window their note needs, not their longest.
        var window = step.result<PitchReeds>(id)?.size ?? step.windows?[id];
        return window == null
            ? ''
            : '${(window / step.sampleRate * 1000).round()} ms';
      }

      String micros(String id) {
        var value = step.micros?[id];
        return value == null ? '' : '${(value / 1000).toStringAsFixed(1)} ms';
      }

      var total = step.micros?.values.fold(0, (a, b) => a + b) ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const ValueKey('compare_table'),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Algorithm')),
                DataColumn(label: Text('Note')),
                DataColumn(label: Text('Hz'), numeric: true),
                DataColumn(label: Text('Clarity'), numeric: true),
                DataColumn(label: Text('Window'), numeric: true),
                DataColumn(label: Text('Time'), numeric: true),
              ],
              rows: [
                for (var id in LabIds.mono)
                  () {
                    var estimate = step.result<PitchEstimate>(id);
                    return DataRow(
                      cells: [
                        DataCell(Text(id)),
                        DataCell(
                          Text(
                            estimate == null
                                ? '–'
                                : '${pitchNoteName(estimate.note(a4: a4))} '
                                      '${_cents(estimate.cents(a4: a4))}',
                          ),
                        ),
                        DataCell(
                          Text(estimate?.frequency.toStringAsFixed(2) ?? '–'),
                        ),
                        DataCell(
                          Text(estimate?.clarity.toStringAsFixed(2) ?? '–'),
                        ),
                        DataCell(Text(ms(id))),
                        DataCell(Text(micros(id))),
                      ],
                    );
                  }(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Every analysis of a step', style: muted),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var analysis in controller.listening.analyses)
                Chip(
                  label: Text(
                    '${analysis.id} ${micros(analysis.id)}'
                    ' · ${ms(analysis.id)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total ${(total / 1000).toStringAsFixed(1)} ms every '
            '${(controller.listening.hop / step.sampleRate * 1000).round()} ms'
            ' · level ${step.decibels.isFinite ? step.decibels.round() : '–'}'
            ' dB · peak ${(step.peak * 100).round()} %'
            '${step.clipped() ? ' · clipped' : ''}',
            key: const ValueKey('compare_total'),
            style: muted,
          ),
          Text(
            'At ${step.time.toStringAsFixed(2)} s, '
            '${math.max(0, step.sample)} samples',
            style: muted,
          ),
        ],
      );
    }
  }
}
