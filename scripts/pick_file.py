#!/usr/bin/env python3
import os
import re
import subprocess
import sys
from urllib.parse import unquote

def pick_omarchy():
    paths = [os.path.expanduser("~/Downloads"), os.path.expanduser("~/Documents"), os.path.expanduser("~/Pictures"), os.path.expanduser("~/Videos")]
    existing = [p for p in paths if os.path.isdir(p)]
    if not existing:
        return None
    path_arg = ":".join(existing)
    try:
        p = subprocess.run(
            ["omarchy-menu-file", "Select file to send", path_arg, "jpg jpeg png webp gif heic avif mp4 mov m4v mkv webm avi pdf txt zip tar gz iso", "--width", "800"],
            capture_output=True,
            text=True
        )
        if p.returncode == 0 and p.stdout.strip():
            return p.stdout.strip()
    except Exception:
        pass
    return None

def pick_zenity():
    try:
        p = subprocess.run(
            ["zenity", "--file-selection", "--title=Select file to send"],
            capture_output=True,
            text=True
        )
        if p.returncode == 0 and p.stdout.strip():
            return p.stdout.strip()
    except Exception:
        pass
    return None

def pick_kdialog():
    try:
        p = subprocess.run(
            ["kdialog", "--getopenfilename", os.path.expanduser("~")],
            capture_output=True,
            text=True
        )
        if p.returncode == 0 and p.stdout.strip():
            return p.stdout.strip()
    except Exception:
        pass
    return None

def pick_portal():
    try:
        cmd_open = [
            "gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop",
            "--method", "org.freedesktop.portal.FileChooser.OpenFile",
            "", "Select file to send", "{}"
        ]
        res = subprocess.run(cmd_open, capture_output=True, text=True, timeout=5)
        if res.returncode != 0 or "request" not in res.stdout:
            return None

        m = re.search(r"'/org/freedesktop/portal/desktop/request/[^']+'", res.stdout)
        if not m:
            return None
        req_path = m.group(0).strip("'")

        proc = subprocess.Popen(
            ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", req_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        try:
            for line in proc.stdout:
                match = re.search(r"file://([^\s'\">\]]+)", line)
                if match:
                    return unquote(match.group(1))
                if "Response" in line and (re.search(r"Response\s*\(\s*[12]\s*,", line) or re.search(r"uint32\s+[12]", line)):
                    return None
        finally:
            proc.terminate()
            proc.wait()
    except Exception:
        pass
    return None

def main():
    for picker in [pick_omarchy, pick_zenity, pick_kdialog, pick_portal]:
        result = picker()
        if result and os.path.exists(result):
            print(result)
            sys.exit(0)
    sys.exit(1)

if __name__ == "__main__":
    main()
