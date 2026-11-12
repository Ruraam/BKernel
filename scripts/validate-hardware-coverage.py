#!/usr/bin/env python3
"""Validate that x86_64 allmodconfig retains major upstream driver subsystems."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED = {
    "Architecture 64-bit": "CONFIG_64BIT",
    "Architecture x86_64": "CONFIG_X86_64",
    "PCI": "CONFIG_PCI",
    "USB": "CONFIG_USB",
    "ATA/SATA": "CONFIG_ATA",
    "SCSI": "CONFIG_SCSI",
    "NVMe": "CONFIG_BLK_DEV_NVME",
    "Networking": "CONFIG_NET",
    "Wi-Fi": "CONFIG_WLAN",
    "Bluetooth": "CONFIG_BT",
    "Audio": "CONFIG_SOUND",
    "DRM graphics": "CONFIG_DRM",
}

CONFIG_LINE = re.compile(r"^(CONFIG_[A-Z0-9_]+)=(.*)$")


def read_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = CONFIG_LINE.match(line)
        if match:
            values[match.group(1)] = match.group(2)
        elif line.startswith("# CONFIG_") and line.endswith(" is not set"):
            name = line[2:].split(" is not set", 1)[0]
            values[name] = "n"
    return values


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    if not args.config.is_file():
        parser.error(f"configuration file not found: {args.config}")

    values = read_config(args.config)
    rows: list[tuple[str, str, str]] = []
    failures: list[str] = []

    for label, symbol in REQUIRED.items():
        value = values.get(symbol, "n")
        status = "PASS" if value in {"y", "m"} else "FAIL"
        rows.append((label, symbol, value))
        if status == "FAIL":
            failures.append(f"{label}: {symbol} is {value}, expected y or m")

    report = [
        "BKernel x86_64 allmodconfig hardware-subsystem coverage",
        "Scope: Kconfig presence only; this is not a hardware runtime certification.",
        "",
        "Subsystem | Kconfig symbol | Value",
        "----------|----------------|------",
    ]
    report.extend(f"{label} | {symbol} | {value}" for label, symbol, value in rows)
    report.extend(["", f"Result: {'FAIL' if failures else 'PASS'}"])
    if failures:
        report.extend(f"- {failure}" for failure in failures)

    output = "\n".join(report) + "\n"
    print(output, end="")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output, encoding="utf-8")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
