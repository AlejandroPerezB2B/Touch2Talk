#### Preparation of the Spanish target speech stimuli

The target sentences used in this project are based on the Spanish Speech Perception in Noise (SPIN) materials developed by Cervera and González-Alvarez (2010), available from the original [SPIN website](https://www.uv.es/~cervera/SPIN.htm).

The file [Nombres archivos audio_2026_10_06.doc](Nombres%20archivos%20audio_2026_10_06.doc), is an annotated and corrected version of the original sentence list. In this document:

- Red text identifies sentences for which the corresponding recordings were missing from the original clean speech audio archive.\
- Bold text identifies an inconsistency in which the high-predictability and low-predictability versions of a sentence pair do not share the same final target word (5.25 and 5b.25: monje versus metal).

Additional inconsistencies in the stimulus identification codes were corrected but are not individually marked.

Further inspection of the original audio recordings revealed additional issues, including differences in sampling rates (16 kHz and 44.1 kHz) and recordings containing clipped speech segments. Consequently, we decided to generate a new audio version of the Spanish sentences using Google Cloud Text-to-Speech, with the Spanish (es) language setting and a female synthetic voice.

The newly generated target speech recordings will be made available in a separate dataset:

Target speech stimuli dataset — link to be added

Importantly, the experimental stimulus lists had already been constructed based on the availability and structure of the original Cervera and González-Alvarez recordings. To preserve the established stimulus allocation and counterbalancing scheme, the four sentences missing from the original audio archive (3.6, 3.10, 3.21, and 4b.4) remain excluded from the main experiment, even though a new synthetic audio version could be generated. Their four corresponding available counterparts (3b.6, 3b.10, 3b.21, and 4.4) are used exclusively for auditory calibration.

Similarly, the sentence pair containing the mismatched final target words (5.25 and 5b.25) is retained in its original textual form but reserved exclusively for calibration rather than the main experiment.

The final allocation comprises 252 experimental sentences (126 high-predictability and 126 low-predictability) distributed across three balanced lists of 84 trials, together with 44 additional sentences reserved for auditory calibration. This preserves the original experimental design and counterbalancing structure while using newly synthesised, consistently prepared speech recordings.

### `create_target_sentence_manifest.m`

Validates the original Spanish target-sentence audio corpus (https://www.uv.es/~cervera/SPIN.htm) and creates the manifests used in subsequent stimulus preparation.

The script:

- Scans the six original `FORMA` directories and parses the stimulus codes from the WAV filenames.
- Checks the expected physical-form, target-family, and high- vs. low-predictability (HP/LP) structure.
- Verifies the four known missing recordings: `3.6`, `4b.4`, `3.10`, and `3.21`.
- Identifies the corresponding surviving unpaired recordings: `3b.6`, `4.4`, `3b.10`, and `3b.21`.
- Reconstructs and validates the HP–LP target pairs across physical forms.
- Confirms that the corpus contains **296 existing WAV files**, comprising **146 complete HP–LP pairs (292 recordings)** plus **4 unpaired recordings**.
- Records audio metadata, including sample rate, number of channels, and duration. The source corpus contains recordings at **16 kHz and 44.1 kHz**, all mono.
- Generates CSV and MATLAB manifests describing the complete corpus, valid HP–LP pairs, excluded/incomplete pairs, and summary information for each physical `FORMA`.

This script performs **validation and documentation only**. It does not modify, resample, normalize, rename, move, or copy the original audio files.

### `prepare_target_audio_common_folder.m`

Prepares the validated Spanish target-sentence recordings for use in the PsychoPy experiment by creating a single, standardized audio directory.

The function:

- Reads the WAV files from the six original `FORMA` directories.
- Verifies that the expected **296 existing recordings** are present and that the four known missing recordings (`3.6`, `4b.4`, `3.10`, and `3.21`) remain absent.
- Extracts the stimulus code from each original filename and checks that all codes are unique.
- Standardizes all recordings to **44.1 kHz, mono**. Recordings already at 44.1 kHz are retained at their original sampling rate, while 16-kHz recordings are resampled to 44.1 kHz.
- Does **not** normalize, trim, or otherwise intentionally alter the amplitude or duration of the stimuli.
- Copies the processed recordings to a common PsychoPy-ready directory while simplifying the filenames by removing the original physical item-number prefix. For example:

  `17 - 3.9.wav` → `3.9.wav`

- Performs post-processing checks on sample rate, channel count, duration, RMS, and peak amplitude.
- Generates [haptic_stimulus_lists.xlsx](`target_audio_processing_log.csv`), which preserves the relationship between each original file and its processed version and records the relevant audio-processing information.

The original corpus is left **untouched**. The resulting directory contains the standardized and uniquely named WAV files required by the experimental and calibration stimulus lists.
