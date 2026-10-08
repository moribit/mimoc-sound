#!/usr/bin/env python3
"""Restore the tested dependency entirely from the checked-in Git bundle."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent.parent
checkout=root/"vendor/mimoc-ui"
revision=(root/"deps/mimoc-ui.rev").read_text().strip()
if not (checkout/".git").exists():
    if checkout.exists() and any(checkout.iterdir()):
        raise SystemExit("Dependency directory is nonempty; refusing to overwrite it")
    subprocess.run(["git","clone",str(root/"deps/mimoc-ui.bundle"),str(checkout)],check=True)
    subprocess.run(["git","-C",str(checkout),"checkout","--detach",revision],check=True)
actual=subprocess.check_output(["git","-C",str(checkout),"rev-parse","HEAD"],text=True).strip()
if actual!=revision: raise SystemExit("mimoc-ui revision differs from tested pin; preserve your changes and restore the pin explicitly")
print("mimoc-ui "+actual)
