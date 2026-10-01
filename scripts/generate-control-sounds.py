#!/usr/bin/env python3
"""Regenerate the original, mellow movement and rotation cues (requires ffmpeg)."""

import math
from pathlib import Path
import struct
import subprocess
import tempfile
import wave


ROOT = Path(__file__).resolve().parents[1]
SAMPLE_RATE = 44100


def generate_cue(name, duration, start_hz, end_hz, amplitude):
    """Encode a softly enveloped tone into both supported asset formats."""
    samples = []
    phase = 0.0
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        progress = time / duration
        frequency = start_hz + (end_hz - start_hz) * progress
        phase += 2 * math.pi * frequency / SAMPLE_RATE
        attack = math.sin(min(time / 0.012, 1) * math.pi / 2) ** 2
        release = math.cos(progress * math.pi / 2) ** 2
        tone = (math.sin(phase) + 0.12 * math.sin(2 * phase)) / 1.12
        samples.append(round(32767 * amplitude * attack * release * tone))

    with tempfile.TemporaryDirectory() as temporary:
        source = Path(temporary) / 'cue.wav'
        with wave.open(str(source), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(SAMPLE_RATE)
            output.writeframes(struct.pack(f'<{len(samples)}h', *samples))
        for extension, codec in [('ogg', 'libvorbis'), ('mp3', 'libmp3lame')]:
            destination = ROOT / f'assets/audio/sfx/wood_{name}.{extension}'
            subprocess.run(
                ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                 '-i', str(source), '-c:a', codec, '-q:a', '4', str(destination)],
                check=True,
            )


if __name__ == '__main__':
    generate_cue('move', 0.070, 330, 260, 0.48)
    generate_cue('rotate', 0.115, 440, 620, 0.42)
