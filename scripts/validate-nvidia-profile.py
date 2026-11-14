#!/usr/bin/env python3
"""Validate the effective Kconfig required for NVIDIA Pascal fallback support."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED = {
    "PCI": ("CONFIG_PCI", {"y"}),
    "PCI MSI": ("CONFIG_PCI_MSI", {"y"}),
    "ACPI": ("CONFIG_ACPI", {"y"}),
    "firmware loader": ("CONFIG_FW_LOADER", {"y"}),
    "DRM core": ("CONFIG_DRM", {"y"}),
    "DRM KMS helpers": ("CONFIG_DRM_KMS_HELPER", {"y"}),
    "Nouveau": ("CONFIG_DRM_NOUVEAU", {"m", "y"}),
    "kernel modules": ("CONFIG_MODULES", {"y"}),
    "Rust Kbuild": ("CONFIG_RUST", {"y"}),
    "module versioning": ("CONFIG_MODVERSIONS", {"y"}),
    "extended module versioning": ("CONFIG_EXTENDED_MODVERSIONS", {"y"}),
    "DWARF symbol versioning": ("CONFIG_GENDWARFKSYMS", {"y"}),
    "DWARF5 debug info": ("CONFIG_DEBUG_INFO_DWARF5", {"y"}),
    "LTO compatibility mode": ("CONFIG_LTO_NONE", {"y"}),
    "PREEMPT_RT disabled for NVIDIA 580": ("CONFIG_PREEMPT_RT", {"n"}),
}

CONFIG_LINE = re.compile(r"^(CONFIG_[A-Z0-9_]+)=(.*)$")


def read_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = CONFIG_LINE.match(line)
        if match:
            values[match.group(1)] = match.group(2)
        elif line.startswith("# CONFIG_") and line.endswith(" is not set"):
            values[line[2:].split(" is not set", 1)[0]] = "n"
    return values


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    args = parser.parse_args()

    if not args.config.is_file():
        parser.error(f"configuration file not found: {args.config}")

    values = read_config(args.config)
    failures: list[str] = []

    for label, (symbol, accepted) in REQUIRED.items():
        actual = values.get(symbol, "n")
        status = "PASS" if actual in accepted else "FAIL"
        print(f"{status}: {label}: {symbol}={actual}")
        if status == "FAIL":
            failures.append(
                f"{label}: expected one of {', '.join(sorted(accepted))}, got {actual}"
            )

    if failures:
        print("\nNVIDIA Pascal profile validation failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("\nNVIDIA Pascal + Rust + module-versioning Kconfig validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
