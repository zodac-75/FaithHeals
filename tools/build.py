#!/usr/bin/env python3
"""Builds dist/FaithHeals/ from FaithHeals/ and fills in the version.

The version comes from the first line of CHANGELOG.md ("# FaithHeals 0.1.0-alpha").
  python3 tools/build.py              build dist/FaithHeals/
  python3 tools/build.py --zip DIR    also write FaithHeals-<version>.zip into DIR
"""
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "FaithHeals")
NAME = "FaithHeals"


def version():
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as f:
        first = f.readline().strip()
    m = re.match(r"#\s+%s\s+(\S+)\s*$" % NAME, first)
    if not m:
        sys.exit('CHANGELOG.md must start with "# %s <version>", found: %r' % (NAME, first))
    return m.group(1)


def build(out=None, ver=None):
    """Copy the addon to <out>/FaithHeals and set the .toc version. Returns the addon folder."""
    out = out or os.path.join(ROOT, "dist")
    ver = ver or version()
    addon = os.path.join(out, NAME)
    if os.path.exists(addon):
        shutil.rmtree(addon)
    shutil.copytree(SRC, addon, ignore=shutil.ignore_patterns("__pycache__", "*.bak"))
    toc = os.path.join(addon, NAME + ".toc")
    with open(toc, encoding="utf-8") as f:
        text = f.read()
    text, n = re.subn(r"(?m)^## Version:.*$", "## Version: " + ver, text)
    if n != 1:
        sys.exit("the .toc needs exactly one '## Version:' line")
    with open(toc, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return addon


def make_zip(addon, dest_dir, ver):
    os.makedirs(dest_dir, exist_ok=True)
    path = os.path.join(dest_dir, "%s-%s.zip" % (NAME, ver))
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for folder, _, files in os.walk(addon):
            for fn in sorted(files):
                full = os.path.join(folder, fn)
                z.write(full, os.path.join(NAME, os.path.relpath(full, addon)).replace(os.sep, "/"))
    return path


if __name__ == "__main__":
    v = version()
    addon = build(ver=v)
    print("built", addon, v)
    if "--zip" in sys.argv:
        print("zip", make_zip(addon, sys.argv[sys.argv.index("--zip") + 1], v))
