"""Run Godot and fail even if a script error did not change its exit code."""
import pathlib
import subprocess
import sys

mode = sys.argv[1]
commands = {
    "import": ["godot", "--headless", "--editor", "--path", ".", "--import"],
    "tests": ["godot", "--headless", "--path", ".", "--script", "res://tests/test_game.gd"],
    "screenshots": [
        "xvfb-run", "-a", "godot", "--path", ".", "--audio-driver", "Dummy",
        "--rendering-method", "gl_compatibility", "--script", "res://tests/capture.gd"
    ],
    "android": ["godot", "--headless", "--path", ".", "--export-debug", "Android", "build/night-courier-debug.apk"],
}
pathlib.Path("build/logs").mkdir(parents=True, exist_ok=True)
try:
    result = subprocess.run(commands[mode], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=240)
except subprocess.TimeoutExpired as error:
    print(error.stdout)
    raise SystemExit("Godot timed out")
output = result.stdout
print(output)
pathlib.Path(f"build/logs/{mode}.log").write_text(output, encoding="utf-8")
if result.returncode or any(token in output for token in (
    "SCRIPT ERROR:", "Parse Error:", "TESTS FAILED", "FAIL:", "ERROR:"
)):
    raise SystemExit(1)
if mode == "tests" and "TESTS PASSED:" not in output:
    raise SystemExit("Tests did not complete")
if mode == "screenshots" and "SCREENSHOTS PASSED" not in output:
    raise SystemExit("Screenshot capture did not complete")
if mode == "android":
    apk = pathlib.Path("build/night-courier-debug.apk")
    if not apk.exists() or apk.stat().st_size < 1_000_000:
        raise SystemExit("APK missing or unexpectedly small")
