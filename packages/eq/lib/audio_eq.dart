/// Parametric equalizer in pure Dart: bands, biquad coefficients, response
/// curve, a reference processor, PipeWire filter-chain and Web Audio forms.
library;

export 'src/eq_band.dart'
    show EqBand, EqFilterType, EqPreset, eqBandwidthToQ, eqButterworthQ;
export 'src/eq_biquad.dart' show EqBiquad, EqChain, eqDbToLinear, eqLinearToDb;
export 'src/eq_demo_sound.dart' show eqDemoTechno;
export 'src/eq_number.dart' show eqFormatNumber;
export 'src/eq_pipewire_format.dart'
    show
        EqPipeWireMix,
        eqPipeWireBandNodeName,
        eqPipeWireIdentityBand,
        eqPipeWireInputNodeName,
        eqPipeWireLabels,
        eqPipeWireMixNodeName,
        eqPipeWirePathPreampNodeName,
        eqPipeWirePreampNodeName,
        eqPipeWireGainNodeNames,
        eqPipeWireGainSmoothing,
        eqPipeWireSameChain,
        eqPipeWireSlotBands,
        formatEqPipeWireFilterChainArgs,
        formatEqPipeWireFilterChainConf,
        formatEqPipeWireMixParams,
        formatEqPipeWireParams;
export 'src/eq_presets.dart' show EqPresets;
export 'src/eq_processor.dart' show EqProcessor;
export 'src/eq_response.dart' show EqResponse, eqAutoPreamp, eqLogFrequencies;
export 'src/eq_web_audio.dart' show EqWebAudioFilter, eqWebAudioFilters;
