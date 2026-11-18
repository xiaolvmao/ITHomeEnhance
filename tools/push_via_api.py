#!/usr/bin/env python3
"""在 git push 走不通时，用 GitHub Git Data API 把当前工作区提交上去。"""
import base64
import json
import os
import subprocess
import sys

REPO = "xiaolvmao/ITHomeEnhance"
BRANCH = "master"
MESSAGE = os.environ.get("COMMIT_MESSAGE", "chore: 更新")


FILES = [
    "Makefile",
    "control",
    "README.md",
    "Sources/ITXHooks.xm",
    "Sources/ITXSettingsViewController.m",
    "Sources/ITXFeedAdFilter.h",
    "Sources/ITXFeedAdFilter.m",
]


def gh(args, payload=None):
    cmd = ["gh", "api"] + args
    if payload is not None:
        cmd += ["--input", "-"]
    proc = subprocess.run(
        cmd,
        input=json.dumps(payload) if payload is not None else None,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if proc.returncode != 0:
        sys.exit(f"gh api {' '.join(args)} 失败:\n{proc.stderr}")
    out = proc.stdout.strip()
    return json.loads(out) if out else None


head = gh([f"repos/{REPO}/git/refs/heads/{BRANCH}"])["object"]["sha"]
print("当前 HEAD", head)

commit = gh([f"repos/{REPO}/git/commits/{head}"])
base_tree = commit["tree"]["sha"]
print("base tree", base_tree)

tree_items = []
for path in FILES:
    with open(path, "rb") as fh:
        raw = fh.read()
    blob = gh([f"repos/{REPO}/git/blobs", "--method", "POST"],
              {"content": base64.b64encode(raw).decode(), "encoding": "base64"})
    tree_items.append({"path": path, "mode": "100644", "type": "blob", "sha": blob["sha"]})
    print("  待提交", path, len(raw), "bytes ->", blob["sha"][:8])

new_tree = gh([f"repos/{REPO}/git/trees", "--method", "POST"],
              {"base_tree": base_tree, "tree": tree_items})
print("新 tree", new_tree["sha"])

new_commit = gh([f"repos/{REPO}/git/commits", "--method", "POST"],
                {"message": MESSAGE, "tree": new_tree["sha"], "parents": [head]})
print("新 commit", new_commit["sha"])

gh([f"repos/{REPO}/git/refs/heads/{BRANCH}", "--method", "PATCH"],
   {"sha": new_commit["sha"]})
print("分支已更新")
