#!/usr/bin/env python3
"""Independent WAV, legacy firmware and C99 adapter verification; stdlib only."""
import subprocess, wave, struct, math, json, os, shutil
os.environ["ZIG_GLOBAL_CACHE_DIR"]=os.path.abspath(".zig-cache/global")
from pathlib import Path
def run(command,check=True):
    if shutil.which("rtk"): command=["rtk","proxy"]+command
    subprocess.run(command,check=check)
run(["zig","build"],check=True)
run(["./zig-out/bin/tone-render"],check=True)
run(["c++","-std=c++17","-ffp-contract=off","tools/reference.cpp","-o",".zig-cache/tone-reference"],check=True)
run([".zig-cache/tone-reference"],check=True)
run(["cc","-std=c99","-Iintegration","-I.zig-cache","tools/export_smoke.c","-lm","-o",".zig-cache/export-smoke"],check=True)
run([".zig-cache/export-smoke"],check=True)
with wave.open("tone.wav","rb") as w:
    assert (w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes())==(1,2,44100,44100)
    pcm=struct.unpack("<44100h",w.readframes(44100))
legacy=struct.unpack("<44100h",Path(".zig-cache/legacy.pcm").read_bytes())
portable=struct.unpack("<44100h",Path(".zig-cache/portable.pcm").read_bytes())
max_portable=max(abs(a-b) for a,b in zip(pcm,portable))
steady=max(abs(pcm[i]-legacy[i]) for i in range(200,21800))
assert max_portable<=3, max_portable
assert steady<=3, steady
assert not any(pcm[23000:])
result={"sample_rate":44100,"frames":len(pcm),"format":"mono signed PCM16 LE","peak":max(abs(s) for s in pcm)/32767,"rms":math.sqrt(sum(s*s for s in pcm)/len(pcm))/32767,"clipped_samples":sum(abs(s)>=32767 for s in pcm),"portable_c_max_error_lsb":max_portable,"legacy_steady_max_error_lsb":steady,"legacy_full_max_error_lsb":max(abs(a-b) for a,b in zip(pcm,legacy)),"legacy_difference":"Legacy one-shot releases before tone end; Studio key release starts at 500ms. Legacy attack denominator N, Studio N-1. Float libm differences allowed up to 3 LSB."}
Path("docs/pcm-verification.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(result,indent=2))
