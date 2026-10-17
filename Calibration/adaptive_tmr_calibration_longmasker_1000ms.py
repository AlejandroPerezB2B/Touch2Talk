# -*- coding: utf-8 -*-
"""
adaptive_tmr_calibration_longmasker.py

Auditory calibration for the haptic entrainment experiment.

Design:
- Fixed calibration-sentence order.
- One pre-built continuous four-talker masker.
- Masker begins 1000 ms before target onset.
- Masker ends 1000 ms after target offset.
- 500-ms raised-cosine masker onset and offset ramps.
- Masker level remains fixed across trials.
- TMR is manipulated only by changing target level.
- RA scores spoken response: 1 = correct, 0 = incorrect.
- No vibrotactile stimulation.
"""

from pathlib import Path
from datetime import datetime
import csv
import json
import random
import secrets
import traceback
import tkinter as tk
from tkinter import filedialog

import numpy as np
from scipy.io import wavfile

from psychopy import prefs
prefs.hardware["audioLib"] = ["ptb"]

from psychopy import core, event, gui, sound, visual

FS = 44100
START_TMR_DB = 0.0
INITIAL_DOWN_DB = 2.0
INITIAL_UP_DB = 3.0
LATE_DOWN_DB = 1.0
LATE_UP_DB = 1.5
STEP_CHANGE_AFTER_REVERSALS = 2
MAX_REVERSALS = 8
MAX_TRIALS = 40
REVERSALS_FOR_THRESHOLD = 6
PRE_MASKER_S = 1.000
POST_MASKER_S = 1.000
RAMP_S = 0.500
REFERENCE_RMS_DBFS = -30.0
MASTER_GAIN = 0.70

CALIBRATION_ORDER = [
    "5.25", "5b.25", "1.1", "1b.1", "3b.6", "4.4", "3b.10", "3b.21",
    "2b.13", "1.19", "6b.15", "1.11", "1b.10", "3b.16", "5b.9", "5b.7",
    "6.15", "5.7", "4b.7", "1.10", "4.7", "2b.25", "5.8", "4.1",
    "6b.23", "2b.12", "2.13", "6.1", "6b.18", "6.23", "5.9", "1b.11",
    "2b.10", "5b.8", "3.16", "4b.1", "4.20", "6.18", "2.10", "1b.19",
    "4b.20", "2.12", "6b.1", "2.25"
]


def db_to_amp(db):
    return 10.0 ** (float(db) / 20.0)


def rms(x):
    x = np.asarray(x, dtype=np.float64)
    return float(np.sqrt(np.mean(x * x)))


def to_float(data):
    if np.issubdtype(data.dtype, np.floating):
        return data.astype(np.float64)
    if data.dtype == np.int16:
        return data.astype(np.float64) / 32768.0
    if data.dtype == np.int32:
        return data.astype(np.float64) / 2147483648.0
    if data.dtype == np.uint8:
        return (data.astype(np.float64) - 128.0) / 128.0
    raise TypeError(f"Unsupported WAV dtype: {data.dtype}")


def make_mono(x):
    x = np.asarray(x)
    if x.ndim == 1:
        return x.astype(np.float64)
    if x.ndim == 2:
        return np.mean(x, axis=1).astype(np.float64)
    raise ValueError(f"Unexpected audio shape: {x.shape}")


def read_wav(path):
    fs, data = wavfile.read(str(path))
    if fs != FS:
        raise RuntimeError(f"{path.name} is {fs} Hz; expected {FS} Hz.")
    x = make_mono(to_float(data))
    if len(x) == 0:
        raise RuntimeError(f"{path.name} is empty.")
    if rms(x) == 0:
        raise RuntimeError(f"{path.name} is silent.")
    return x


def raised_cosine(n_samples):
    if n_samples <= 1:
        return np.ones(max(1, n_samples), dtype=np.float64)
    return 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n_samples))


def choose_folder(title):
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    folder = filedialog.askdirectory(title=title)
    root.destroy()
    return Path(folder) if folder else None


def choose_file(title):
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    filename = filedialog.askopenfilename(
        title=title,
        filetypes=[("WAV audio", "*.wav"), ("All files", "*.*")],
    )
    root.destroy()
    return Path(filename) if filename else None


def startup():
    dlg = gui.Dlg(title="Auditory calibration")
    dlg.addField("Participant ID:")
    values = dlg.show()
    if not dlg.OK or values is None:
        return None
    participant_id = str(values[0]).strip()
    if not participant_id:
        return None

    sentence_folder = choose_folder(
        "Select folder containing calibration sentence WAV files"
    )
    if sentence_folder is None:
        return None

    masker_file = choose_file(
        "Select the single continuous four-talker masker WAV file"
    )
    if masker_file is None:
        return None

    output_folder = choose_folder(
        "Select folder where calibration results will be saved"
    )
    if output_folder is None:
        return None

    return participant_id, sentence_folder, masker_file, output_folder


def preload_audio(sentence_folder, masker_file):
    sentence_audio = {}
    missing = []

    for stem in CALIBRATION_ORDER:
        path = sentence_folder / f"{stem}.wav"
        if not path.exists():
            missing.append(path.name)
            continue
        sentence_audio[stem] = read_wav(path)

    if missing:
        raise RuntimeError(
            "Missing calibration sentence file(s):\n" + "\n".join(missing)
        )

    long_masker = read_wav(masker_file)

    if len(CALIBRATION_ORDER) > MAX_TRIALS:
        print(
            f"NOTE: {len(CALIBRATION_ORDER)} calibration items are defined, "
            f"but MAX_TRIALS={MAX_TRIALS}. Therefore at most the first "
            f"{MAX_TRIALS} items can be presented in one staircase attempt."
        )

    return sentence_audio, long_masker


def build_trial(target, long_masker, tmr_db, rng):
    pre_n = int(round(PRE_MASKER_S * FS))
    post_n = int(round(POST_MASKER_S * FS))
    ramp_n = int(round(RAMP_S * FS))

    target_n = len(target)
    total_n = pre_n + target_n + post_n

    if len(long_masker) < total_n:
        raise RuntimeError("The continuous masker is shorter than the required trial.")

    max_start = len(long_masker) - total_n
    masker_start = rng.randint(0, max_start) if max_start > 0 else 0
    masker = long_masker[masker_start:masker_start + total_n].copy()

    overlap = masker[pre_n:pre_n + target_n]
    reference_rms = db_to_amp(REFERENCE_RMS_DBFS)
    masker_rms = rms(overlap)
    if masker_rms == 0:
        raise RuntimeError("Selected masker segment has zero RMS.")
    masker *= reference_rms / masker_rms

    ramp = raised_cosine(ramp_n)
    masker[:ramp_n] *= ramp
    masker[-ramp_n:] *= ramp[::-1]

    target_rms = rms(target)
    if target_rms == 0:
        raise RuntimeError("Target sentence has zero RMS.")
    target_norm = target * (reference_rms / target_rms)

    target_gain = db_to_amp(tmr_db)
    target_scaled = target_norm * target_gain

    target_pad = np.zeros(total_n, dtype=np.float64)
    target_pad[pre_n:pre_n + target_n] = target_scaled

    mixture = (masker + target_pad) * MASTER_GAIN
    peak = float(np.max(np.abs(mixture)))
    if peak >= 1.0:
        raise RuntimeError(
            f"Digital clipping risk: mixture peak={peak:.3f}. "
            "Reduce MASTER_GAIN or REFERENCE_RMS_DBFS."
        )

    stereo = np.column_stack((mixture, mixture))

    return stereo, {
        "masker_start_sample": int(masker_start),
        "masker_start_s": float(masker_start / FS),
        "target_duration_s": float(target_n / FS),
        "trial_duration_s": float(total_n / FS),
        "target_gain_linear": float(target_gain),
        "mixture_peak": peak,
    }


def wait_screen(win, text, keys=("space",), color="white"):
    stim = visual.TextStim(
        win,
        text=text,
        color=color,
        height=0.045,
        wrapWidth=1.6,
        alignText="center",
    )
    stim.draw()
    win.flip()
    pressed = event.waitKeys(keyList=list(keys) + ["escape"])
    key = pressed[0]
    if key == "escape":
        raise KeyboardInterrupt
    return key


def instructions(win):
    wait_screen(
        win,
        "CALIBRACIÓN AUDITIVA\n\n"
        "Escuchará frases con ruido de fondo.\n\n"
        "Después de cada frase, diga EN VOZ ALTA la última palabra "
        "que haya entendido.\n\n"
        "Espere a que aparezca «RESPONDA AHORA» antes de responder.\n\n"
        "Pulse ESPACIO para comenzar."
    )


def collect_score(win):
    key = wait_screen(
        win,
        "RESPONDA AHORA\n\n"
        "Diga en voz alta la última palabra que ha entendido.\n\n\n"
        "RA: 1 = CORRECTA     0 = INCORRECTA",
        keys=("1", "0"),
    )
    return key == "1"


def staircase_steps(n_reversals):
    if n_reversals < STEP_CHANGE_AFTER_REVERSALS:
        return INITIAL_DOWN_DB, INITIAL_UP_DB
    return LATE_DOWN_DB, LATE_UP_DB


def append_trial(csv_path, fieldnames, row):
    exists = csv_path.exists()
    with csv_path.open("a", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if not exists:
            writer.writeheader()
        writer.writerow(row)


def run_attempt(win, participant_id, attempt_number, sentence_audio,
                long_masker, rng, csv_path):
    current_tmr = START_TMR_DB
    previous_direction = None
    reversal_tmrs = []

    fieldnames = [
        "participant_id", "attempt", "trial", "sentence_file",
        "tmr_db_presented", "correct", "direction", "reversal",
        "reversal_number", "reversal_tmr_db", "down_step_db", "up_step_db",
        "next_tmr_db", "masker_start_sample", "masker_start_s",
        "target_duration_s", "trial_duration_s", "target_gain_linear",
        "mixture_peak", "timestamp"
    ]

    n_trials_completed = 0

    for trial_number in range(1, MAX_TRIALS + 1):
        stem = CALIBRATION_ORDER[trial_number - 1]
        target = sentence_audio[stem]

        print(
            f"Preparing trial {trial_number}: {stem}.wav "
            f"at {current_tmr:.2f} dB TMR"
        )

        mixture, meta = build_trial(target, long_masker, current_tmr, rng)

        print(
            f"  duration={meta['trial_duration_s']:.3f} s; "
            f"peak={meta['mixture_peak']:.3f}"
        )

        trial_sound = sound.Sound(
            value=mixture,
            sampleRate=FS,
            stereo=True,
            hamming=False,
        )

        fixation = visual.TextStim(win, text="+", color="white", height=0.08)
        fixation.draw()
        win.flip()

        trial_sound.play()
        core.wait(meta["trial_duration_s"])
        trial_sound.stop()

        correct = collect_score(win)
        direction = "down" if correct else "up"

        reversal = (
            previous_direction is not None and direction != previous_direction
        )

        reversal_tmr = ""
        if reversal:
            reversal_tmrs.append(float(current_tmr))
            reversal_tmr = float(current_tmr)

        n_reversals = len(reversal_tmrs)
        down_step, up_step = staircase_steps(n_reversals)

        if correct:
            next_tmr = current_tmr - down_step
        else:
            next_tmr = current_tmr + up_step

        row = {
            "participant_id": participant_id,
            "attempt": attempt_number,
            "trial": trial_number,
            "sentence_file": f"{stem}.wav",
            "tmr_db_presented": float(current_tmr),
            "correct": int(correct),
            "direction": direction,
            "reversal": int(reversal),
            "reversal_number": n_reversals if reversal else "",
            "reversal_tmr_db": reversal_tmr,
            "down_step_db": float(down_step),
            "up_step_db": float(up_step),
            "next_tmr_db": float(next_tmr),
            "masker_start_sample": meta["masker_start_sample"],
            "masker_start_s": meta["masker_start_s"],
            "target_duration_s": meta["target_duration_s"],
            "trial_duration_s": meta["trial_duration_s"],
            "target_gain_linear": meta["target_gain_linear"],
            "mixture_peak": meta["mixture_peak"],
            "timestamp": datetime.now().isoformat(timespec="seconds"),
        }

        append_trial(csv_path, fieldnames, row)

        previous_direction = direction
        current_tmr = next_tmr
        n_trials_completed = trial_number

        if n_reversals >= MAX_REVERSALS:
            break

        wait_screen(win, "Pulse ESPACIO para continuar.")

    successful = len(reversal_tmrs) >= REVERSALS_FOR_THRESHOLD

    if successful:
        final_six = reversal_tmrs[-REVERSALS_FOR_THRESHOLD:]
        threshold = float(np.mean(final_six))
    else:
        final_six = []
        threshold = None

    return {
        "attempt": attempt_number,
        "successful": successful,
        "n_trials": n_trials_completed,
        "n_reversals": len(reversal_tmrs),
        "reversal_tmrs_db": reversal_tmrs,
        "final_six_reversal_tmrs_db": final_six,
        "threshold_tmr_db": threshold,
    }


def main():
    info = startup()
    if info is None:
        print("Calibration cancelled.")
        return

    participant_id, sentence_folder, masker_file, output_folder = info
    output_folder.mkdir(parents=True, exist_ok=True)

    try:
        sentence_audio, long_masker = preload_audio(sentence_folder, masker_file)
    except Exception:
        traceback.print_exc()
        raise

    random_seed = secrets.randbits(32)
    rng = random.Random(random_seed)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base = f"{participant_id}_calibration_{timestamp}"
    csv_path = output_folder / f"{base}_trials.csv"
    summary_path = output_folder / f"{base}_summary.json"

    summary = {
        "participant_id": participant_id,
        "sentence_folder": str(sentence_folder),
        "masker_file": str(masker_file),
        "random_seed": random_seed,
        "sentence_order": CALIBRATION_ORDER,
        "max_trials": MAX_TRIALS,
        "max_reversals": MAX_REVERSALS,
        "threshold_reversals": REVERSALS_FOR_THRESHOLD,
        "start_tmr_db": START_TMR_DB,
        "initial_down_db": INITIAL_DOWN_DB,
        "initial_up_db": INITIAL_UP_DB,
        "late_down_db": LATE_DOWN_DB,
        "late_up_db": LATE_UP_DB,
        "step_change_after_reversals": STEP_CHANGE_AFTER_REVERSALS,
        "pre_masker_s": PRE_MASKER_S,
        "post_masker_s": POST_MASKER_S,
        "ramp_s": RAMP_S,
        "reference_rms_dbfs": REFERENCE_RMS_DBFS,
        "master_gain": MASTER_GAIN,
        "successful": False,
        "final_tmr_db": None,
        "attempts": [],
        "note": (
            "There are 44 fixed calibration items, but the preregistered "
            "maximum is 40 trials. Therefore only the first 40 can be "
            "presented within a single staircase attempt."
        ),
    }

    win = visual.Window(
        fullscr=True,
        color="black",
        units="height",
        allowGUI=False,
    )

    try:
        instructions(win)
        final_result = None

        for attempt_number in (1, 2):
            if attempt_number == 2:
                wait_screen(
                    win,
                    "La primera calibración produjo menos de 6 inversiones.\n\n"
                    "La calibración se repetirá una vez.\n\n"
                    "Pulse ESPACIO para comenzar."
                )

            result = run_attempt(
                win,
                participant_id,
                attempt_number,
                sentence_audio,
                long_masker,
                rng,
                csv_path,
            )

            summary["attempts"].append(result)

            with summary_path.open("w", encoding="utf-8") as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)

            if result["successful"]:
                final_result = result
                break

        if final_result is not None:
            summary["successful"] = True
            summary["final_tmr_db"] = final_result["threshold_tmr_db"]

            wait_screen(
                win,
                "CALIBRACIÓN COMPLETADA\n\n"
                f"TMR individual = {summary['final_tmr_db']:.2f} dB\n\n"
                "Pulse ESPACIO para finalizar."
            )
        else:
            summary["successful"] = False
            summary["final_tmr_db"] = None

            wait_screen(
                win,
                "CALIBRACIÓN NO VÁLIDA\n\n"
                "El segundo intento también produjo menos de 6 inversiones.\n\n"
                "El participante no debe continuar a la tarea principal.\n\n"
                "Pulse ESPACIO para finalizar.",
                color="orange",
            )

        summary["completed"] = datetime.now().isoformat(timespec="seconds")

        with summary_path.open("w", encoding="utf-8") as f:
            json.dump(summary, f, indent=2, ensure_ascii=False)

    except KeyboardInterrupt:
        print("Calibration aborted by user.")

    except Exception:
        traceback.print_exc()
        try:
            wait_screen(
                win,
                "ERROR DURANTE LA CALIBRACIÓN\n\n"
                "Consulte la consola de PsychoPy para ver el error.\n\n"
                "Pulse ESPACIO para cerrar.",
                color="red",
            )
        except Exception:
            pass
        raise

    finally:
        win.close()


if __name__ == "__main__":
    main()
