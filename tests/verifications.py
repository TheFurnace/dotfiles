#!/usr/bin/env python3
"""Run CI verification suites and optionally emit JUnit XML."""

import argparse
import subprocess
import sys
import time
from pathlib import Path

from junit_report import TestResult, write_junit_xml


SUITES: dict[str, tuple[str, list[tuple[str, list[str]]]]] = {
    "flake-shape": (
        "Linux output evaluation",
        [
            (
                "x86_64 packages",
                [
                    "nix",
                    "eval",
                    ".#packages.x86_64-linux",
                    "--apply",
                    "builtins.attrNames",
                ],
            ),
            (
                "aarch64 packages",
                [
                    "nix",
                    "eval",
                    ".#packages.aarch64-linux",
                    "--apply",
                    "builtins.attrNames",
                ],
            ),
            (
                "x86_64 apps",
                ["nix", "eval", ".#apps.x86_64-linux", "--apply", "builtins.attrNames"],
            ),
            (
                "aarch64 apps",
                [
                    "nix",
                    "eval",
                    ".#apps.aarch64-linux",
                    "--apply",
                    "builtins.attrNames",
                ],
            ),
        ],
    ),
    "installer-bootstrap": (
        "Installer integration",
        [
            (
                "Fresh-home bootstrap",
                [
                    "nix",
                    "run",
                    "--print-build-logs",
                    ".#installer-bootstrap-test",
                    "--",
                    "--with-sudo",
                ],
            )
        ],
    ),
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("suite", choices=SUITES)
    parser.add_argument("--junit-xml", type=Path)
    args = parser.parse_args()

    suite_name, checks = SUITES[args.suite]
    results: list[TestResult] = []
    for name, command in checks:
        print(f"--- {name} ---", flush=True)
        started = time.monotonic()
        completed = subprocess.run(command, check=False)
        elapsed = time.monotonic() - started
        passed = completed.returncode == 0
        message = (
            None if passed else f"Command exited with status {completed.returncode}"
        )
        results.append(TestResult(name, passed, elapsed, message))
        print(f"{'PASS' if passed else 'FAIL'}: {name}", flush=True)

    if args.junit_xml is not None:
        write_junit_xml(args.junit_xml, suite_name, results)
        print(f"JUnit report written to: {args.junit_xml}", file=sys.stderr)

    if any(not result.passed for result in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
