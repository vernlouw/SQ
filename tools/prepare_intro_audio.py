#!/usr/bin/env python3
"""Lightly master user-supplied intro recordings without cuts or rearrangement.

Usage:
    python3 tools/prepare_intro_audio.py --fanfare /path/to/fanfare.mp3 \
        --theme /path/to/complete_intro.mp3

Requires FFmpeg and FFprobe on PATH. The inputs are left untouched. This is
gentle mastering of existing recordings, not reorchestration or a new score.
No copyrighted recording is included in this preparation script itself.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

RATE = 44100
BASE = "highpass=f=25:p=2,equalizer=f=2600:t=q:w=0.7:g=0.6"
TARGET_I = -18
TARGET_TP = -2
# A high permitted range lets linear normalization preserve existing dynamics.
TARGET_LRA = 50


def execute(command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result


def checksum(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def probe(source):
    data = json.loads(execute([
        "ffprobe", "-v", "error", "-select_streams", "a:0",
        "-show_entries", "format=duration,size:stream=sample_rate,channels,codec_name",
        "-of", "json", str(source),
    ]).stdout)
    frames = execute([
        "ffprobe", "-v", "error", "-select_streams", "a:0", "-show_frames",
        "-show_entries", "frame=nb_samples", "-of", "csv=p=0", str(source),
    ]).stdout
    sample_count = sum(int(line.split(",")[0]) for line in frames.splitlines() if line.split(",")[0].isdigit())
    data["decoded_samples"] = sample_count
    data["decoded_seconds"] = sample_count / int(data["streams"][0]["sample_rate"])
    return data


def loudness(source, filters=BASE):
    norm = f"loudnorm=I={TARGET_I}:TP={TARGET_TP}:LRA={TARGET_LRA}:print_format=json"
    chain = f"{filters},{norm}" if filters else norm
    result = execute([
        "ffmpeg", "-hide_banner", "-nostdin", "-i", str(source),
        "-map", "0:a:0", "-af", chain, "-f", "null", "-",
    ])
    matches = re.findall(r'\{\s*"input_i"[\s\S]*?\}', result.stderr)
    if not matches:
        raise RuntimeError("FFmpeg did not provide loudness measurements")
    return json.loads(matches[-1])


def prepare(source, destination, codec):
    if source.resolve() == destination.resolve():
        raise ValueError("The output path must be different from the source recording")
    source_digest = checksum(source)
    before = probe(source)
    duration = before["decoded_seconds"]
    measurement = loudness(source)
    options = ":".join([
        f"I={TARGET_I}", f"TP={TARGET_TP}", f"LRA={TARGET_LRA}",
        f"measured_I={measurement['input_i']}",
        f"measured_TP={measurement['input_tp']}",
        f"measured_LRA={measurement['input_lra']}",
        f"measured_thresh={measurement['input_thresh']}",
        f"offset={measurement['target_offset']}", "linear=true", "print_format=json",
    ])
    chain = f"{BASE},loudnorm={options},afade=t=in:st=0:d=0.025,afade=t=out:st={max(0, duration - .065):.8f}:d=0.065"
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "ffmpeg", "-hide_banner", "-nostdin", "-y", "-i", str(source),
        "-map", "0:a:0", "-map_metadata", "-1", "-vn", "-af", chain,
        "-ar", str(RATE), "-ac", "2",
    ]
    if codec == "wav":
        command.extend(["-c:a", "pcm_s16le"])
    else:
        command.extend(["-c:a", "libvorbis", "-q:a", "5"])
    command.append(str(destination))
    rendered = execute(command)
    normalization = re.findall(r'\{\s*"input_i"[\s\S]*?\}', rendered.stderr)
    after = probe(destination)
    final_loudness = loudness(destination, "")
    # Container timing may include MP3 padding; decoded duration is authoritative.
    assert abs(after["decoded_seconds"] - duration) < .02, "Recording duration changed"
    assert after["streams"][0]["sample_rate"] == str(RATE)
    assert after["streams"][0]["channels"] == 2
    assert checksum(source) == source_digest, "Source recording changed"
    return {
        "source_name": source.name,
        "source_sha256": source_digest,
        "source_container_seconds": float(before["format"]["duration"]),
        "source_decoded_seconds": duration,
        "destination": destination.name,
        "output_seconds": after["decoded_seconds"],
        "output_bytes": int(after["format"]["size"]),
        "output_sha256": checksum(destination),
        "source_loudness_after_light_eq": measurement,
        "normalization": json.loads(normalization[-1]) if normalization else None,
        "final_loudness": final_loudness,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fanfare", type=Path, required=True)
    parser.add_argument("--theme", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "assets" / "audio")
    args = parser.parse_args()
    reports = [
        prepare(args.fanfare, args.output / "intro_fanfare.wav", "wav"),
        prepare(args.theme, args.output / "intro_theme.ogg", "ogg"),
    ]
    print(json.dumps(reports, indent=2))


if __name__ == "__main__":
    main()
