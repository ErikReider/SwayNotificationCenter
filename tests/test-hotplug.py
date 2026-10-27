#!/usr/bin/env python3
"""Exercise the built SwayNC daemon on a private headless Sway display and D-Bus."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


BUILD = Path(sys.argv.pop(1)).resolve()
SOURCE = Path(sys.argv.pop(1)).resolve()
SWAY = os.environ.get("SWAY_BIN", "sway")
SWAYMSG = os.environ.get("SWAYMSG_BIN", "swaymsg")


class HotplugTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="swaync-hotplug-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.processes = []
        self.logs = []
        self.addCleanup(self.stop)
        self.env = {
            "PATH": os.environ["PATH"],
            "HOME": str(self.root),
            "LANG": "C.UTF-8",
            "XDG_RUNTIME_DIR": str(self.root),
            "XDG_CONFIG_HOME": str(self.root),
            "GSETTINGS_SCHEMA_DIR": str(self.root),
            "GSETTINGS_BACKEND": "memory",
            "GIO_USE_VFS": "local",
            "GTK_A11Y": "none",
            "G_MESSAGES_DEBUG": "all",
            "GSK_RENDERER": "cairo",
            "WLR_BACKENDS": "headless",
            "WLR_RENDERER": "pixman",
            "WLR_HEADLESS_OUTPUTS": "1",
            "WLR_LIBINPUT_NO_DEVICES": "1",
        }
        self.run_command([
            "glib-compile-schemas", "--strict", f"--targetdir={self.root}",
            str(SOURCE / "data"),
        ])
        # No service directories: do not activate portals, keyrings or other services.
        bus_config = self.root / "bus.conf"
        bus_config.write_text(
            '<busconfig><type>session</type><listen>unix:tmpdir='
            + str(self.root)
            + '</listen><auth>EXTERNAL</auth><policy context="default">'
            '<allow own="*"/><allow send_destination="*"/>'
            '<allow receive_sender="*"/></policy></busconfig>'
        )
        bus = subprocess.Popen(
            ["dbus-daemon", "--nofork", "--print-address=1", f"--config-file={bus_config}"],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
        self.processes.append(bus)
        self.env["DBUS_SESSION_BUS_ADDRESS"] = bus.stdout.readline().strip()
        self.addCleanup(bus.stdout.close)
        config = self.root / "sway.conf"
        config.write_text("xwayland disable\nswaybg_command -\nswaynag_command -\n")
        self.launch([SWAY, "-c", str(config), "--unsupported-gpu"], "sway.log")
        self.wait(lambda: list(self.root.glob("sway-ipc.*.sock")), "Sway IPC socket")
        self.env["SWAYSOCK"] = str(next(self.root.glob("sway-ipc.*.sock")))
        self.env["WAYLAND_DISPLAY"] = next(
            p.name for p in self.root.glob("wayland-*") if p.is_socket()
        )
        self.config = self.root / "swaync.json"
        self.settings = {
            "notification-window-preferred-output": "HEADLESS-2",
            "control-center-preferred-output": "HEADLESS-2",
            "layer-shell-cover-screen": False,
            "timeout": 0,
            "widgets": ["notifications"],
            "widget-config": {"notifications": {}},
        }

    def stop(self):
        for process in reversed(self.processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for log in self.logs:
            log.close()

    def fail(self, msg=None):
        for name in ("daemon.log", "sway.log"):
            path = self.root / name
            if path.exists():
                print(f"\n--- {name} ---\n{path.read_text()[-10000:]}", file=sys.stderr)
        super().fail(msg)

    def launch(self, args, name):
        log = (self.root / name).open("w")
        self.logs.append(log)
        process = subprocess.Popen(args, env=self.env, stdout=log, stderr=log)
        self.processes.append(process)
        return process

    def run_command(self, args, *, check=True):
        result = subprocess.run(
            args, env=self.env, text=True, capture_output=True, timeout=5,
        )
        if check and result.returncode:
            self.fail(f"Command failed: {args!r}\n{result.stdout}\n{result.stderr}")
        return result

    def sway(self, command):
        result = self.run_command([SWAYMSG, command])
        self.assertTrue(all(item["success"] for item in json.loads(result.stdout)))

    def client(self, *args, check=True):
        return self.run_command(
            [str(BUILD / "src/swaync-client"), *args, "--skip-wait"], check=check,
        )

    def wait(self, predicate, description):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(0.025)
        self.fail(f"Timed out waiting for {description}")

    def start_daemon(self):
        self.config.write_text(json.dumps(self.settings))
        self.launch(
            [str(BUILD / "src/swaync"), "-c", str(self.config),
             "--custom-system-css", str(BUILD / "data/style/style.css")],
            "daemon.log",
        )
        self.wait(lambda: self.client("--count", check=False).returncode == 0, "SwayNC D-Bus")

    def notify(self):
        self.run_command([
            "gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.Notify",
            "hotplug-test", "0", "", "Hotplug regression", "Synthetic notification",
            "[]", "{}", "0",
        ])
        self.wait(lambda: self.client("--count").stdout.strip() == "1", "notification count")

    def monitors(self):
        # Query only the test display to identify the expected enter-monitor message.
        probe = (
            "import gi,json; gi.require_version('Gtk','4.0'); from gi.repository import Gtk,Gdk; "
            "Gtk.init(); d=Gdk.Display.get_default(); print(json.dumps({m.get_connector(): "
            "[m.get_manufacturer(),m.get_model(),m.get_description()] "
            "for m in d.get_monitors()}))"
        )
        output = self.run_command([sys.executable, "-c", probe]).stdout
        return json.loads(output.splitlines()[-1])

    def log_position(self):
        return len((self.root / "daemon.log").read_text())

    def expect_mapped(self, component, output, after=0):
        description = self.monitors()[output][2]
        expected = f"{component} mapped on monitor: {description},"
        self.wait(
            lambda: expected in (self.root / "daemon.log").read_text()[after:],
            expected,
        )

    def test_late_output_moves_existing_popup_and_center(self):
        self.start_daemon()
        self.notify()
        self.expect_mapped("NotificationWindow", "HEADLESS-1")
        position = self.log_position()
        self.sway("create_output")
        self.expect_mapped("NotificationWindow", "HEADLESS-2", position)
        self.assertEqual(self.client("--count").stdout.strip(), "1")
        outputs = json.loads(self.run_command([SWAYMSG, "-t", "get_outputs"]).stdout)
        self.assertEqual(next(o["name"] for o in outputs if o["focused"]), "HEADLESS-1")
        self.client("--open-panel")
        self.expect_mapped("ControlCenter", "HEADLESS-2", position)
        self.assertNotIn("CRITICAL", (self.root / "daemon.log").read_text())

    def check_reconnect(self, full_identity):
        self.sway("create_output")
        if full_identity:
            identity = " ".join(self.monitors()["HEADLESS-2"])
            self.settings["notification-window-preferred-output"] = identity
            self.settings["control-center-preferred-output"] = identity
        self.start_daemon()
        self.notify()
        self.expect_mapped("NotificationWindow", "HEADLESS-2")
        for _ in range(3):
            position = self.log_position()
            self.sway("output HEADLESS-2 disable")
            self.expect_mapped("NotificationWindow", "HEADLESS-1", position)
            position = self.log_position()
            self.sway("output HEADLESS-2 enable")
            self.expect_mapped("NotificationWindow", "HEADLESS-2", position)
            self.assertEqual(self.client("--count").stdout.strip(), "1")
        self.client("--open-panel")
        self.expect_mapped("ControlCenter", "HEADLESS-2")
        position = self.log_position()
        self.sway("output HEADLESS-2 disable")
        self.expect_mapped("ControlCenter", "HEADLESS-1", position)
        position = self.log_position()
        self.sway("output HEADLESS-2 enable")
        self.expect_mapped("ControlCenter", "HEADLESS-2", position)
        self.assertEqual(self.client("--count").stdout.strip(), "1")
        self.assertNotIn("CRITICAL", (self.root / "daemon.log").read_text())

    def test_reconnect_with_connector(self):
        self.check_reconnect(full_identity=False)

    def test_reconnect_with_full_monitor_identity(self):
        self.check_reconnect(full_identity=True)

    def test_empty_preferences_keep_compositor_selection(self):
        self.settings["notification-window-preferred-output"] = ""
        self.settings["control-center-preferred-output"] = ""
        self.start_daemon()
        self.notify()
        self.sway("create_output")
        self.expect_mapped("NotificationWindow", "HEADLESS-1")
        self.assertEqual(self.client("--count").stdout.strip(), "1")
        self.assertNotIn("CRITICAL", (self.root / "daemon.log").read_text())


if __name__ == "__main__":
    for command in (SWAY, SWAYMSG, "dbus-daemon", "gdbus"):
        if not shutil.which(command):
            sys.exit(f"Missing test dependency: {command}")
    unittest.main(verbosity=2)
