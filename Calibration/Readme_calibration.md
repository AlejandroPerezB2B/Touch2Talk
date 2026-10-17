## Auditory calibration

The auditory calibration is implemented in PsychoPy using the script:

`adaptive_tmr_calibration_longmasker_1000ms.py`

The purpose of the calibration is to estimate, for each participant, the target-to-masker ratio (TMR) corresponding to approximately 60% correct identification of the sentence-final target word.

No vibrotactile stimulation is presented during the calibration.

### Required input files

The script asks the researcher to select:

- the folder containing the calibration sentence `.wav` files;
- the single continuous four-talker masker `.wav` file;
- the folder in which the calibration results should be saved;
- the participant ID.

All audio files used by the script are expected to have a sampling rate of 44.1 kHz.

The calibration sentence files are loaded into memory before the calibration begins. The continuous masker is also loaded into memory before the first trial.

### Calibration sentence order

The calibration sentences are presented in a fixed order. The order implemented in the PsychoPy script is:

1. `5.25.wav`
2. `5b.25.wav`
3. `1.1.wav`
4. `1b.1.wav`
5. `3b.6.wav`
6. `4.4.wav`
7. `3b.10.wav`
8. `3b.21.wav`
9. `2b.13.wav`
10. `1.19.wav`
11. `6b.15.wav`
12. `1.11.wav`
13. `1b.10.wav`
14. `3b.16.wav`
15. `5b.9.wav`
16. `5b.7.wav`
17. `6.15.wav`
18. `5.7.wav`
19. `4b.7.wav`
20. `1.10.wav`
21. `4.7.wav`
22. `2b.25.wav`
23. `5.8.wav`
24. `4.1.wav`
25. `6b.23.wav`
26. `2b.12.wav`
27. `2.13.wav`
28. `6.1.wav`
29. `6b.18.wav`
30. `6.23.wav`
31. `5.9.wav`
32. `1b.11.wav`
33. `2b.10.wav`
34. `5b.8.wav`
35. `3.16.wav`
36. `4b.1.wav`
37. `4.20.wav`
38. `6.18.wav`
39. `2.10.wav`
40. `1b.19.wav`
41. `4b.20.wav`
42. `2.12.wav`
43. `6b.1.wav`
44. `2.25.wav`

The preregistered staircase has a maximum duration of 40 trials. Therefore, within a single calibration attempt, only the first 40 files can be presented if the staircase reaches the maximum number of trials. Files 41–44 remain available as reserve calibration stimuli but are not reached within the current 40-trial stopping rule.

### Masker presentation

A single continuous four-talker masker is used.

For every trial, the script selects a segment from this continuous masker with a total duration equal to:

`1000 ms + target sentence duration + 1000 ms`

The temporal structure of each trial is therefore:

- the masker starts 1000 ms before target-sentence onset;
- the target sentence is presented while the masker continues;
- the masker remains present for 1000 ms after target-sentence offset.

A 500-ms raised-cosine ramp is applied at masker onset and masker offset:

- from 0 to 500 ms after masker onset, the masker amplitude increases smoothly from zero to its full level;
- from 500 to 1000 ms before target onset, the masker remains at its full level;
- after target offset, the masker remains at its full level for 500 ms;
- during the final 500 ms of the masker, its amplitude decreases smoothly to zero.

Thus, schematically:

```text
Masker onset
|
|---- 500 ms onset ramp ----|
|---- 500 ms full masker ---|
                             Target onset
                             |
                             |---- target sentence ----|
                                                      Target offset
                                                      |
                                                      |---- 500 ms full masker ---|
                                                      |---- 500 ms offset ramp ----|
                                                                                    Masker offset
```

### Definition and manipulation of TMR

The level of the masker remains fixed during the adaptive staircase.

The TMR is manipulated only by changing the amplitude of the target sentence.

The target sentence and the masker are first referenced to the same RMS level. Therefore, a TMR of 0 dB corresponds operationally to equal RMS levels for the target sentence and the masker during the target-sentence interval.

For a requested TMR, the target amplitude is multiplied by:

`10^(TMR_dB / 20)`

For example:

- 0 dB TMR corresponds to a target gain of 1.000;
- -2 dB TMR corresponds to a target gain of approximately 0.794;
- -4 dB TMR corresponds to a target gain of approximately 0.631;
- +3 dB TMR corresponds to a target gain of approximately 1.413.

A fixed master gain is subsequently applied equally to the complete target-plus-masker mixture to provide digital headroom. Because this gain is applied equally to both components, it does not change the TMR.

### Adaptive weighted up-down staircase

The calibration uses an adaptive weighted up-down staircase.

The staircase begins at:

`0 dB TMR`

During the initial phase:

- a correct response decreases the TMR by 2 dB;
- an incorrect response increases the TMR by 3 dB.

Therefore:

```text
Correct response   -> TMR - 2 dB
Incorrect response -> TMR + 3 dB
```

The 2:3 relationship between the downward and upward step sizes targets approximately 60% correct performance.

After the second reversal, the step sizes are reduced while preserving the same 1:1.5 relationship:

```text
Correct response   -> TMR - 1 dB
Incorrect response -> TMR + 1.5 dB
```

A correct response therefore makes the following trial more difficult, whereas an incorrect response makes the following trial easier.

### Definition of a reversal

A reversal is defined as a change in the direction of the staircase.

For example:

```text
0 dB   -> correct   -> -2 dB
-2 dB  -> correct   -> -4 dB
-4 dB  -> incorrect -> -1 dB
```

The response at `-4 dB` changes the staircase direction from decreasing TMR to increasing TMR. Therefore, `-4 dB` is recorded as a reversal point.

The TMR presented on the trial whose response produces the change in staircase direction is stored as the reversal TMR.

### Stopping rule

Each calibration attempt terminates when either:

- 8 reversals have occurred; or
- 40 trials have been completed;

whichever occurs first.

Thus:

```text
Maximum reversals = 8
Maximum trials    = 40
```

### Threshold estimation

A calibration attempt is considered successful if at least 6 reversals have occurred.

The participant-specific auditory threshold is calculated as the arithmetic mean of the final 6 reversal TMRs.

For example, if the final six reversal points were:

```text
-4.0 dB
-2.5 dB
-3.5 dB
-2.0 dB
-3.0 dB
-2.5 dB
```

the threshold would be:

```text
(-4.0 - 2.5 - 3.5 - 2.0 - 3.0 - 2.5) / 6
= -2.92 dB TMR
```

The first two reversals are therefore effectively excluded from the final threshold estimate when the staircase reaches eight reversals.

Formally:

`Threshold TMR = mean(final 6 reversal TMRs)`

This participant-specific TMR is the value intended to be used during the main experiment.

### Failed calibration

If fewer than 6 reversals have occurred after 40 trials, the calibration is repeated once.

If the second attempt again produces fewer than 6 reversals, calibration is considered unsuccessful and the participant should not proceed to the main experimental task.

The logic is therefore:

```text
Attempt 1
    |
    |-- >= 6 reversals -> calculate threshold -> calibration successful
    |
    |-- < 6 reversals  -> repeat calibration once
                              |
                              |-- >= 6 reversals -> calculate threshold -> successful
                              |
                              |-- < 6 reversals  -> calibration unsuccessful
```

### Participant response

During sound presentation, a fixation cross is displayed.

After the target sentence and the post-target masker have finished, the participant sees:

`RESPONDA AHORA`

The participant then says aloud the sentence-final word that they understood.

The researcher records the response using:

- `1` = correct;
- `0` = incorrect.

The researcher then presses `SPACE` to start the next trial.

`ESC` can be used to abort the calibration.

### Output files

For each calibration session, the script creates:

- a trial-by-trial `.csv` file;
- a `.json` summary file.

The trial-level CSV contains information including:

- participant ID;
- calibration attempt;
- trial number;
- sentence filename;
- TMR presented;
- whether the response was correct;
- staircase direction;
- whether the trial was a reversal;
- reversal number;
- reversal TMR;
- downward and upward step sizes;
- TMR selected for the following trial;
- position of the selected segment within the continuous masker;
- target duration;
- complete trial duration;
- target gain;
- peak amplitude of the generated mixture;
- timestamp.

The summary JSON stores information including:

- participant ID;
- calibration parameters;
- fixed sentence order;
- staircase parameters;
- reversal TMRs;
- final six reversal TMRs;
- number of trials;
- number of reversals;
- whether calibration was successful;
- final participant-specific TMR.

### Summary of the calibration procedure

```text
Start at 0 dB TMR

Masker:
    1000 ms before target onset
    continues throughout target
    1000 ms after target offset

Masker ramps:
    first 500 ms  -> raised-cosine onset ramp
    final 500 ms  -> raised-cosine offset ramp

Initial staircase:
    correct   -> -2 dB
    incorrect -> +3 dB

After reversal 2:
    correct   -> -1 dB
    incorrect -> +1.5 dB

Stop:
    8 reversals
    OR
    40 trials

Successful calibration:
    at least 6 reversals

Threshold:
    mean of final 6 reversal TMRs

If attempt 1 has fewer than 6 reversals:
    repeat once

If attempt 2 also has fewer than 6 reversals:
    calibration unsuccessful
```
