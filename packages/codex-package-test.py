"""Check the layout required by Codex daemon provisioning."""
import json
import os
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
version, target = sys.argv[2:]
manifest = json.loads((root / "codex-package.json").read_text())
assert manifest == {
    "layoutVersion": 1,
    "version": version,
    "target": target,
    "entrypoint": "bin/codex",
}
required = ["bin/codex", "bin/codex-code-mode-host", "codex-path/rg"]
if "linux" in target:
    required.append("codex-resources/bwrap")
for name in required:
    path = root / name
    assert path.is_file() and os.access(path, os.X_OK), name
for path in root.rglob("*"):
    assert path.resolve().is_relative_to(root), f"Escaping link: {path}"
    assert not (path.is_symlink() and path.is_dir()), f"Directory link: {path}"
print("Codex package layout checks passed")
