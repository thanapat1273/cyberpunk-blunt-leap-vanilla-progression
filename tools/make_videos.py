"""Makes the two perk-card videos from in-game recordings.

    py -3.10 -I tools/make_videos.py <recordings folder> <ffmpeg.exe> <radvideo64.exe> [work folder]

The game's own perk videos (base\\movies\\tutorials\\700x394\\perk_*.bk2) are
700 x 394, 30 fps, no sound, about 1,000,000 bytes per second. This script
makes ours the same way:

  1. ffmpeg cuts each recording at the chosen seconds, scales it to 700 x 394
     (lanczos) at 30 fps without sound, and writes PNG frames.
  2. RAD Video Tools encodes the frames to a Bink file at 1,000,000 bytes per
     second. The free RAD Video Tools only writes Bink 1 (its Bink 2 encoder
     needs a licence). The game's player (bin/x64/bink2w64.dll) reads Bink 1
     files too: it checks for the Bink 1 headers BIKf to BIKk, and RAD writes
     BIKk.
  3. The files go to art/video/, where tools/pack_icons.sh packs them into
     archive/pc/mod/BluntLeap.archive under bluntleap\\movies\\.

The recordings themselves are not kept in this repository.
"""
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (output name, recording file, first second, last second)
CLIPS = [
    ("perk_body_batteringram", "Battering Ram Vid 7-18.mp4", 7, 18),
    ("perk_body_thunderbreaker", "Thunder Breaker 14-25.mp4", 14, 25),
]
WIDTH, HEIGHT, FPS, RATE = 700, 394, 30, 1000000


def rad(radvideo, args, limit):
    """Runs RAD with a plain argument list. A RAD error shows a dialog that
    waits for a click, so RAD is closed if it runs past the time limit."""
    try:
        return subprocess.run([radvideo] + args, timeout=limit).returncode
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/F", "/IM", os.path.basename(radvideo)], capture_output=True)
        return "timed out"


def describe(path):
    d = open(path, "rb").read(48)
    frames, = struct.unpack("<I", d[8:12])
    w, h = struct.unpack("<II", d[20:28])
    num, den = struct.unpack("<II", d[28:36])
    tracks, = struct.unpack("<I", d[40:44])
    return "%s, %d frames, %d x %d, %.2f fps, %d sound tracks, %.2f MB" % (
        d[:4].decode("latin-1"), frames, w, h, num / den, tracks, os.path.getsize(path) / 1e6)


def main():
    if len(sys.argv) < 4:
        sys.exit("usage: make_videos.py <recordings folder> <ffmpeg.exe> <radvideo64.exe> [work folder]")
    recordings, ffmpeg, radvideo = sys.argv[1:4]
    work = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.environ["TEMP"], "bluntleap_videos")
    out_dir = os.path.join(HERE, "art", "video")
    os.makedirs(out_dir, exist_ok=True)
    for name, recording, first, last in CLIPS:
        frames = os.path.join(work, name)
        os.makedirs(frames, exist_ok=True)
        for old in os.listdir(frames):
            if old.endswith(".png"):
                os.remove(os.path.join(frames, old))
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                        "-ss", str(first), "-i", os.path.join(recordings, recording), "-t", str(last - first), "-an",
                        "-vf", "fps=%d,scale=%d:%d:flags=lanczos" % (FPS, WIDTH, HEIGHT),
                        os.path.join(frames, "f%04d.png")], check=True)
        count = len([f for f in os.listdir(frames) if f.endswith(".png")])
        target = os.path.join(out_dir, name + ".bk2")
        code = rad(radvideo, ["Binkc", os.path.join(frames, "f????.png*1-%d" % count), target,
                              "/Bink1", "/ForceFrameRate%d" % FPS, "/DataRate%d" % RATE, "/NoSound", "/O", "/#"], 900)
        if code != 0 or not os.path.exists(target):
            sys.exit("%s: RAD failed (%s)" % (name, code))
        print("%s: %d frames -> art/video/%s.bk2 (%s)" % (name, count, name, describe(target)))


main()
