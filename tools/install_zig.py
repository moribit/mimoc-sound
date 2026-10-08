#!/usr/bin/env python3
"""CI bootstrap: official Zig 0.17.0 archive, SHA-256 verified."""
from pathlib import Path
import hashlib,json,platform,tarfile,urllib.request
version="0.17.0"
arch={"arm64":"aarch64","aarch64":"aarch64","x86_64":"x86_64","AMD64":"x86_64"}[platform.machine()]
os_name={"Darwin":"macos","Linux":"linux"}[platform.system()]
with urllib.request.urlopen("https://ziglang.org/download/index.json") as response:entry=json.load(response)[version][arch+"-"+os_name]
folder=Path(".tools");folder.mkdir(exist_ok=True)
archive=folder/"zig.tar.xz"
with urllib.request.urlopen(entry["tarball"]) as response:archive.write_bytes(response.read())
if hashlib.sha256(archive.read_bytes()).hexdigest()!=entry["shasum"]:raise SystemExit("Zig checksum mismatch")
with tarfile.open(archive) as tar:
    directory=tar.getmembers()[0].name.split("/")[0]
    tar.extractall(folder,filter="data")
print((folder/directory).resolve())
