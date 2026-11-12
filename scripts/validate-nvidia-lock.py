#!/usr/bin/env python3
"""Fail-closed validation for the pinned NVIDIA external-driver metadata."""

from __future__ import annotations

import re
import sys
import tomllib
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

LOCK = Path(__file__).resolve().parents[1] / "drivers/nvidia/version.lock"
REQUIRED = {
    "schema", "vendor", "version", "release_date", "architecture",
    "gpu_family", "target_gpu", "package", "variant", "url", "sha256",
    "sha256_source", "redistribution", "kernel_compatibility",
}
EXPECTED = {
    "schema": 1,
    "vendor": "NVIDIA",
    "version": "580.76.05",
    "architecture": "x86_64",
    "gpu_family": "Pascal",
    "target_gpu": "GeForce GTX 1050 Ti",
    "package": "NVIDIA-Linux-x86_64-580.76.05.run",
    "variant": "full",
    "url": "https://download.nvidia.com/XFree86/Linux-x86_64/580.76.05/NVIDIA-Linux-x86_64-580.76.05.run",
    "sha256_source": "https://download.nvidia.com/XFree86/Linux-x86_64/580.76.05/NVIDIA-Linux-x86_64-580.76.05.run.sha256sum",
}
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    try:
        data = tomllib.loads(LOCK.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        return fail(f"cannot read {LOCK}: {exc}")

    missing = sorted(REQUIRED - data.keys())
    if missing:
        return fail("missing required keys: " + ", ".join(missing))

    for key, expected in EXPECTED.items():
        if data.get(key) != expected:
            return fail(f"{key}: expected {expected!r}, got {data.get(key)!r}")

    if not HEX_SHA256.fullmatch(str(data["sha256"])):
        return fail("sha256 must be exactly 64 lowercase hexadecimal characters")

    try:
        date.fromisoformat(str(data["release_date"]))
    except ValueError:
        return fail("release_date must be a valid ISO date (YYYY-MM-DD)")

    for key in ("url", "sha256_source"):
        parsed = urlparse(str(data[key]))
        if parsed.scheme != "https" or parsed.hostname != "download.nvidia.com":
            return fail(f"{key} must use HTTPS on download.nvidia.com")

    if "restricted" not in str(data["redistribution"]).lower():
        return fail("redistribution policy must explicitly retain the restricted status")

    if data["kernel_compatibility"] not in {"not_yet_tested", "build_passed", "runtime_tested"}:
        return fail("kernel_compatibility has an unsupported state")

    print(f"PASS: NVIDIA {data['version']} lock metadata is complete and pinned")
    print("NOTE: this validates metadata only, not installer bytes or hardware compatibility")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
