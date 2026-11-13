#!/usr/bin/env python3
"""Fail-closed validation for the pinned CachyOS NVIDIA 580 patch set."""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

LOCK = Path(__file__).resolve().parents[1] / "drivers/nvidia/patches.lock"
EXPECTED = {
    "schema": 1,
    "source_repository": "CachyOS/kernel-patches",
    "source_commit": "21d721415790e6717b2ece16e82e08eb98d16c00",
    "target_subdirectory": "kernel",
    "patches": [
        {
            "name": "atomic-kms-default",
            "path": "7.3/misc/nvidia-580xx/0001-Enable-atomic-kernel-modesetting-by-default.patch",
            "blob_sha1": "ffc13a0492cdb8eedcc104fe0d85395e5b5c67e5",
        },
        {
            "name": "kde-hardware-cursor",
            "path": "7.3/misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch",
            "blob_sha1": "de49cfd425fdd1073144d10d0b6e0972370348f2",
        },
    ],
}
HEX_SHA1 = re.compile(r"^[0-9a-f]{40}$")


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    try:
        data = tomllib.loads(LOCK.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        return fail(f"cannot read {LOCK}: {exc}")

    if data != EXPECTED:
        return fail("patch lock does not match the reviewed, immutable CachyOS patch set")

    if not HEX_SHA1.fullmatch(data["source_commit"]):
        return fail("source_commit must be a full lowercase Git commit SHA")

    for patch in data["patches"]:
        if not HEX_SHA1.fullmatch(patch["blob_sha1"]):
            return fail(f"{patch['name']}: blob_sha1 must be a full lowercase Git blob SHA")
        if patch["path"].startswith("/") or ".." in Path(patch["path"]).parts:
            return fail(f"{patch['name']}: unsafe patch path")

    print(
        f"PASS: {len(data['patches'])} NVIDIA 580 patches pinned to "
        f"{data['source_repository']}@{data['source_commit']}"
    )
    print("NOTE: source identity is pinned; applicability is checked against the extracted driver in CI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
