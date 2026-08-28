#!/usr/bin/env python3
"""Run all CI verification logic on one worker and emit JUnit XML."""

import argparse
import fnmatch
import os
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

INSTALLER_PATHS = (
    "flake.nix",
    "flake.lock",
    ".flake-modules/installer.nix",
    ".flake-modules/lib/setup-shell.nix",
    ".flake-modules/home-manager/**",
    "tests/integration/**",
    "tests/junit_report.py",
    "tests/verifications.py",
    ".github/workflows/ci.yml",
)


def run_suite(suite_key: str, junit_xml: Path) -> bool:
    """Run every check in one suite, recording failures without stopping early."""
    suite_name, checks = SUITES[suite_key]
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

    write_junit_xml(junit_xml, suite_name, results)
    print(f"JUnit report written to: {junit_xml}", file=sys.stderr)
    return all(result.passed for result in results)


def changed_paths() -> list[str] | None:
    """Return paths changed by this event, or None when a safe diff is unavailable."""
    event_name = os.environ.get("GITHUB_EVENT_NAME")
    if event_name == "workflow_dispatch":
        return None

    if event_name == "pull_request":
        base_ref = os.environ.get("GITHUB_BASE_REF")
        if not base_ref:
            return None
        diff_range = f"origin/{base_ref}...HEAD"
    elif event_name == "push":
        before = os.environ.get("GITHUB_EVENT_BEFORE")
        sha = os.environ.get("GITHUB_SHA", "HEAD")
        if not before or set(before) == {"0"}:
            return None
        diff_range = f"{before}...{sha}"
    else:
        return None

    completed = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", diff_range],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        print(
            f"Could not inspect {diff_range}; running installer verification.",
            file=sys.stderr,
        )
        return None
    return [path for path in completed.stdout.splitlines() if path]


def should_run_installer() -> bool:
    """Run installer verification for relevant changes or uncertain event history."""
    paths = changed_paths()
    if paths is None:
        print("Installer verification selected: no reliable path diff.")
        return True

    matches = [
        path
        for path in paths
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in INSTALLER_PATHS)
    ]
    if matches:
        print(f"Installer verification selected by: {', '.join(matches)}")
        return True

    print("Installer verification skipped: no relevant paths changed.")
    return False


def run_all(output_dir: Path, skip_installer: bool) -> bool:
    """Run all applicable suites sequentially on the current worker."""
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    module_runner = Path(__file__).with_name("tests.py")
    modules = (
        subprocess.run(
            [
                sys.executable,
                str(module_runner),
                "--junit-xml",
                str(output_dir / "modules.xml"),
            ],
            check=False,
        ).returncode
        == 0
    )
    flake_shape = run_suite("flake-shape", output_dir / "flake-shape.xml")

    installer = True
    if not skip_installer and should_run_installer():
        installer = run_suite("installer-bootstrap", output_dir / "installer.xml")

    return modules and flake_shape and installer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("suite", choices=["all", *SUITES])
    parser.add_argument("--junit-xml", type=Path)
    parser.add_argument("--output-dir", type=Path, default=Path("test-results"))
    parser.add_argument(
        "--skip-installer",
        action="store_true",
        help="Skip the installer suite (intended for local validation only).",
    )
    args = parser.parse_args()

    if args.suite == "all":
        passed = run_all(args.output_dir, args.skip_installer)
    else:
        output_path = args.junit_xml or args.output_dir / f"{args.suite}.xml"
        passed = run_suite(args.suite, output_path)

    if not passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
