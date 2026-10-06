### `create_target_sentence_manifest.m`

Validates the original Spanish target-sentence audio corpus and creates the manifests used in subsequent stimulus preparation.

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