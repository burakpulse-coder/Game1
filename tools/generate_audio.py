#!/usr/bin/env python3
"""Oyunun ses efektlerini ve müzik döngülerini sentezleyip assets/audio'ya yazar.

Harici ses dosyası ya da kütüphane gerektirmez; her şey standart kütüphaneyle
(wave + math) üretilir. Böylece depoda telif belirsizliği olan ikili ses dosyası
bulunmaz ve tonlar buradan tek noktadan ayarlanabilir.

Kullanım: python3 tools/generate_audio.py
"""
from __future__ import annotations

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio")
RATE = 22050

# Nota adı -> frekans (Hz), A4 = 440
_SEMITONES = {"c": -9, "d": -7, "e": -5, "f": -4, "g": -2, "a": 0, "b": 2}


def note(name: str, octave: int = 4, sharp: bool = False) -> float:
    semitone = _SEMITONES[name] + (1 if sharp else 0) + (octave - 4) * 12
    return 440.0 * (2.0 ** (semitone / 12.0))


class Buffer:
    """Basit kayan noktalı ses tamponu (mono)."""

    def __init__(self, seconds: float) -> None:
        self.data = [0.0] * int(RATE * seconds)

    def __len__(self) -> int:
        return len(self.data)

    def add(self, start: float, samples: list[float], gain: float = 1.0) -> None:
        offset = int(start * RATE)
        for i, value in enumerate(samples):
            index = offset + i
            if 0 <= index < len(self.data):
                self.data[index] += value * gain

    def normalize(self, peak: float = 0.82) -> None:
        top = max((abs(v) for v in self.data), default=0.0)
        if top < 1e-6:
            return
        scale = peak / top
        self.data = [v * scale for v in self.data]

    def write(self, filename: str) -> None:
        os.makedirs(OUT_DIR, exist_ok=True)
        path = os.path.join(OUT_DIR, filename)
        with wave.open(path, "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            frames = bytearray()
            for value in self.data:
                clipped = max(-1.0, min(1.0, value))
                frames += struct.pack("<h", int(clipped * 32767))
            handle.writeframes(bytes(frames))
        return path


# --------------------------------------------------------------------------
# Dalga üreticileri
# --------------------------------------------------------------------------
def env_ad(length: int, attack: float, decay_curve: float = 3.0) -> list[float]:
    """Hızlı yükselip üstel sönen zarf."""
    attack_samples = max(1, int(length * attack))
    out = []
    for i in range(length):
        if i < attack_samples:
            out.append(i / attack_samples)
        else:
            t = (i - attack_samples) / max(1, length - attack_samples)
            out.append(math.exp(-decay_curve * t))
    return out


def tone(freq: float, seconds: float, harmonics=(1.0, 0.35, 0.12),
         attack: float = 0.01, decay: float = 3.0, detune: float = 0.0,
         sweep: float = 1.0) -> list[float]:
    """Harmonikli sinüs tonu. `sweep` süre sonunda frekans çarpanıdır."""
    length = int(RATE * seconds)
    envelope = env_ad(length, attack, decay)
    out = []
    phase = 0.0
    for i in range(length):
        t = i / length if length else 0.0
        current = freq * (1.0 + (sweep - 1.0) * t)
        phase += 2.0 * math.pi * current / RATE
        value = 0.0
        for index, amp in enumerate(harmonics):
            value += amp * math.sin(phase * (index + 1))
        if detune:
            value += 0.4 * math.sin(phase * (1.0 + detune))
        out.append(value * envelope[i])
    return out


def noise(seconds: float, attack: float = 0.005, decay: float = 6.0,
          low_pass: float = 0.35, seed: int = 1) -> list[float]:
    """Alçak geçiren süzgeçten geçmiş gürültü — vuruş ve savurma sesleri için."""
    rng = random.Random(seed)
    length = int(RATE * seconds)
    envelope = env_ad(length, attack, decay)
    out = []
    previous = 0.0
    for i in range(length):
        white = rng.uniform(-1.0, 1.0)
        previous += (white - previous) * low_pass
        out.append(previous * envelope[i])
    return out


# --------------------------------------------------------------------------
# Ses efektleri
# --------------------------------------------------------------------------
def sfx_word_correct() -> Buffer:
    """Yükselen üç notalı çınlama — doğru kelime onayı."""
    buffer = Buffer(0.75)
    for index, freq in enumerate([note("e", 5), note("g", 5, sharp=True), note("b", 5)]):
        buffer.add(index * 0.07, tone(freq, 0.55, (1.0, 0.5, 0.25, 0.12),
                                      attack=0.005, decay=4.0), 0.55)
    buffer.add(0.14, tone(note("e", 6), 0.4, (0.6, 0.2), attack=0.004, decay=6.0), 0.3)
    buffer.normalize(0.8)
    return buffer


def sfx_word_wrong() -> Buffer:
    """Kısa, alçalan uyarı — geçersiz kelime."""
    buffer = Buffer(0.34)
    buffer.add(0.0, tone(220.0, 0.3, (1.0, 0.6, 0.4), attack=0.004, decay=5.0, sweep=0.55), 0.8)
    buffer.add(0.0, noise(0.12, decay=10.0, low_pass=0.2, seed=7), 0.25)
    buffer.normalize(0.7)
    return buffer


def sfx_letter_pick() -> Buffer:
    """Harf taşına dokunma tıkırtısı."""
    buffer = Buffer(0.12)
    buffer.add(0.0, tone(880.0, 0.09, (1.0, 0.25), attack=0.002, decay=9.0), 0.5)
    buffer.add(0.0, noise(0.04, decay=14.0, low_pass=0.6, seed=3), 0.2)
    buffer.normalize(0.6)
    return buffer


def sfx_button() -> Buffer:
    buffer = Buffer(0.13)
    buffer.add(0.0, tone(520.0, 0.11, (1.0, 0.3), attack=0.003, decay=8.0), 0.5)
    buffer.normalize(0.55)
    return buffer


def sfx_tower_build() -> Buffer:
    """Taş oturma sesi — kule inşası."""
    buffer = Buffer(0.6)
    buffer.add(0.0, noise(0.28, attack=0.002, decay=7.0, low_pass=0.12, seed=11), 0.9)
    buffer.add(0.02, tone(120.0, 0.35, (1.0, 0.4), attack=0.004, decay=6.0, sweep=0.7), 0.6)
    buffer.add(0.16, tone(330.0, 0.3, (0.7, 0.3), attack=0.004, decay=6.0), 0.3)
    buffer.normalize(0.82)
    return buffer


def sfx_archer() -> Buffer:
    """Yay savurması."""
    buffer = Buffer(0.24)
    buffer.add(0.0, noise(0.2, attack=0.004, decay=9.0, low_pass=0.5, seed=21), 0.8)
    buffer.add(0.0, tone(1400.0, 0.14, (0.5,), attack=0.003, decay=10.0, sweep=0.45), 0.25)
    buffer.normalize(0.62)
    return buffer


def sfx_mage() -> Buffer:
    """Büyü fırlatma — yukarı süpüren parıltı."""
    buffer = Buffer(0.5)
    buffer.add(0.0, tone(420.0, 0.42, (0.8, 0.4, 0.2), attack=0.02, decay=4.0,
                         sweep=2.6, detune=0.01), 0.7)
    buffer.add(0.06, tone(1250.0, 0.3, (0.4, 0.2), attack=0.01, decay=6.0), 0.25)
    buffer.normalize(0.7)
    return buffer


def sfx_catapult() -> Buffer:
    """Ağır mancınık gümbürtüsü."""
    buffer = Buffer(0.7)
    buffer.add(0.0, noise(0.4, attack=0.002, decay=5.0, low_pass=0.08, seed=33), 1.0)
    buffer.add(0.0, tone(80.0, 0.5, (1.0, 0.5, 0.2), attack=0.005, decay=4.0, sweep=0.6), 0.9)
    buffer.normalize(0.85)
    return buffer


def sfx_enemy_death() -> Buffer:
    buffer = Buffer(0.35)
    buffer.add(0.0, tone(520.0, 0.3, (1.0, 0.4), attack=0.004, decay=7.0, sweep=0.4), 0.6)
    buffer.add(0.0, noise(0.16, decay=9.0, low_pass=0.3, seed=41), 0.4)
    buffer.normalize(0.66)
    return buffer


def sfx_castle_hit() -> Buffer:
    buffer = Buffer(0.6)
    buffer.add(0.0, noise(0.35, attack=0.002, decay=5.5, low_pass=0.07, seed=53), 1.0)
    buffer.add(0.0, tone(70.0, 0.45, (1.0, 0.35), attack=0.004, decay=4.5, sweep=0.65), 0.8)
    buffer.normalize(0.86)
    return buffer


def sfx_ulti() -> Buffer:
    """Kadim Büyü: yükselen şarj + patlama."""
    buffer = Buffer(1.5)
    buffer.add(0.0, tone(180.0, 0.7, (0.7, 0.4, 0.2), attack=0.25, decay=1.2,
                         sweep=4.0, detune=0.008), 0.6)
    buffer.add(0.62, noise(0.8, attack=0.002, decay=3.5, low_pass=0.06, seed=67), 1.0)
    for index, freq in enumerate([note("a", 4), note("c", 5), note("e", 5), note("a", 5)]):
        buffer.add(0.66 + index * 0.05, tone(freq, 0.75, (1.0, 0.5, 0.2),
                                             attack=0.006, decay=3.0), 0.4)
    buffer.normalize(0.9)
    return buffer


def sfx_victory() -> Buffer:
    """Zafer fanfarı (majör)."""
    buffer = Buffer(1.8)
    melody = [(note("c", 5), 0.0), (note("e", 5), 0.16), (note("g", 5), 0.32),
              (note("c", 6), 0.48)]
    for freq, start in melody:
        buffer.add(start, tone(freq, 1.0, (1.0, 0.45, 0.2, 0.1), attack=0.01, decay=2.6), 0.5)
    buffer.add(0.48, tone(note("g", 4), 1.2, (0.8, 0.3), attack=0.02, decay=2.0), 0.3)
    buffer.normalize(0.85)
    return buffer


def sfx_defeat() -> Buffer:
    """Yenilgi (minör, alçalan)."""
    buffer = Buffer(1.7)
    melody = [(note("a", 4), 0.0), (note("f", 4), 0.24), (note("d", 4), 0.48),
              (note("a", 3), 0.72)]
    for freq, start in melody:
        buffer.add(start, tone(freq, 1.0, (1.0, 0.4, 0.18), attack=0.02, decay=2.4), 0.5)
    buffer.normalize(0.78)
    return buffer


# --------------------------------------------------------------------------
# Müzik döngüleri
# --------------------------------------------------------------------------
def _pad(buffer: Buffer, freq: float, start: float, seconds: float, gain: float) -> None:
    """Yumuşak, uzun soluklu yastık ton."""
    length = int(RATE * seconds)
    attack = int(length * 0.25)
    release = int(length * 0.35)
    phase = 0.0
    out = []
    for i in range(length):
        phase += 2.0 * math.pi * freq / RATE
        value = math.sin(phase) + 0.32 * math.sin(phase * 2) + 0.14 * math.sin(phase * 3)
        value += 0.25 * math.sin(phase * 1.003)  # hafif detune, koro hissi
        amp = 1.0
        if i < attack:
            amp = i / attack
        elif i > length - release:
            amp = (length - i) / release
        out.append(value * amp)
    buffer.add(start, out, gain)


def music_menu() -> Buffer:
    """Sakin, epik-fantastik menü döngüsü (la minör). 12.8 s, kusursuz döner."""
    bars = 4
    bar_seconds = 3.2
    buffer = Buffer(bars * bar_seconds)
    chords = [
        [note("a", 3), note("c", 4), note("e", 4)],   # Am
        [note("f", 3), note("a", 3), note("c", 4)],   # F
        [note("c", 4), note("e", 4), note("g", 4)],   # C
        [note("g", 3), note("b", 3), note("d", 4)],   # G
    ]
    for bar in range(bars):
        start = bar * bar_seconds
        for freq in chords[bar]:
            _pad(buffer, freq, start, bar_seconds, 0.16)
        # Arpej: akorun notaları sırayla çınlar
        for step in range(8):
            freq = chords[bar][step % 3] * 2.0
            buffer.add(start + step * (bar_seconds / 8.0),
                       tone(freq, 0.5, (0.8, 0.25), attack=0.02, decay=4.5), 0.12)
        # Kök notanın oktav altı: davul yerine geçen nabız
        buffer.add(start, tone(chords[bar][0] * 0.5, 0.6, (1.0, 0.2),
                               attack=0.01, decay=4.0), 0.16)
    buffer.normalize(0.6)
    return buffer


def music_battle() -> Buffer:
    """Savaş döngüsü: aynı armoni, daha hızlı nabız ve vurmalı vuruşlar."""
    bars = 4
    bar_seconds = 2.4
    buffer = Buffer(bars * bar_seconds)
    chords = [
        [note("a", 3), note("c", 4), note("e", 4)],
        [note("g", 3), note("b", 3), note("d", 4)],
        [note("f", 3), note("a", 3), note("c", 4)],
        [note("e", 3), note("g", 3, sharp=True), note("b", 3)],
    ]
    for bar in range(bars):
        start = bar * bar_seconds
        for freq in chords[bar]:
            _pad(buffer, freq, start, bar_seconds, 0.13)
        # Sekizlik nabız
        for step in range(8):
            offset = start + step * (bar_seconds / 8.0)
            buffer.add(offset, tone(chords[bar][0] * 0.5, 0.22, (1.0, 0.3),
                                    attack=0.004, decay=7.0), 0.20)
            if step % 2 == 0:
                buffer.add(offset, noise(0.1, decay=12.0, low_pass=0.09,
                                         seed=100 + bar * 8 + step), 0.16)
            else:
                buffer.add(offset, noise(0.06, decay=16.0, low_pass=0.7,
                                         seed=200 + bar * 8 + step), 0.07)
        # Melodi çizgisi
        for step in range(4):
            freq = chords[bar][step % 3] * 2.0
            buffer.add(start + step * (bar_seconds / 4.0),
                       tone(freq, 0.45, (0.7, 0.3, 0.12), attack=0.01, decay=5.0), 0.13)
    buffer.normalize(0.68)
    return buffer


SOUNDS = {
    "sfx_kelime_dogru.wav": sfx_word_correct,
    "sfx_kelime_yanlis.wav": sfx_word_wrong,
    "sfx_harf_sec.wav": sfx_letter_pick,
    "sfx_dugme.wav": sfx_button,
    "sfx_kule_insa.wav": sfx_tower_build,
    "sfx_okcu_atis.wav": sfx_archer,
    "sfx_buyu_atis.wav": sfx_mage,
    "sfx_mancinik_atis.wav": sfx_catapult,
    "sfx_dusman_olum.wav": sfx_enemy_death,
    "sfx_kale_hasar.wav": sfx_castle_hit,
    "sfx_ulti.wav": sfx_ulti,
    "sfx_zafer.wav": sfx_victory,
    "sfx_yenilgi.wav": sfx_defeat,
    "muzik_menu.wav": music_menu,
    "muzik_savas.wav": music_battle,
}


def main() -> int:
    total = 0
    for filename, factory in SOUNDS.items():
        buffer = factory()
        buffer.write(filename)
        size = os.path.getsize(os.path.join(OUT_DIR, filename))
        total += size
        print("  %-26s %6.1f s  %6.0f KB" % (filename, len(buffer) / RATE, size / 1024))
    print("  toplam %.1f MB" % (total / 1048576))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
