#!/usr/bin/env python3
"""Checks the addon before a release: every file in the .toc exists, the XML is valid,
the Lua parses (luac), and no leftovers from the old name are in the code.
Usage: check.py <addon folder>   (env LUAC = luac command, default luac5.3)
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import xml.dom.minidom


def main(addon):
    errors = []
    toc = os.path.join(addon, "FaithHeals.toc")
    listed = [l.strip() for l in open(toc, encoding="utf-8") if l.strip() and not l.startswith("#")]
    for fn in listed:
        if not os.path.exists(os.path.join(addon, fn.replace("\\", "/"))):
            errors.append("the .toc lists %s but it is missing" % fn)
    for fn in glob.glob(os.path.join(addon, "*.lua")):
        if os.path.basename(fn) not in listed:
            errors.append("%s is not in the .toc" % os.path.basename(fn))
    for fn in glob.glob(os.path.join(addon, "*.xml")):
        try:
            xml.dom.minidom.parse(fn)
        except Exception as e:  # noqa: BLE001
            errors.append("%s: %s" % (os.path.basename(fn), e))
    for fn in glob.glob(os.path.join(addon, "*.lua")):
        text = open(fn, encoding="utf-8").read()
        if re.search(r"JennieHeals|jennieheals", text):
            errors.append("%s still mentions the old name" % os.path.basename(fn))
    luac = os.environ.get("LUAC", "luac5.3")
    if shutil.which(luac):
        for fn in sorted(glob.glob(os.path.join(addon, "*.lua"))):
            r = subprocess.run([luac, "-p", fn], capture_output=True, text=True)
            if r.returncode != 0:
                errors.append(r.stderr.strip())
    else:
        print("note: %s not found, Lua syntax not checked" % luac)
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print("checks passed")


if __name__ == "__main__":
    main(sys.argv[1])
