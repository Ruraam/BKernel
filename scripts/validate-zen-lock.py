#!/usr/bin/env python3
"""Fail-closed validation for the pinned Zen Kernel patch metadata."""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path
from urllib.parse import urlparse

EXPECTED = {
    "schema": 1,
    "name": "linux-zen",
    "version": "7.3.4-zen2",
    "base_version": "7.3.4",
    "architecture": "x86_64",
    "release_tag": "v7.3.4-zen2",
    "release_id": 441987196,
    "release_commit": "f18219c1624ecbe082f05aca073d6555eee91a2d",
    "patch": "linux-v7.3.4-zen2.patch.zst",
    "patch_url": "https://github.com/zen-kernel/zen-kernel/releases/download/v7.3.4-zen2/linux-v7.3.4-zen2.patch.zst",
    "patch_sha256": "3296823f5ad0bc93308630b7574614cd687889c42f72da27d0e534ee843626d",
    "signature": "linux-v7.3.4-zen2.patch.zst.sig",
    "signature_url": "https://github.com/zen-kernel/zen-kernel/releases/download/v7.3.4-zen2/linux-v7.3.4-zen2.patch.zst.sig",
    "signature_sha256": "fc35f59330bf64297c5cf21a38d077203e15074b20fb8f51bbb660a4e0067844",
    "signature_verification": "pinned-only; trusted maintainer key not yet configured",
    "source_date_epoch": 1794335460,
}


def main() -> int:
    path = Path("zen-source.toml")
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        print(f"error: cannot read {path}: {exc}", file=sys.stderr)
        return 1

    errors = [
        f"{key}: expected {expected!r}, got {data.get(key)!r}"
        for key, expected in EXPECTED.items()
        if data.get(key) != expected
    ]
    for key in ("patch_sha256", "signature_sha256"):
        if not re.fullmatch(r"[0-9a-f]{64}", str(data.get(key, ""))):
            errors.append(f"{key}: must be 64 lowercase hexadecimal characters")

    for key in ("patch_url", "signature_url"):
        parsed = urlparse(str(data.get(key, "")))
        if parsed.scheme != "https" or parsed.hostname != "github.com":
            errors.append(f"{key}: must use HTTPS on github.com")

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print("Zen Kernel v7.3.4-zen2 source metadata: OK")
    print("Note: pinned hashes are checked against downloaded bytes in CI.")
    print("Note: detached PGP signature is pinned but not cryptographically verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
