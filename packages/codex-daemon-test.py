"""Run manually outside the Nix sandbox: python3 packages/codex-daemon-test.py /path/to/codex."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="codex-daemon-test-") as directory:
    home = Path(directory)
    settings = home / "app-server-daemon/settings.json"
    settings.parent.mkdir()
    settings.write_text(json.dumps({"updater": {"autoUpdateEnabled": False}}))
    env = {**os.environ, "CODEX_HOME": directory}

    def run(*arguments, check=True):
        return subprocess.run(
            [binary, "app-server", "daemon", *arguments],
            env=env, check=check, timeout=60, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )

    try:
        started = run("start", check=False)
        print(started.stdout)
        started.check_returncode()
        release = home / "packages/app-server-daemon/current"
        assert (release / "codex-package.json").is_file()
        assert (release / "bin/codex").is_file()
        version = run("version")
        print(version.stdout)
        status = json.loads(version.stdout)
        assert status["status"] == "running", status
        assert status["appServerVersion"] == status["cliVersion"], status
        print("Codex daemon startup passed")
    finally:
        stopped = run("stop", check=False)
        print(stopped.stdout)
        stopped.check_returncode()
