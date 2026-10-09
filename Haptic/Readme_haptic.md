## `create_haptic_stimuli.m`

Creates speech-derived vibrotactile stimulation signals for the haptic entrainment experiment.

The function processes all `.wav` files in a stimulus folder and generates:

- RMS-normalized speech files
- speech-derived amplitude envelopes
- 150 Hz amplitude-modulated haptic signals
- quality-control figures
- CSV and MAT manifests containing stimulus statistics and processing settings

### Processing pipeline

For each speech stimulus, the function:

1. Converts the audio to mono if necessary.
2. Normalizes all speech stimuli to a common RMS level.
3. Ensures that the same RMS target is used across the complete stimulus set.
4. Filters the normalized speech through a [31-channel gammatone filter bank](https://github.com/IoSR-Surrey/MatlabToolbox) .
5. Uses centre frequencies spaced evenly on the Mel scale between 150 and 7000 Hz.
6. Uses the IoSR implementation `iosr.auditory.gammatoneFast`.
7. Applies `align=true` in `gammatoneFast` to compensate for frequency-dependent filter delays.
8. Extracts the Hilbert amplitude envelope independently from each gammatone band.
9. Averages the 31 band envelopes to obtain a broadband speech envelope.
10. Does **not** low-pass filter the extracted envelope.
11. Applies a single global envelope scaling factor across all stimuli.
12. Uses the scaled envelope to amplitude-modulate a 150 Hz sinusoidal carrier.
13. Applies the same global haptic gain to every stimulus.
14. Saves the processed files and QC information.

The resulting haptic signal is:

```text
haptic(t) = global_gain × envelope(t) × sin(2π × 150 × t)
```

A link to the haptic stimuli dataset is to be included.
