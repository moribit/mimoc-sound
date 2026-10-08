#!/usr/bin/env python3
"""Restore phase commits into this workspace without overwriting files."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent.parent
if (root/".git").exists():raise SystemExit("Existing .git found; use git fetch tone-studio.bundle main manually")
subprocess.run(["git","init",str(root)],check=True)
subprocess.run(["git","-C",str(root),"fetch",str(root/"tone-studio.bundle"),"main"],check=True)
subprocess.run(["git","-C",str(root),"reset","--mixed","FETCH_HEAD"],check=True)
