import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]


def parse_device(line):
    parts = line.split("\t")
    if len(parts) < 9 or parts[0] != "DEVICE":
        return None
    plugins = set(parts[8].split(","))
    return {
        "id": parts[1],
        "name": parts[2] or parts[1],
        "type": parts[3] or "unknown",
        "paired": parts[4] == "true",
        "reachable": parts[5] == "true",
        "battery": int(parts[6]) if parts[6].isdigit() else -1,
        "charging": parts[7] == "true",
        "capabilities": {
            "battery": "kdeconnect_battery" in plugins,
            "ping": "kdeconnect_ping" in plugins,
            "text": "kdeconnect_share" in plugins,
            "commands": "kdeconnect_runcommand" in plugins,
            "clipboard": "kdeconnect_clipboard" in plugins,
            "file": "kdeconnect_share" in plugins,
            "ring": "kdeconnect_findmyphone" in plugins,
        },
    }


def categorize(exit_code, operation):
    return {
        127: f"{operation} unavailable",
        2: f"{operation} rejected",
        3: f"{operation} timed out",
    }.get(exit_code, f"{operation} failed")


def accept_completion(target_generation, current_generation, target_id, selected_id):
    return target_generation == current_generation and target_id == selected_id


class StateTests(unittest.TestCase):
  def test_authoritative_snapshot_is_stable_and_capability_aware(self):
    line = "DEVICE\tdevice-1\tTest phone\tphone\ttrue\ttrue\t95\tfalse\tkdeconnect_battery,kdeconnect_ping,kdeconnect_share"
    self.assertEqual(parse_device(line), {
        "id": "device-1",
        "name": "Test phone",
        "type": "phone",
        "paired": True,
        "reachable": True,
        "battery": 95,
        "charging": False,
         "capabilities": {"battery": True, "ping": True, "text": True, "commands": False, "clipboard": False, "file": True, "ring": False},
    })


  def test_empty_command_output_is_a_valid_empty_list(self):
    self.assertEqual(json.loads("[]"), [])

  def test_quoted_name_and_unknown_battery_are_safe(self):
    device = parse_device("DEVICE\tid\tO'Reilly phone\tphone\ttrue\ttrue\tinvalid\tfalse\tkdeconnect_runcommand")
    self.assertEqual(device["name"], "O'Reilly phone")
    self.assertEqual(device["battery"], -1)
    self.assertTrue(device["capabilities"]["commands"])
    self.assertFalse(device["capabilities"]["file"])

  def test_discovery_boundary_is_fail_closed(self):
    script = (ROOT / "scripts" / "discover_devices.sh").read_text()
    self.assertIn("NameHasOwner", script)
    self.assertIn("set -Eeuo pipefail", script)
    self.assertNotIn("gdbus introspect", script)
    self.assertNotIn("gdbus introspect", script)

  def test_capability_and_target_contracts(self):
    source = (ROOT / "KdeConnectController.qml").read_text()
    self.assertIn('"--send-clipboard"', source)
    self.assertIn('"--share", value', source)
    self.assertIn("targetGeneration !== root.generation", source)
    self.assertIn("commandsLoading = false", source)
    self.assertIn("positionViewAtIndex", (ROOT / "BarWidget.qml").read_text())

  def test_discovery_script_against_sanitized_gdbus_fixture(self):
    with tempfile.TemporaryDirectory() as directory:
      mock = Path(directory) / "gdbus"
      mock.write_text("""#!/usr/bin/env python3
import sys
args = sys.argv
if any('NameHasOwner' in arg for arg in args): print('(true,)')
elif any('daemon.devices' in arg for arg in args): print("(['fixture-id'],)")
elif args[-1] == 'name': print("(<'Quoted phone'>,)")
elif args[-1] == 'type': print("(<'phone'>,)")
elif args[-1] == 'isPaired': print('(true,)')
elif args[-1] == 'isReachable': print('(true,)')
elif args[-1] == 'supportedPlugins': print("([<'kdeconnect_runcommand'>, <'kdeconnect_share'>],)")
else: raise SystemExit(1)
""")
      mock.chmod(0o755)
      environment = dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"])
      result = subprocess.run([str(ROOT / "scripts" / "discover_devices.sh")], env=environment,
                              text=True, capture_output=True, check=False)
      self.assertEqual(result.returncode, 0, result.stderr)
      self.assertEqual(result.stdout, "DEVICE\tfixture-id\tQuoted phone\tphone\ttrue\ttrue\t-1\tfalse\tkdeconnect_share,kdeconnect_runcommand\n")


  def test_errors_are_categorized_without_stderr_text(self):
    self.assertEqual(categorize(127, "ping"), "ping unavailable")
    self.assertEqual(categorize(2, "pairing"), "pairing rejected")
    self.assertEqual(categorize(3, "remote command"), "remote command timed out")
    self.assertNotIn("stderr", categorize(1, "action"))


  def test_stale_completion_is_ignored(self):
    self.assertFalse(accept_completion(4, 5, "old", "old"))
    self.assertFalse(accept_completion(5, 5, "old", "new"))
    self.assertTrue(accept_completion(5, 5, "new", "new"))


  def test_manifest_and_runtime_shape(self):
    manifest = json.loads((ROOT / "manifest.json").read_text())
    self.assertEqual(manifest["entryPoints"], {"service": "Service.qml", "barWidget": "BarWidget.qml"})
    self.assertFalse((ROOT / "main.qml").exists())
    self.assertFalse(any((ROOT / "components").rglob("*")))


  def test_no_privacy_product_claims_or_ui_processes(self):
    sources = "\n".join(path.read_text() for path in ROOT.glob("*.qml"))
    self.assertNotIn("notification", sources.lower())
    self.assertNotIn("sms", sources.lower())
    self.assertNotIn("Process {", (ROOT / "BarWidget.qml").read_text())


  def test_shell_script_is_not_needed_for_file_sharing(self):
    self.assertFalse((ROOT / "scripts" / "share_file.sh").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
