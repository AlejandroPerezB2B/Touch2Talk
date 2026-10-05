# Four-Talker Speech Masker Creation

This document describes the MATLAB procedure used to create independent four-talker speech-masker segments from the Spanish **Glissando-sp** corpus.

Garrido, J. M., Escudero, D., Aguilar, L., Cardeñoso, V., Rodero, E., de-la-Mota, C.,
González, C., Rustullet, S., Larrea, O., Laplaza, Y., Vizcaíno, F., Cabrera, M., Bonafonte, A.
(2013). Glissando: a corpus for multidisciplinary prosodic studies in Spanish and Catalan,
Language Resources and Evaluation, 47, 4, 945-971. DOI 10.1007/s10579-012-9213-0.

## Source corpus

The masker is constructed from the **News** subcorpus of Glissando-sp.

The following corpus components are used:

- Subcorpus: `News`
- Material: `Prosodic`
- Recording type: `.fix.wav`
- Number of speakers: 4
- Number of recordings per speaker: 36
- Number of resulting four-talker masker sets: 36

The four selected speakers are professional news broadcasters:

| Speaker | Sex | Profile |
| --- | --- | --- |
| `sp_f11r` | Female | News broadcaster |
| `sp_f13r` | Female | News broadcaster |
| `sp_m12r` | Male | News broadcaster |
| `sp_m14r` | Male | News broadcaster |

## General procedure

The first processing stage creates **36 independent four-talker masker segments**.

Each masker set contains one recording from each of the four speakers. The four recordings within a set always correspond to different news items (`prnXX` identifiers).

The processing sequence for each set is:

1. Select one recording from each of the four speakers.
2. Verify that the four recordings correspond to different `prnXX` news items.
3. Remove the first **1 s** from each recording.
4. Remove the DC offset from each recording.
5. Calculate whole-file RMS.
6. Normalize the four recordings to the same RMS.
7. Determine the duration of the shortest recording.
8. Truncate all four recordings to this common duration.
9. Sum the four normalized recordings.
10. Save the resulting four-talker masker segment.

No silence detection or removal is performed.

The 36 resulting masker segments are kept independent at this stage. They are **not concatenated or independently normalized after mixing**.

## Initial trimming

Exactly **1 s** is removed from the beginning of every source recording.

This is intended to remove possible pre-reading silence, preparation noise, or inhalation before the newsreader begins speaking.

The operation is fixed and does not depend on the content of the recording. No automatic silence or voice-activity detection is performed.

For a recording sampled at `fs`:

```matlab
nTrimSamples = round(1.0 * fs);
x = x(nTrimSamples + 1:end);
```

## DC removal

After the initial trim, the DC offset is removed independently from each recording:

```matlab
x = x - mean(x);
```

This centers the waveform around zero before RMS calculation.

## RMS normalization

RMS is calculated over the complete remaining recording after the 1-s initial trim and DC removal:

```matlab
rmsBefore = sqrt(mean(x.^2));
```

Each recording is then scaled to the same target RMS:

```matlab
x = x .* (targetRMS / rmsBefore);
```

The current processing value is:

```matlab
targetRMS = 0.05;
```

This value provides digital headroom during summation. It does not define the experimental target-to-masker ratio (TMR).

The experimental TMR will be imposed later when target sentences are mixed with excerpts from the final continuous masker.

No robust RMS estimator, outlier removal, compression, or clipping is applied to the individual recordings.

## Assignment of news recordings

A central requirement is that speakers should not simultaneously read the same news item.

Therefore, a given four-talker set cannot contain the same `prnXX` identifier more than once.

The assignment also satisfies the following constraints:

1. Every set contains four different news recordings.
2. Every speaker contributes exactly one recording to each set.
3. Every `prn01`–`prn36` recording is used exactly once for each speaker.
4. No source recording is reused.

The current assignment is deterministic and uses circular shifts of:

```text
0, 9, 18, 27
```

for the four speakers.

For example:

```text
Set 01:
    sp_f11r_prn01.fix.wav
    sp_f13r_prn10.fix.wav
    sp_m12r_prn19.fix.wav
    sp_m14r_prn28.fix.wav

Set 02:
    sp_f11r_prn02.fix.wav
    sp_f13r_prn11.fix.wav
    sp_m12r_prn20.fix.wav
    sp_m14r_prn29.fix.wav
```

The MATLAB script automatically verifies that each set contains four different `prnXX` identifiers and that every speaker uses all 36 recordings exactly once.

This procedure avoids the need to introduce arbitrary temporal offsets between speakers.

## Duration matching

After initial trimming, DC removal, and RMS normalization, the four recordings within each set will generally differ slightly in duration.

For each set, the shortest recording determines the common duration:

```matlab
lengths = cellfun(@length, audioData);
minLength = min(lengths);
```

All four recordings are then truncated to this length:

```matlab
for s = 1:numel(speakers)
    audioData{s} = audioData{s}(1:minLength);
end
```

This guarantees that every sample in the resulting masker segment contains contributions from all four speakers.

## Four-talker mixture

After duration matching, the four normalized recordings are summed:

```matlab
mixture = zeros(minLength,1);

for s = 1:numel(speakers)
    mixture = mixture + audioData{s};
end
```

The resulting signal constitutes one four-talker masker segment.

The mixture RMS and peak absolute amplitude are recorded for quality control.

## Clipping control

The individual masker sets are **not automatically normalized after summation**.

Instead, the script checks whether the summed waveform reaches digital full scale:

```matlab
mixturePeak = max(abs(mixture));

if mixturePeak >= 1
    error('Potential clipping detected.');
end
```

If clipping occurs, processing stops rather than automatically changing the gain of that particular masker segment.

The appropriate response would be to reduce the common `targetRMS` and regenerate all masker sets using the same normalization procedure.

## Output files

The script creates 36 independent WAV files:

```text
masker_set_01.wav
masker_set_02.wav
masker_set_03.wav
...
masker_set_36.wav
```

The output WAV files are written at 32-bit depth.

## Processing log

The script additionally generates:

```text
masker_processing_log.csv
masker_processing_info.mat
```

The processing log records information including:

- masker-set number
- source recording used for each speaker
- `prnXX` identifier for each speaker
- original RMS of each source recording
- original peak amplitude of each source recording
- duration of each resulting four-talker segment
- RMS of each four-talker mixture
- peak amplitude of each four-talker mixture

The `.mat` file additionally stores the assignment matrix and processing parameters required to reproduce the masker construction.

## Validation checks

The MATLAB script automatically checks that:

- all expected source files exist
- all recordings are mono
- the four recordings within each set have different `prnXX` identifiers
- every speaker uses recordings `prn01`–`prn36` exactly once
- all four recordings within a set have the same sampling rate
- no recording has zero RMS
- the summed four-talker signal does not clip

Unexpected multichannel files or sampling-rate mismatches generate an error rather than being silently converted or resampled.
