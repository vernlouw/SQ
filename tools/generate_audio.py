#!/usr/bin/env python3
"""Rebuild the game's original retro-futurist score and Foley.

Requires Python 3 and NumPy. All compositions, synth voices and sound effects
are made here; no recordings, melodies or sound banks from Space Quest are used.
Run from anywhere: python3 tools/generate_audio.py
Generate just the Monolith Burger room: python3 tools/generate_audio.py --only-monolith
Generate just the six campaign regions: python3 tools/generate_audio.py --only-campaign
"""

from pathlib import Path
import argparse
import json
import math
import wave

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
TAU = 2.0 * math.pi
RNG = np.random.default_rng(74219)


def hz(note):
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def envelope(t, duration, attack=0.009, release=0.09, decay=0.0):
    rise = np.sin(np.minimum(t / attack, 1.0) * math.pi / 2.0) ** 2
    fall = np.sin(np.clip((duration - t) / release, 0.0, 1.0) * math.pi / 2.0) ** 2
    return rise * fall * np.exp(-t * decay)


def voice(note, duration, kind="keys"):
    count = max(8, round(duration * RATE))
    t = np.arange(count, dtype=np.float64) / RATE
    freq = hz(note)
    phase = TAU * freq * t
    if kind == "keys":
        # A soft electric piano: mellow fundamentals and a decaying FM tine.
        y = .64 * np.sin(phase + 1.15 * np.exp(-3.4 * t) * np.sin(2.0 * phase))
        y += .24 * np.sin(phase) + .06 * np.sin(3 * phase)
        env = envelope(t, duration, .008, .24, 1.6)
    elif kind == "bass":
        y = .82 * np.sin(phase + .22 * np.exp(-7 * t) * np.sin(phase))
        y += .12 * np.sin(2 * phase) + .045 * np.sin(3 * phase)
        env = envelope(t, duration, .012, .11, 1.45)
    elif kind == "lead":
        vibrato = .035 * np.sin(TAU * 5.3 * t) * np.minimum(t / .15, 1)
        y = .70 * np.sin(phase + vibrato + .36 * np.sin(2 * phase))
        y += .12 * np.sin(2 * phase) + .035 * np.sin(3 * phase)
        env = envelope(t, duration, .027, .14, .6)
    elif kind == "bell":
        y = .65 * np.sin(phase + 1.7 * np.exp(-2.6 * t) * np.sin(2 * phase))
        y += .27 * np.sin(phase) + .045 * np.sin(4 * phase) * np.exp(-5 * t)
        env = envelope(t, duration, .014, .3, 1.85)
    elif kind == "pad":
        # Two gently detuned voices, with equal slow fades at both ends.
        y = .45 * np.sin(phase + .22 * np.sin(phase))
        y += .34 * np.sin(phase * 1.0019) + .06 * np.sin(2 * phase)
        env = envelope(t, duration, .65, .85, .065)
    elif kind == "brass":
        # A restrained synthetic horn, with no sampled instruments.
        phase += .022 * np.sin(TAU * 5.1 * t) * np.minimum(t / .2, 1)
        y = .48 * np.sin(phase) + .23 * np.sin(2 * phase)
        y += .12 * np.sin(3 * phase) + .055 * np.sin(4 * phase)
        env = envelope(t, duration, .044, .18, .36)
    elif kind == "pluck":
        y = .65 * np.sin(phase + 1.8 * np.exp(-7.5 * t) * np.sin(2 * phase))
        y += .25 * np.sin(phase)
        env = envelope(t, duration, .009, .24, 3.0)
    else:
        raise ValueError(kind)
    return y * env


def smooth_noise(count, width):
    raw = RNG.normal(0, 1, count + width)
    cumulative = np.cumsum(raw)
    result = (cumulative[width:] - cumulative[:-width]) / math.sqrt(width)
    return result[:count]


def drum(kind, duration=None):
    durations = {"kick": .22, "brush": .14, "hat": .055, "tap": .10}
    duration = duration or durations[kind]
    t = np.arange(round(duration * RATE)) / RATE
    if kind == "kick":
        phase = TAU * (44 * t + 44 * .027 * (1 - np.exp(-t / .027)))
        y = np.sin(phase) * envelope(t, duration, .003, .04, 18)
    elif kind == "brush":
        y = .64 * smooth_noise(len(t), 12) + .15 * np.sin(TAU * 172 * t)
        y *= envelope(t, duration, .005, .05, 19)
    elif kind == "hat":
        noise = smooth_noise(len(t), 3)
        y = (noise - np.convolve(noise, np.ones(25) / 25, mode="same")) * .35
        y *= envelope(t, duration, .002, .035, 35)
    else:
        y = np.sin(TAU * (360 * t + 24 * t * t))
        y *= envelope(t, duration, .002, .035, 28)
    return y


class Song:
    def __init__(self, bpm, bars):
        self.beat = 60 / bpm
        self.audio = np.zeros((round(self.beat * bars * 4 * RATE), 2))
        self.frames = len(self.audio)

    def event(self, seconds, mono, gain=1, pan=0):
        # Event tails wrap across the boundary instead of being cut off.
        start = round(seconds * RATE) % self.frames
        pan = np.clip(pan, -1, 1)
        stereo = mono[:, None] * gain * np.array([
            math.cos((pan + 1) * math.pi / 4),
            math.sin((pan + 1) * math.pi / 4),
        ])
        offset = 0
        while offset < len(stereo):
            take = min(self.frames - start, len(stereo) - offset)
            self.audio[start:start + take] += stereo[offset:offset + take]
            offset += take
            start = 0

    def note(self, beat, pitch, beats, kind="keys", gain=.12, pan=0):
        self.event(beat * self.beat, voice(pitch, beats * self.beat, kind), gain, pan)

    def percussion(self, beat, kind, gain=.09, pan=0):
        self.event(beat * self.beat, drum(kind), gain, pan)


def diner():
    song = Song(110, 16)
    chords = [
        [48, 52, 55, 59, 62], [45, 48, 52, 55, 59],
        [50, 53, 57, 60, 64], [43, 47, 53, 57, 64],
        [52, 55, 59, 62, 66], [45, 49, 55, 59, 64],
        [50, 53, 57, 60, 64], [43, 47, 53, 57, 62],
    ]
    motifs = [
        [(0.66, 76), (1.5, 79), (2.66, 74), (3.33, 71)],
        [(0, 72), (1.33, 76), (2, 79), (3.33, 76)],
        [(0.66, 77), (1.33, 76), (2.66, 74), (3.33, 72)],
        [(0, 71), (1.33, 74), (2.66, 69)],
        [(0.66, 78), (1.5, 79), (2.66, 83), (3.33, 79)],
        [(0, 76), (1.33, 73), (2.66, 71)],
        [(0.66, 72), (1.33, 74), (2.66, 77), (3.33, 76)],
        [(0, 74), (1.33, 71), (2.66, 67)],
    ]
    for bar in range(16):
        beat = bar * 4
        chord = chords[bar % 8]
        root = chord[0] - 12
        bassline = [root, root + 7, root + 12, root + 7]
        for i, pitch in enumerate(bassline):
            song.note(beat + i, pitch, .86, "bass", .18, -.06)
        for offset, velocity in [(0, .078), (1.66, .06), (3, .054)]:
            for i, pitch in enumerate(chord[1:]):
                song.note(beat + offset + i * .015, pitch, 1.1, "keys", velocity, -.4 + i * .24)
        for offset, pitch in motifs[bar % 8]:
            song.note(beat + offset, pitch, .63, "lead", .083 if bar < 8 else .068, .19)
        for offset in [0, 2]:
            song.percussion(beat + offset, "kick", .10)
        for offset in [1, 3]:
            song.percussion(beat + offset, "brush", .073, .17)
        for offset in [0, .66, 1, 1.66, 2, 2.66, 3, 3.66]:
            song.percussion(beat + offset, "hat", .047, -.32)
    return song.audio


def dock():
    song = Song(108, 16)
    chords = [[40, 55, 59, 66], [36, 55, 59, 64], [33, 52, 55, 59], [35, 54, 59, 62]]
    melody = [[71, 74, 78, 74], [76, 79, 78, 71], [76, 71, 67, 71], [74, 78, 71, 66]]
    for bar in range(16):
        b = bar * 4
        chord = chords[(bar // 2) % 4]
        for i, pitch in enumerate(chord[1:]):
            song.note(b, pitch, 5.3, "pad", .069, -.65 + .65 * i)
        for step in range(8):
            pitch = chord[0] + (12 if step == 6 else 0)
            song.note(b + .5 * step, pitch, .41, "bass", .137 if step % 2 == 0 else .10, -.1)
            song.note(b + .5 * step + .25, chord[1 + step % 3] + 12, .55,
                      "keys", .042, -.44 if step % 2 else .44)
        if bar % 2:
            for offset, pitch in zip([.5, 1.5, 2.5, 3.5], melody[(bar // 2) % 4]):
                song.note(b + offset, pitch, 1.45, "lead", .065, .22)
        for step in range(4):
            song.percussion(b + step, "kick", .12 if step % 2 == 0 else .067)
            song.percussion(b + step + .5, "hat", .055, -.24)
        song.percussion(b + 1, "brush", .055, .3)
        song.percussion(b + 3, "brush", .055, .3)
    return song.audio


def museum():
    song = Song(72, 8)
    chords = [[38, 53, 57, 64], [34, 53, 57, 62], [31, 50, 57, 62], [33, 52, 55, 62]]
    motifs = [[77, 76, 69], [74, 77, 81], [74, 69, 67], [76, 74, 69]]
    for bar in range(8):
        b = bar * 4
        chord = chords[bar % 4]
        song.note(b, chord[0], 4.8, "pad", .115, 0)
        for i, pitch in enumerate(chord[1:]):
            song.note(b + .12 * i, pitch, 5.1, "pad", .067, -.6 + .6 * i)
        for i, pitch in enumerate(motifs[bar % 4]):
            song.note(b + [.45, 1.75, 3.15][i], pitch, 2.4, "bell", .106, [-.45, .4, -.08][i])
        for step in [0, 2]:
            song.percussion(b + step, "tap", .043, -.2 if step == 0 else .2)
        if bar % 2:
            song.note(b + 3.7, chord[2] + 12, 2.2, "bell", .052, .5)
    return song.audio


def monolith():
    """A bright, original counter-service groove with a little orbital swagger."""
    song = Song(124, 16)
    chords = [
        [50, 54, 57, 61, 64], [47, 50, 54, 57, 61],
        [52, 55, 59, 62, 66], [45, 49, 55, 59, 66],
        [54, 57, 61, 64, 68], [47, 51, 57, 61, 66],
        [52, 55, 59, 62, 66], [45, 49, 55, 59, 64],
    ]
    melody = [
        [(.5, 78), (1.25, 81), (2.5, 76), (3.25, 74)],
        [(.25, 73), (1, 74), (2.5, 78), (3.5, 81)],
        [(.5, 79), (1.5, 78), (2.75, 76)],
        [(.25, 76), (1.25, 73), (2.5, 71), (3.5, 73)],
        [(.5, 80), (1.25, 81), (2.5, 85), (3.25, 83)],
        [(.25, 78), (1.5, 75), (2.75, 73)],
        [(.5, 74), (1.25, 78), (2.5, 79), (3.25, 78)],
        [(.25, 76), (1.25, 73), (2.5, 69), (3.5, 73)],
    ]
    for bar in range(16):
        b = bar * 4
        chord = chords[bar % 8]
        root = chord[0] - 12
        for offset, pitch, gain in [
            (0, root, .16), (1, root + 7, .12),
            (1.75, root + 12, .11), (2.5, root + 7, .13),
            (3.5, root + (11 if bar % 8 == 7 else 2), .10),
        ]:
            song.note(b + offset, pitch, .48, "bass", gain, -.08)
        for offset, gain in [(.5, .070), (1.5, .048), (2.75, .061)]:
            for i, pitch in enumerate(chord[1:]):
                song.note(b + offset + i * .016, pitch, .9, "keys", gain, -.48 + i * .30)
        for offset, pitch in melody[bar % 8]:
            song.note(b + offset, pitch, .52 if offset < 3 else .73,
                      "lead", .077 if bar < 8 else .062, .17)
        if bar >= 8:
            song.note(b + 2.125, chord[-1] + 12, 1.12, "bell", .045, -.38)
        for offset in [0, 2]:
            song.percussion(b + offset, "kick", .105)
        for offset in [1, 3]:
            song.percussion(b + offset, "brush", .068, .23)
        for step in range(8):
            song.percussion(b + step * .5, "hat", .041 if step % 2 else .029, -.30)
        if bar % 4 == 3:
            song.percussion(b + 3.75, "tap", .030, .34)
    return song.audio


def room_tone(kind):
    # Integer-cycle hum and circularly filtered noise make exact periodic beds.
    duration = 8.0
    n = round(duration * RATE)
    t = np.arange(n) / RATE
    white = RNG.normal(0, 1, n)
    spectrum = np.fft.rfft(white)
    frequencies = np.fft.rfftfreq(n, 1 / RATE)
    cutoff = {"diner": 180, "dock": 92, "museum": 240, "monolith": 210}[kind]
    spectrum *= 1 / (1 + (frequencies / cutoff) ** 6)
    spectrum[0] = 0
    air = np.fft.irfft(spectrum, n=n)
    air /= max(np.sqrt(np.mean(air * air)), 1e-9)
    base = {"diner": 60, "dock": 48, "museum": 80, "monolith": 56}[kind]
    hum = .48 * np.sin(TAU * base * t) + .12 * np.sin(TAU * base * 2 * t)
    hum *= .92 + .08 * np.sin(TAU * .25 * t)
    if kind == "diner":
        hum += .08 * np.sin(TAU * 240 * t) * (1 + .2 * np.sin(TAU * .375 * t))
    elif kind == "dock":
        hum += .13 * np.sin(TAU * 24 * t) + .075 * np.sin(TAU * 96 * t)
    elif kind == "monolith":
        hum += .075 * np.sin(TAU * 192 * t) * (1 + .25 * np.sin(TAU * .375 * t))
        hum += .035 * np.sin(TAU * 384 * t)
    else:
        hum += .06 * np.sin(TAU * 320 * t) * (.65 + .35 * np.sin(TAU * .125 * t))
    left = .6 * hum + .22 * air
    right = .6 * hum + .22 * np.roll(air, 1400)
    if kind == "monolith":
        # A faint extractor/grill hiss, filtered on a circular eight-second
        # buffer so it wraps naturally rather than fading in and out.
        kitchen = np.fft.rfft(white)
        kitchen *= frequencies ** 2 / (frequencies ** 2 + 700 ** 2)
        kitchen *= 1 / (1 + (frequencies / 2600) ** 8)
        kitchen = np.fft.irfft(kitchen, n=n)
        kitchen /= max(np.sqrt(np.mean(kitchen * kitchen)), 1e-9)
        left += .045 * kitchen
        right += .045 * np.roll(kitchen, 920)
    return np.column_stack((left, right))


CAMPAIGN_REGIONS = ("labion", "plexi", "starcon", "polysorbate", "glitzon", "finale")


def campaign_score(region):
    """Six original regional arrangements, all with circular release tails."""
    tempos = {"labion": (92, 12), "plexi": (120, 16), "starcon": (112, 16),
              "polysorbate": (88, 12), "glitzon": (116, 16), "finale": (112, 16)}
    progressions = {
        "labion": [[50, 57, 60, 64], [46, 53, 57, 62], [43, 53, 57, 62], [45, 55, 59, 64]],
        "plexi": [[52, 59, 63, 66], [49, 56, 59, 63], [57, 61, 64, 68], [47, 54, 61, 66]],
        "starcon": [[43, 55, 59, 62], [48, 55, 60, 64], [40, 55, 59, 64], [50, 57, 60, 66]],
        "polysorbate": [[48, 55, 58, 63], [41, 53, 56, 60], [46, 56, 60, 65], [43, 53, 59, 62]],
        "glitzon": [[41, 57, 60, 64], [48, 55, 59, 62], [45, 55, 60, 64], [46, 53, 57, 60]],
        "finale": [[35, 50, 54, 61], [31, 50, 54, 59], [34, 49, 52, 58], [30, 49, 54, 57]],
    }
    melodies = {
        "labion": [[74, 76, 69], [77, 74, 69], [79, 77, 74], [76, 71, 69]],
        "plexi": [[83, 78, 75, 80], [80, 75, 83, 78], [85, 80, 76, 73], [78, 73, 75, 82]],
        "starcon": [[67, 71, 74, 72], [76, 72, 67, 64], [71, 76, 74, 67], [69, 66, 74, 62]],
        "polysorbate": [[75, 72, 70], [72, 68, 65], [77, 72, 70], [71, 74, 68]],
        "glitzon": [[77, 76, 72, 69], [74, 79, 76, 71], [76, 72, 79, 81], [77, 74, 72, 69]],
        "finale": [[61, 62, 66], [59, 62, 61], [58, 64, 61], [57, 61, 54]],
    }
    bpm, bars = tempos[region]
    song = Song(bpm, bars)
    for bar in range(bars):
        beat = bar * 4
        chord = progressions[region][bar % 4]
        melody = melodies[region][bar % 4]
        root = chord[0]
        if region == "labion":
            for i, pitch in enumerate(chord[1:]):
                song.note(beat + .08 * i, pitch, 5.1, "pad", .065, -.55 + .55 * i)
            song.note(beat, root - 12, 2.8, "bass", .09)
            for i, pitch in enumerate(melody):
                song.note(beat + [.4, 1.8, 3.15][i], pitch, 1.4, "pluck", .092, [-.42, .38, .1][i])
            song.percussion(beat + 1.5, "tap", .022, -.3)
            song.percussion(beat + 3.25, "brush", .025, .3)
        elif region == "plexi":
            song.note(beat, root - 12, .7, "bass", .11)
            song.note(beat + 2.5, root - 5, .65, "bass", .095)
            for i in range(8):
                pitch = chord[1 + i % 3] + 12
                song.note(beat + i * .5, pitch, .65, "bell", .055, -.48 if i % 2 else .48)
            if bar % 2 == 0:
                for i, pitch in enumerate(melody):
                    song.note(beat + .25 + i, pitch, .6, "keys", .062, .1)
            song.percussion(beat, "kick", .065)
            song.percussion(beat + 2, "brush", .04)
            for i in range(4):
                song.percussion(beat + i + .5, "hat", .026, -.2)
        elif region == "starcon":
            for i, pitch in enumerate(chord[1:]):
                song.note(beat, pitch, .75, "brass", .050, -.35 + i * .35)
            for i, pitch in enumerate(melody):
                song.note(beat + [0, 1, 2.5, 3.25][i], pitch, .55 if i < 3 else .9, "brass", .10, .1)
            for i in [0, 2]:
                song.note(beat + i, root - 12 + (7 if i else 0), .75, "bass", .135)
                song.percussion(beat + i, "kick", .073)
            for i in [1, 3]:
                song.percussion(beat + i, "brush", .060, -.2)
            for i in range(8):
                song.percussion(beat + .5 * i, "hat", .017, .25)
        elif region == "polysorbate":
            for offset in [.65, 2.35]:
                for i, pitch in enumerate(chord[1:]):
                    song.note(beat + offset + .015 * i, pitch, 1.3, "keys", .070, -.4 + .4 * i)
            for i, pitch in enumerate([root - 12, root - 5, root, root - 10]):
                song.note(beat + i, pitch, .72, "bass", .125)
            if bar % 2 == 0:
                for i, pitch in enumerate(melody):
                    song.note(beat + [.4, 1.7, 3.2][i], pitch, .85, "lead", .063, .12)
            song.percussion(beat, "kick", .06)
            for i in [1, 3]:
                song.percussion(beat + i, "brush", .043, .25)
                song.percussion(beat + i + .65, "hat", .024, -.2)
        elif region == "glitzon":
            for offset in [.25, 2.5]:
                for i, pitch in enumerate(chord[1:]):
                    song.note(beat + offset + .02 * i, pitch, 1.3, "keys", .064, -.4 + i * .4)
            for i, pitch in enumerate(melody):
                song.note(beat + [0, 1.25, 2.25, 3.5][i], pitch, .9, "keys", .13, .12)
            song.note(beat, root - 12, .85, "bass", .13)
            song.note(beat + 2, root - 5, .8, "bass", .10)
            if bar % 4 == 3:
                song.note(beat + 3, chord[-1] + 24, 1.5, "bell", .028, -.4)
            for i in [0, 2]:
                song.percussion(beat + i, "kick", .065)
            for i in [1, 3]:
                song.percussion(beat + i, "brush", .048, .15)
        else:
            for i, pitch in enumerate(chord[1:]):
                song.note(beat + .04 * i, pitch, 5.2, "pad", .075, -.5 + .5 * i)
            for i in range(8):
                song.note(beat + i * .5, root + (7 if i % 3 == 2 else 0), .34, "bass", .10, -.1)
            for i, pitch in enumerate(melody):
                song.note(beat + [.5, 2, 3.3][i], pitch, 1.1, "bell", .045, .3)
            song.percussion(beat, "kick", .09)
            song.percussion(beat + 2.75, "tap", .035, -.3)
            song.percussion(beat + 3.5, "brush", .025, .25)
    return song.audio


def campaign_tone(region):
    """Periodic environmental beds; jungle birds are synthesized chirps."""
    bed = Song(20, 1)  # Twelve seconds, including events wrapping the seam.
    n = bed.frames
    t = np.arange(n) / RATE
    frequencies = np.fft.rfftfreq(n, 1 / RATE)
    white = RNG.normal(0, 1, n)
    cutoff = {"labion": 480, "plexi": 190, "starcon": 135,
              "polysorbate": 260, "glitzon": 155, "finale": 85}[region]
    spectrum = np.fft.rfft(white) / (1 + (frequencies / cutoff) ** 6)
    spectrum[0] = 0
    air = np.fft.irfft(spectrum, n=n)
    air /= max(np.sqrt(np.mean(air * air)), 1e-9)
    base = {"labion": 45, "plexi": 72, "starcon": 60,
            "polysorbate": 42, "glitzon": 110, "finale": 35}[region]
    hum = .38 * np.sin(TAU * base * t) + .09 * np.sin(TAU * base * 2 * t)
    hum *= .9 + .1 * np.sin(TAU * t / 12)
    bed.audio[:, 0] = (.07 if region == "labion" else .55) * hum + .22 * air
    bed.audio[:, 1] = (.07 if region == "labion" else .55) * hum + .22 * np.roll(air, 1800)
    if region in ("labion", "polysorbate", "finale"):
        hiss = np.fft.rfft(white)
        hiss *= frequencies ** 2 / (frequencies ** 2 + 400 ** 2)
        hiss *= 1 / (1 + (frequencies / 2800) ** 8)
        hiss = np.fft.irfft(hiss, n=n)
        hiss /= max(np.sqrt(np.mean(hiss * hiss)), 1e-9)
        gain = .11 if region == "labion" else .025
        bed.audio[:, 0] += gain * hiss
        bed.audio[:, 1] += gain * np.roll(hiss, 700)
    if region == "labion":
        for start, pitch, pan in [(1.7, 1800, -.55), (5.8, 2250, .5), (9.4, 1560, -.2)]:
            chirp_t = np.arange(round(.42 * RATE)) / RATE
            chirp = np.sin(TAU * (pitch * chirp_t + 440 * chirp_t ** 2))
            chirp *= envelope(chirp_t, .42, .014, .15) * (.6 + .4 * np.sin(TAU * 8 * chirp_t))
            bed.event(start, chirp, .080, pan)
    elif region == "plexi":
        bed.event(3.4, voice(88, 1.4, "bell"), .044, -.3)
        bed.event(8.3, voice(84, 1.4, "bell"), .039, .3)
    elif region == "starcon":
        bed.event(6.4, voice(67, .25, "keys"), .025, .3)
        bed.event(6.8, voice(72, .35, "keys"), .025, .3)
    elif region == "polysorbate":
        neon = .065 * np.sin(TAU * 180 * t) * (.8 + .2 * np.sin(TAU * t / 6))
        bed.audio += neon[:, None]
    elif region == "glitzon":
        bed.event(9.2, voice(89, 1.8, "bell"), .027, -.35)
    else:
        machinery = .095 * np.sin(TAU * 47.5 * t) + .035 * np.sin(TAU * 190 * t)
        bed.audio += machinery[:, None]
        bed.event(5.7, drum("tap", .22), .041, -.3)
    return bed.audio


def effect(notes=None, duration=.45):
    audio = np.zeros((round(duration * RATE), 2))
    if notes:
        for start, pitch, length, kind, gain, pan in notes:
            mono = voice(pitch, length, kind)
            start_frame = round(start * RATE)
            take = min(len(mono), len(audio) - start_frame)
            angle = (pan + 1) * math.pi / 4
            audio[start_frame:start_frame + take] += mono[:take, None] * gain * [math.cos(angle), math.sin(angle)]
    return audio


def add_mono(audio, mono, gain=.1, start=0, pan=0):
    start_frame = round(start * RATE)
    take = min(len(mono), len(audio) - start_frame)
    angle = (pan + 1) * math.pi / 4
    audio[start_frame:start_frame + take] += mono[:take, None] * gain * [math.cos(angle), math.sin(angle)]
    return audio


def effects():
    result = {}
    result["ui_click"] = effect([(0, 83, .085, "keys", .55, 0)], .12)
    result["pickup"] = effect([(0, 76, .23, "bell", .36, -.2), (.085, 83, .33, "bell", .4, .2)], .5)
    result["terminal"] = effect([(0, 76, .18, "keys", .35, -.2), (.1, 80, .2, "keys", .3, .2),
                                 (.23, 83, .30, "keys", .34, 0)], .62)
    result["combine"] = effect([(0, 67, .3, "bell", .35, -.4), (.12, 74, .3, "bell", .35, .4),
                                (.25, 79, .43, "bell", .35, 0)], .8)
    result["success"] = effect([(0, 72, .42, "lead", .30, -.2), (.15, 76, .45, "lead", .3, .2),
                                (.3, 79, .6, "lead", .32, 0), (.3, 60, .6, "keys", .18, -.4)], 1.0)
    result["blocked"] = effect([(0, 57, .18, "bass", .45, 0), (.17, 54, .23, "bass", .36, 0)], .5)
    result["save"] = effect([(0, 72, .18, "keys", .33, -.1), (.10, 76, .18, "keys", .3, .1),
                             (.21, 79, .32, "keys", .35, 0)], .62)
    result["load"] = effect([(0, 79, .18, "keys", .33, .1), (.10, 76, .18, "keys", .3, -.1),
                             (.21, 72, .32, "keys", .35, 0)], .62)
    result["dialogue"] = effect([(0, 69, .15, "keys", .28, 0), (.06, 76, .18, "keys", .21, 0)], .30)
    result["complete"] = effect(duration=2.5)
    for start, pitches in [(0, [60, 64, 67]), (.3, [62, 65, 69]), (.6, [64, 67, 71]),
                           (1.05, [60, 64, 67, 72])]:
        for i, pitch in enumerate(pitches):
            add_mono(result["complete"], voice(pitch, 1.3 if start > 1 else .6, "keys"), .18,
                     start + .017 * i, -.4 + .25 * i)
    for start, pitch in [(0, 72), (.3, 74), (.6, 76), (1.05, 79), (1.27, 84)]:
        add_mono(result["complete"], voice(pitch, 1.15, "bell"), .23, start, .16)
    door = effect(duration=.85)
    t = np.arange(round(.7 * RATE)) / RATE
    motor = np.sin(TAU * (105 * t + 80 * t * t)) + .3 * np.sin(TAU * 320 * t)
    motor *= envelope(t, .7, .055, .15) * (.6 + .4 * np.sin(math.pi * t / .7))
    add_mono(door, motor, .16)
    add_mono(door, drum("tap"), .32, .69)
    result["door"] = door
    for name, seed in [("step_a", 1), ("step_b", 2)]:
        step = effect(duration=.19)
        t = np.arange(round(.17 * RATE)) / RATE
        thud = np.sin(TAU * ((62 + seed * 5) * t + 34 * .018 * (1 - np.exp(-t / .018))))
        thud *= envelope(t, .17, .002, .065, 30)
        scuff = smooth_noise(len(t), 14) * envelope(t, .17, .005, .07, 26)
        add_mono(step, .55 * thud + .22 * scuff, .4)
        result[name] = step
    return result


def write_asset(name, data, target_rms, peak_limit):
    # Maintain useful headroom and remove DC before converting to PCM.
    data = data - np.mean(data, axis=0)
    data = np.tanh(data * 1.3) / 1.3
    data = data - np.mean(data, axis=0)
    rms = np.sqrt(np.mean(data * data))
    peak = np.max(np.abs(data))
    data *= min(target_rms / max(rms, 1e-12), peak_limit / max(peak, 1e-12))
    encoded = np.rint(data * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(encoded.tobytes())
    seam = float(np.max(np.abs(data[0] - data[-1])))
    stats = {
        "file": path.name,
        "seconds": round(len(data) / RATE, 3),
        "peak_dbfs": round(20 * math.log10(max(np.max(np.abs(data)), 1e-12)), 2),
        "rms_dbfs": round(20 * math.log10(max(np.sqrt(np.mean(data * data)), 1e-12)), 2),
        "seam_delta": round(seam, 6),
        "dc": round(float(np.max(np.abs(np.mean(data, axis=0)))), 9),
    }
    assert np.max(np.abs(encoded)) < 32767, name + " clips"
    return stats


def main():
    global RNG
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true", help="Print validation as JSON.")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--only-monolith", action="store_true", help="Write only the Monolith room's music and ambience; preserve all other recordings.")
    selection.add_argument("--only-campaign", action="store_true", help="Write only the six regional scores and ambience beds; preserve all other recordings.")
    args = parser.parse_args()
    reports = []
    if not args.only_monolith and not args.only_campaign:
        # Preserve the legacy synthesis order and seed for the existing cues.
        for room, generator in [("diner", diner), ("dock", dock), ("museum", museum)]:
            reports.append(write_asset("music_" + room, generator(), .09, .45))
            reports.append(write_asset("ambience_" + room, room_tone(room), .036, .16))
        for name, sound in effects().items():
            reports.append(write_asset(name, sound, .10 if name.startswith("step") else .12, .46))
    # The added room has its own deterministic seed, independent of whether
    # older assets were generated in the same run. Supplied title cues are
    # never outputs of this synthesis script.
    if not args.only_campaign:
        RNG = np.random.default_rng(74220)
        reports.append(write_asset("music_monolith", monolith(), .09, .45))
        reports.append(write_asset("ambience_monolith", room_tone("monolith"), .036, .16))
    if not args.only_monolith:
        for index, region in enumerate(CAMPAIGN_REGIONS):
            # Regional seeds isolate regeneration from every older asset.
            RNG = np.random.default_rng(74300 + index)
            reports.append(write_asset("music_" + region, campaign_score(region), .085, .40))
            reports.append(write_asset("ambience_" + region, campaign_tone(region), .036, .16))
    if args.report:
        print(json.dumps({"rate": RATE, "channels": 2, "format": "PCM16", "assets": reports}, indent=2))
    else:
        for report in reports:
            print(f"{report['file']:24} {report['seconds']:6.2f}s  peak {report['peak_dbfs']:6.2f}dBFS  RMS {report['rms_dbfs']:6.2f}dBFS")


if __name__ == "__main__":
    main()
