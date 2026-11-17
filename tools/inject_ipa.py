#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 ITHomeEnhance.dylib 注入到 IT之家 IPA 里，输出可交给 TrollStore 安装的包。

用法:
    python tools/inject_ipa.py IT之家-9.52.ipa ITHomeEnhance.dylib -o IT之家-9.52-enhance.ipa

依赖（二选一）:
    pip install lief
    或  insert_dylib（macOS: brew install insert_dylib）

注意:
    * 需要已脱壳（cryptid = 0）的 IPA，App Store 原始包注入后无法运行
    * 注入会破坏原签名，TrollStore / 自签工具安装时会重新签名，属正常现象
"""

import argparse
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import zipfile

DYLIB_NAME = "ITHomeEnhance.dylib"
LOAD_PATH = "@executable_path/Frameworks/" + DYLIB_NAME


def log(msg):
    print("[*] " + msg)


def fail(msg):
    print("[!] " + msg, file=sys.stderr)
    sys.exit(1)


def unpack(ipa, workdir):
    with zipfile.ZipFile(ipa) as z:
        z.extractall(workdir)
    payload = os.path.join(workdir, "Payload")
    if not os.path.isdir(payload):
        fail("IPA 结构异常：找不到 Payload 目录")
    apps = [d for d in os.listdir(payload) if d.endswith(".app")]
    if len(apps) != 1:
        fail("Payload 里应当只有一个 .app，实际找到 %d 个" % len(apps))
    return os.path.join(payload, apps[0])


def is_encrypted(binary_path):
    """读 LC_ENCRYPTION_INFO 判断是否还是 App Store 加密包"""
    with open(binary_path, "rb") as f:
        data = f.read()
    if len(data) < 32:
        return False
    magic = int.from_bytes(data[:4], "little")
    if magic != 0xFEEDFACF:
        return False
    ncmds = int.from_bytes(data[16:20], "little")
    off = 32
    for _ in range(ncmds):
        cmd = int.from_bytes(data[off:off + 4], "little")
        size = int.from_bytes(data[off + 4:off + 8], "little")
        if cmd in (0x21, 0x2C):
            cryptid = int.from_bytes(data[off + 16:off + 20], "little")
            if cryptid != 0:
                return True
        off += size
    return False


def inject_with_lief(binary_path):
    try:
        import lief
    except ImportError:
        return False
    try:
        fat = lief.MachO.parse(binary_path)
        try:
            count = len(fat)
        except TypeError:
            count = 1
        for i in range(count):
            binary = fat.at(i) if hasattr(fat, "at") else fat
            if any(LOAD_PATH in x.name for x in binary.libraries):
                log("已经注入过，跳过 %s" % binary.header.cpu_type)
                continue
            binary.add_library(LOAD_PATH)
        fat.write(binary_path)
        return True
    except Exception as e:  # noqa: BLE001
        log("lief 注入失败：%s" % e)
        return False


def inject_with_insert_dylib(binary_path):
    for tool in ("insert_dylib", "optool"):
        if shutil.which(tool):
            cmd = ([tool, "--inplace", "--weak", LOAD_PATH, binary_path]
                   if tool == "insert_dylib"
                   else [tool, "install", "-c", LOAD_PATH, "-t", binary_path])
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode == 0:
                return True
            log("%s 失败：%s" % (tool, r.stderr.strip()))
    return False


def verify(binary_path):
    with open(binary_path, "rb") as f:
        data = f.read()
    return LOAD_PATH.encode() in data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ipa", help="原始（已脱壳）IPA")
    ap.add_argument("dylib", help="编译出来的 ITHomeEnhance.dylib")
    ap.add_argument("-o", "--output", help="输出 IPA 路径")
    ap.add_argument("--keep-workdir", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.ipa):
        fail("找不到 IPA：%s" % args.ipa)
    if not os.path.isfile(args.dylib):
        fail("找不到 dylib：%s" % args.dylib)

    output = args.output or os.path.splitext(args.ipa)[0] + "-enhance.ipa"
    workdir = tempfile.mkdtemp(prefix="itx-inject-")

    try:
        app = unpack(args.ipa, workdir)
        info_path = os.path.join(app, "Info.plist")
        with open(info_path, "rb") as f:
            info = plistlib.load(f)
        log("目标 App: %s (%s)" % (info.get("CFBundleDisplayName", "?"),
                                   info.get("CFBundleIdentifier", "?")))

        exe = os.path.join(app, info["CFBundleExecutable"])
        if is_encrypted(exe):
            fail("这个 IPA 仍然是 App Store 加密状态，请先脱壳再注入")

        frameworks = os.path.join(app, "Frameworks")
        os.makedirs(frameworks, exist_ok=True)
        shutil.copy2(args.dylib, os.path.join(frameworks, DYLIB_NAME))

        if not inject_with_lief(exe) and not inject_with_insert_dylib(exe):
            fail("注入失败：请先 pip install lief，或安装 insert_dylib")

        if not verify(exe):
            fail("注入后没有在二进制里找到 load command，请检查 dylib 名字")

        log("已写入 LC_LOAD_DYLIB: %s" % LOAD_PATH)

        # 重新打包
        if os.path.exists(output):
            os.remove(output)
        with zipfile.ZipFile(output, "w", zipfile.ZIP_STORED) as z:
            for root, _, files in os.walk(workdir):
                for name in files:
                    full = os.path.join(root, name)
                    arc = os.path.relpath(full, workdir)
                    z.write(full, arc)

        log("完成：%s (%.1f MB)" % (output, os.path.getsize(output) / 1024 / 1024))
        log("下一步：把该 IPA 交给 TrollStore 安装，或在 TrollFools 里直接注入 dylib")
    finally:
        if not args.keep_workdir:
            shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
