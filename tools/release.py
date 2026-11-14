#!/usr/bin/env python3
"""Releases FaithHeals when the version in CHANGELOG.md's first line is new.

Used by .github/workflows/release.yml. If the tag "FaithHeals-<version>" doesn't exist it:
  1. builds the addon (tools/build.py) and checks it (tools/check.py),
  2. packages it with the BigWigs packager, which uploads it to CurseForge when the .toc
     has "## X-Curse-Project-ID" and CF_API_KEY is set,
  3. tags the commit and makes a GitHub release with the zip.

A version containing "beta" or "alpha" becomes a beta/alpha file on CurseForge.
Environment: CF_API_KEY, GH_TOKEN, PACKAGER (path to the packager's release.sh),
LUAC (luac command for the syntax check, default luac5.3).
"""
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import build  # noqa: E402

GAME_VERSION = "1.60.1"  # WoW Forever


def run(cmd, cwd=None, env=None):
    print("+", " ".join(cmd), flush=True)
    if subprocess.run(cmd, cwd=cwd, env=env).returncode != 0:
        sys.exit("failed: " + " ".join(cmd))


def tag_exists(tag):
    return subprocess.run(["git", "rev-parse", "-q", "--verify", "refs/tags/" + tag],
                          cwd=ROOT, stdout=subprocess.DEVNULL).returncode == 0


def latest_notes(name, version):
    """The top section of CHANGELOG.md, as Markdown for CurseForge and GitHub."""
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as f:
        lines = f.read().splitlines()
    body = []
    for line in lines[1:]:
        if line.startswith("# "):
            break
        body.append(line)
    return "## %s %s\n\n%s\n" % (name, version, "\n".join(body).strip())


def main():
    name, version = build.NAME, build.version()
    tag = "%s-%s" % (name, version)
    if tag_exists(tag):
        print("%s %s is already released." % (name, version))
        return
    print("== Releasing %s %s" % (name, version), flush=True)

    addon_dir = build.build(os.path.join(ROOT, "dist"), version)
    run([sys.executable, os.path.join(ROOT, "tools", "check.py"), addon_dir])

    # The packager works on a git checkout tagged with the version. The changelog on
    # CurseForge and GitHub is only this version's notes (the full history stays in the repo).
    with open(os.path.join(addon_dir, "CHANGELOG.md"), "w", encoding="utf-8") as f:
        f.write(latest_notes(name, version))
    with open(os.path.join(addon_dir, ".pkgmeta"), "w") as f:
        f.write("package-as: %s\n\nmanual-changelog:\n  filename: CHANGELOG.md\n  markup-type: markdown\n\n"
                "ignore:\n  - CHANGELOG.md\n" % name)
    git = ["git", "-c", "user.name=github-actions[bot]",
           "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com"]
    run(["git", "init", "-q", "-b", "main"], cwd=addon_dir)
    run(["git", "add", "-A"], cwd=addon_dir)
    run(git + ["commit", "-q", "-m", tag], cwd=addon_dir)
    run(git + ["tag", "-a", version, "-m", tag], cwd=addon_dir)
    env = dict(os.environ, GITHUB_EVENT_NAME="release", GITHUB_REF="refs/tags/" + version,
               GITHUB_REF_NAME=version)
    env.pop("GITHUB_OAUTH", None)  # the GitHub release is made below, in this repo
    run([os.environ["PACKAGER"], "-g", GAME_VERSION, "-n", "{package-name}-{project-version}"],
        cwd=addon_dir, env=env)
    zips = glob.glob(os.path.join(addon_dir, ".release", "*.zip"))
    if not zips:
        sys.exit("%s: the packager made no zip" % name)

    run(git + ["tag", "-a", tag, "-m", tag], cwd=ROOT)
    run(["git", "push", "origin", tag], cwd=ROOT)
    cmd = ["gh", "release", "create", tag, zips[0], "--title", "%s %s" % (name, version),
           "--notes-file", os.path.join(addon_dir, "CHANGELOG.md")]
    if "beta" in version or "alpha" in version:
        cmd.append("--prerelease")
    run(cmd, cwd=ROOT)


if __name__ == "__main__":
    main()
