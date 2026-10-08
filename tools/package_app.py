#!/usr/bin/env python3
"""Package the compiled macOS binary as a launchable .app."""
from pathlib import Path
import shutil, plistlib
app=Path("zig-out/Tone Studio.app/Contents")
(app/"MacOS").mkdir(parents=True,exist_ok=True)
shutil.copy2("zig-out/bin/tone-studio",app/"MacOS/tone-studio")
(app/"Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable":"tone-studio","CFBundleIdentifier":"com.mimoc.tonestudio","CFBundleName":"Tone Studio","CFBundlePackageType":"APPL","CFBundleVersion":"1","NSHighResolutionCapable":True}))
print(app.parent)
