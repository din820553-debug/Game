"""Configure the ephemeral CI editor; never store signing keys in the repo."""
import json
import os
import pathlib
import subprocess

config = pathlib.Path.home() / ".config/godot"
config.mkdir(parents=True, exist_ok=True)
keystore = pathlib.Path(os.environ["RUNNER_TEMP"]) / "night-courier-debug.keystore"
subprocess.run([
    "keytool", "-genkeypair", "-keystore", str(keystore),
    "-storepass", "android", "-alias", "androiddebugkey", "-keypass", "android",
    "-dname", "CN=Android Debug,O=Night Courier,C=US",
    "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
], check=True)
settings = {
    "export/android/android_sdk_path": os.environ["ANDROID_HOME"],
    "export/android/java_sdk_path": os.environ["JAVA_HOME"],
    "export/android/debug_keystore": str(keystore),
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}
text = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
text += "\n".join(f"{key} = {json.dumps(value)}" for key, value in settings.items())
(config / "editor_settings-4.3.tres").write_text(text + "\n", encoding="utf-8")
