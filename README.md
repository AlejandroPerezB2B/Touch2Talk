# Touch2Talk

## Speech-derived haptic stimulation and speech perception

This repository contains the stimulus-processing code, and analysis resources developed for a submitted Registered Report (Stage 1) investigating whether speech-derived vibrotactile stimulation can influence speech-in-noise perception and cortical speech tracking. The study compares vibrotactile stimulation delivered at different body sites while manipulating the contextual predictability of Spanish target sentences.

The experimental approach builds on previous work showing that vibrotactile signals derived from the temporal envelope of speech can support speech perception in multi-talker noise (Răutu et al., 2023).

The pre-print associated with this project is archived on Zenodo **[doi:10.5281/zenodo.23159385](https://doi.org/10.5281/zenodo.23159385)**.

## Main PsychoPy experiment

The main experiment is implemented in PsychoPy using the script:

`main_haptic_experiment_no_questions.py`

The experiment contains three fixed blocks of 84 trials each, for a total of 252 trials.

The three blocks correspond to the Excel sheets:

- `List1`
- `List2`
- `List3`

contained in:

`haptic_stimulus_lists.xlsx`

The order of the trials within each block is fixed and follows the order specified in the corresponding Excel sheet.

No comprehension questions are presented in the current version of the experiment.

---

### Experimental conditions and counterbalancing

There are three experimental conditions:

- `Lip`
- `Fingertip`
- `No stimulation`

Six counterbalancing versions determine which condition is assigned to each of the three blocks.

The condition assignment is read automatically from the `ConditionOrders` sheet of `haptic_stimulus_lists.xlsx`.

The experimenter selects the participant's counterbalancing version, from 1 to 6, when launching the experiment.

The condition associated with each block is therefore determined automatically from:

`participant version + block number`

The same digital haptic signal is used for the `Lip` and `Fingertip` conditions. The difference between these conditions is the physical stimulation site.

For `No stimulation` blocks, the second audio channel contains digital zeros for the complete duration of the trial.

---

### Information entered at experiment startup

At startup, the program asks for:

- participant ID;
- condition-order version (`1–6`);
- participant-specific TMR obtained during auditory calibration.

The TMR must be entered with its sign.

For example:

`-3.5`

or:

`+2.0`

The entered TMR remains fixed throughout all three experimental blocks.

---

### Required files and folders

The program asks the experimenter to locate the following files and folders.

#### Experimental-list workbook

The experimenter selects:

`haptic_stimulus_lists.xlsx`

This workbook must contain the following sheets:

- `List1`
- `List2`
- `List3`
- `ConditionOrders`

Each of the three stimulus-list sheets must contain 84 trials.

The program expects the following columns:

- `Trial`
- `Code`
- `Sentence`
- `Predictability`
- `TargetFamily`
- `SentenceNumber`
- `SimplifiedFilename`

The `ConditionOrders` sheet determines the stimulation condition associated with each block for each counterbalancing version.

---

### Target-sentence folder

The target-sentence folder must be named exactly:

`PsychoPy_target_audio_44100Hz`

The program explicitly asks the experimenter to select the folder named:

`PsychoPy_target_audio_44100Hz`

If a folder with a different name is selected, the experiment stops and reports the error.

The folder contains the `.wav` files corresponding to the `SimplifiedFilename` values in the experimental lists.

All target audio files must have a sampling rate of:

`44100 Hz`

---

### Haptic-signal folder

The haptic-signal folder must be named exactly:

`haptic_wav`

The program explicitly asks the experimenter to select the folder named:

`haptic_wav`

The haptic file corresponding to each target sentence is identified automatically.

For example:

```text
Target:
5.25.wav

Haptic:
5.25_haptic150.wav
```

The haptic signal is the previously generated speech-derived amplitude envelope modulating a 150-Hz sinusoidal carrier.

All haptic files must have a sampling rate of:

`44100 Hz`

---

### Continuous four-talker masker

The experimenter selects one continuous four-talker masker `.wav` file.

For every experimental trial, the program randomly selects a segment from this continuous masker.

The selected masker segment has a duration equal to:

`1000 ms + target sentence duration + 1000 ms`

The exact starting sample of the masker segment is stored in the experimental log so that the presented stimulus can be reconstructed later.

---

### Response beep

The experimenter selects the response-beep `.wav` file.

The beep is presented after the masker has completely finished.

The beep is sent only through the auditory output channel.

The haptic output channel contains zeros during the beep.

---

### Output folder

The experimenter selects a folder where the experimental results will be saved.

A separate session folder is automatically created using the participant ID, counterbalancing version, and date/time.

For example:

```text
P001_V02_20261017_180000
```

Within the session folder, the program creates a subfolder:

`spoken_responses`

containing one microphone recording for every experimental trial.

---

## Trial timing

The fixation cross appears before the auditory stimulus and remains on screen during the auditory presentation.

The temporal structure of every trial is:

```text
Fixation cross

        500 ms

Masker onset
|
|---- 500 ms raised-cosine onset ramp ----|
|
|---- 500 ms full-level masker -----------|
|
Target sentence onset
Haptic signal onset
EEG target trigger
|
|---- target sentence duration -----------|
|---- haptic signal duration -------------|
|
Target sentence offset
Haptic signal offset
|
|---- 500 ms full-level masker -----------|
|
|---- 500 ms raised-cosine offset ramp ---|
|
Masker offset

Response beep

Beep offset

Microphone recording
|
|---- exactly 3000 ms --------------------|

3000-ms inter-trial interval

Next trial
```

---

### Fixation period

A fixation cross is presented for:

`500 ms`

before the masker begins.

The fixation remains visible throughout the auditory part of the trial.

---

### Masker timing

The masker begins:

`1000 ms`

before target-sentence onset.

The first 500 ms of the masker contains a raised-cosine onset ramp.

Therefore:

```text
0–500 ms:
    raised-cosine onset ramp

500–1000 ms:
    masker at full level

1000 ms:
    target sentence begins
```

After the target sentence ends, the masker continues for another:

`1000 ms`

with:

```text
first 500 ms:
    masker at full level

final 500 ms:
    raised-cosine offset ramp
```

Thus, the masker always starts 1000 ms before target onset and terminates 1000 ms after target offset.

---

## Stereo stimulus structure

The main experimental stimulus is generated as a stereo waveform.

### Channel 1: auditory stimulation

Channel 1 contains:

`four-talker masker + target sentence`

The target sentence is presented at the participant-specific TMR obtained during calibration.

### Channel 2: haptic stimulation

For `Lip` and `Fingertip` blocks, Channel 2 contains:

`*_haptic150.wav`

For `No stimulation` blocks, Channel 2 contains:

`digital zeros`

of exactly the same duration as Channel 1.

The target and haptic signals begin at exactly the same sample.

At 44.1 kHz, target and haptic onset occur:

`44100 samples`

after masker onset, corresponding to exactly:

`1000 ms`

---

## Audio routing

The intended stereo routing is:

```text
PsychoPy stereo output

Channel 1
    |
    audio interface output 1
    |
    connector
    |
    StimTrak
    |
    headphones / auditory chain

Channel 2
    |
    audio interface output 2
    |
    connector
    |
    tactor
```

For `Lip` and `Fingertip`, the signal sent through Channel 2 is digitally identical.

The physical position of the tactor determines whether stimulation is applied to the upper lip or fingertips.

---

## Definition and use of TMR

The participant-specific target-to-masker ratio is obtained during the preceding auditory calibration.

The signed TMR value is entered once when launching the main experiment and remains unchanged throughout the entire experiment.

The masker establishes the fixed auditory reference level.

The target sentence is scaled according to:

`target_gain = 10^(TMR_dB / 20)`

For example:

- `0 dB` corresponds to a target gain of `1.000`;
- `-2 dB` corresponds to a target gain of approximately `0.794`;
- `-4 dB` corresponds to a target gain of approximately `0.631`;
- `+3 dB` corresponds to a target gain of approximately `1.413`.

A negative TMR therefore makes the target sentence quieter than the masker.

A positive TMR makes the target sentence louder than the masker.

The sign of the participant-specific calibration value must therefore be preserved when entering it into the program.

---

### RMS reference

The auditory signal uses the same reference-level logic as the calibration program.

The target and masker are referenced to:

`-30 dBFS RMS`

The masker level remains fixed.

The target sentence is first normalized to the same RMS reference and is then multiplied by the participant-specific TMR gain.

A fixed auditory master gain of:

`0.70`

is subsequently applied to the complete auditory mixture to provide digital headroom.

Because the same final gain is applied to the entire Channel 1 mixture, the intended TMR is preserved.

The program also checks the resulting auditory peak and stops if digital clipping is detected.

---

## Haptic timing

The haptic signal is synchronized with the target sentence.

Both begin at exactly:

`1000 ms after masker onset`

and therefore have sample-identical onset timing.

The haptic waveform is inserted into Channel 2 at the same sample at which the target sentence is inserted into Channel 1.

If necessary, the haptic signal is cropped or zero-padded at its end so that its duration corresponds to the duration of the target sentence.

Its onset is never shifted.

For `No stimulation` trials, the same Channel 2 structure is retained but all samples are zero.

---

## Response procedure

After the masker has completely ended, the response beep is presented.

The temporal sequence is:

```text
Masker offset
    |
Response beep onset
    |
Response beep offset
    |
Microphone recording begins
```

The microphone therefore begins recording only after the response beep has ended.

The participant is instructed to repeat aloud the final word of the sentence, even when unsure of the answer.

During the response-recording period, the screen displays:

`REPITA EN VOZ ALTA LA ÚLTIMA PALABRA`

---

## Microphone recording

The program uses the default Windows audio-input device.

Each spoken response is recorded as:

- mono;
- 44.1 kHz;
- exactly 3.000 seconds.

The recording always lasts the complete 3 seconds, irrespective of how quickly the participant responds.

One separate `.wav` file is created for every trial.

Example filename:

```text
P001_V02_B01_T017_5.25_response.wav
```

The filename identifies:

- participant;
- counterbalancing version;
- block;
- trial;
- target stimulus.

The recordings are saved inside the session's:

`spoken_responses`

folder.

---

## Inter-trial interval

After the 3-second microphone recording ends, the experiment enters a:

`3000 ms`

inter-trial interval.

A fixation cross is shown during this period.

The next trial then begins automatically.

---

## Block structure

The experiment contains three blocks:

```text
Block 1 = List1
Block 2 = List2
Block 3 = List3
```

Each block contains:

`84 trials`

for a total of:

`252 trials`

The trial order within every list is fixed.

---

## Block rest screen

Before each block, a rest/condition screen is displayed.

Both the participant and the experimenter can see the stimulation condition.

For example:

```text
BLOQUE 2 DE 3

CONDICIÓN: YEMAS DE LOS DEDOS

Descanse el tiempo que necesite.

Avise al experimentador cuando esté preparado para continuar.

Pulse ESPACIO para continuar.
```

The Spanish condition labels are:

```text
Lip
    -> LABIO SUPERIOR

Fingertip
    -> YEMAS DE LOS DEDOS

No stimulation
    -> SIN ESTIMULACIÓN
```

The block does not begin until `SPACE` is pressed.

This allows the participant to rest and allows the experimenter to prepare or reposition the tactor when necessary.

---

## EEG trigger coding

Every target sentence has one unique EEG event code.

The mapping is:

```text
List1:
    triggers 1–84

List2:
    triggers 85–168

List3:
    triggers 169–252
```

Therefore, the trigger code uniquely identifies the exact target stimulus irrespective of the stimulation condition.

For example:

```text
List1, trial 1
    -> trigger 1

List1, trial 84
    -> trigger 84

List2, trial 1
    -> trigger 85

List2, trial 84
    -> trigger 168

List3, trial 1
    -> trigger 169

List3, trial 84
    -> trigger 252
```

The stimulation condition can subsequently be reconstructed from:

`participant version + block`

because the selected counterbalancing version determines whether the corresponding block was:

- Lip;
- Fingertip;
- No stimulation.

The behavioural log stores the trigger, target identity, participant version, block, and condition together explicitly.

---

## EEG trigger timing

The EEG event corresponds to target-sentence onset.

The trigger is therefore associated with the same temporal event as:

- target-sentence onset on Channel 1;
- haptic-signal onset on Channel 2.

This occurs:

`1000 ms after masker onset`

or:

`44100 samples after masker onset`

at a sampling rate of 44.1 kHz.

---

## Brain Products TriggerBox

Physical TriggerBox communication has not yet been configured.

The hardware communication is deliberately isolated in the function:

`send_eeg_trigger()`

The current script uses:

`TRIGGER_MODE = "test"`

In test mode, the program prints/logs the trigger value but does not send a hardware command.

For example:

```text
[EEG TEST] trigger 137
```

Once the exact Brain Products TriggerBox interface is known, only the hardware branch of `send_eeg_trigger()` needs to be modified.

The remainder of the experimental program does not need to change.

---

## Trigger mapping file

The experiment automatically creates a trigger-mapping CSV.

This file associates each trigger value with information including:

- trigger code;
- block;
- list;
- trial within block;
- stimulus code;
- target filename;
- predictability condition;
- target family;
- sentence number.

This provides an explicit permanent mapping between EEG markers and experimental stimuli.

---

## Random masker selection

A masker excerpt is selected randomly on every trial.

The random start position within the continuous four-talker masker is stored as:

- masker start sample;
- masker start time in seconds.

The experiment also uses a stored random seed so that the randomization can be reconstructed if necessary.

---

## Trial-level data file

The experiment creates a trial-by-trial CSV file.

The saved variables include:

- `participant_id`
- `version`
- `tmr_db`
- `block`
- `list`
- `condition`
- `trial_in_block`
- `global_trial`
- `trigger_code`
- `code`
- `target_file`
- `haptic_file`
- `predictability`
- `target_family`
- `sentence_number`
- `haptic_present`
- `masker_start_sample`
- `masker_start_s`
- `target_onset_sample`
- `target_onset_s`
- `target_duration_s`
- `trial_audio_duration_s`
- `target_gain_linear`
- `auditory_peak`
- `haptic_peak`
- `trigger_mode`
- `trigger_perf_time_s`
- `response_file`
- `response_recording_samples`
- `response_recording_duration_s`
- `response_recording_peak`
- `timestamp`

This makes it possible to reconstruct the exact experimental state associated with every trial.

---

## Session metadata

The program also saves session-level metadata including:

- participant ID;
- counterbalancing version;
- participant-specific TMR;
- random seed;
- input-file locations;
- experimental timing parameters;
- condition assigned to each block;
- audio reference settings;
- EEG trigger mode;
- output locations.

---

## Summary of one experimental trial

```text
Fixation
    |
    500 ms
    |
Masker begins
    |
    500-ms raised-cosine onset ramp
    |
    500 ms full masker
    |
Target begins on Channel 1
Haptic begins on Channel 2
EEG target trigger occurs
    |
Target + haptic duration
    |
Target ends
Haptic ends
    |
500 ms full masker
    |
500-ms raised-cosine offset ramp
    |
Masker ends
    |
Response beep
    |
Beep ends
    |
3-s microphone recording
    |
Spoken response WAV saved
    |
3-s ITI
    |
Next trial
```

---

## Summary of the experiment

```text
START

Enter:
    participant ID
    condition-order version (1–6)
    signed participant-specific TMR

Select:
    haptic_stimulus_lists.xlsx
    PsychoPy_target_audio_44100Hz
    haptic_wav
    continuous four-talker masker
    response beep
    results folder

Load:
    List1
    List2
    List3
    ConditionOrders
    target audio
    haptic audio
    long masker
    response beep

Create:
    trigger mapping
    session folder
    spoken-response folder

BLOCK 1 / List1
    show condition/rest screen
    84 fixed-order trials

REST / condition screen

BLOCK 2 / List2
    84 fixed-order trials

REST / condition screen

BLOCK 3 / List3
    84 fixed-order trials

For every trial:
    choose random masker excerpt
    apply participant-specific fixed TMR
    construct stereo auditory/haptic waveform
    present masker
    present target + haptic simultaneously
    log/send unique target trigger
    finish masker
    play response beep
    record microphone for 3 s
    save spoken response
    wait 3-s ITI
    continue

END

Save:
    trial CSV
    session metadata
    trigger mapping
    252 individual spoken-response WAV files
```
