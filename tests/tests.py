#!/usr/bin/env python3
"""Test runner for the dotfiles nmt suite.

Tests are discovered from the flake's legacyPackages (test-* attributes) and
built with `nix build`.

Usage examples
--------------
List all available tests::

    dotfiles-tests -l

Run all tests::

    dotfiles-tests

Run tests whose name contains "config"::

    dotfiles-tests config

Pass extra flags through to nix build::

    dotfiles-tests -- --show-trace
"""

import argparse
import os
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path
from textwrap import dedent

SUCCESS_EMOJI = "✅"
FAILURE_EMOJI = "❌"
INFO_EMOJI = "ℹ️"


class TestRunnerError(Exception):
    pass


def _run_command(
    cmd: Sequence[str],
    *,
    cwd: Path | None = None,
    text_input: str | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            input=text_input,
            check=check,
            cwd=cwd,
        )
    except FileNotFoundError as e:
        print(
            f"{FAILURE_EMOJI} Command not found: {e.filename}. Is it in PATH?",
            file=sys.stderr,
        )
        raise TestRunnerError(f"Command not found: {e.filename}") from e
    except subprocess.CalledProcessError as e:
        print(
            f"{FAILURE_EMOJI} Command failed: {' '.join(str(a) for a in cmd)}",
            file=sys.stderr,
        )
        if e.stderr:
            print(e.stderr.strip(), file=sys.stderr)
        raise TestRunnerError("Subprocess failed.") from e


class TestRunner:
    """Discovers and runs nmt tests exposed through the flake's legacyPackages."""

    def __init__(self, repo_root: Path | None = None):
        # Default to the flake root (parent of this script's directory) so the
        # runner works correctly when invoked via `nix run` from any directory.
        self.repo_root = repo_root or Path(__file__).parent.parent

    def get_current_system(self) -> str:
        result = _run_command(
            ["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"]
        )
        return result.stdout.strip()

    def discover_tests(self) -> list[str]:
        """Return all test-* attribute names from legacyPackages."""
        system = self.get_current_system()
        nix_apply_expr = (
            'pkgs: builtins.concatStringsSep "\\n" '
            '(builtins.filter (name: builtins.match "test-.*" name != null) '
            "(builtins.attrNames pkgs))"
        )
        cmd = [
            "nix",
            "eval",
            "--raw",
            f".#legacyPackages.{system}",
            "--apply",
            nix_apply_expr,
        ]
        result = _run_command(cmd, cwd=self.repo_root)
        return [t for t in result.stdout.splitlines() if t]

    def filter_tests(self, tests: list[str], filters: list[str]) -> list[str]:
        """Keep only tests whose name contains at least one of the filter substrings."""
        if not filters:
            return tests
        return [t for t in tests if any(f in t for f in filters)]

    def run_tests(self, tests_to_run: list[str], nix_args: list[str]) -> bool:
        """Build each test derivation; return True only if all pass."""
        if not tests_to_run:
            print(f"{INFO_EMOJI} No tests selected.", file=sys.stderr)
            return True

        system = self.get_current_system()
        count = len(tests_to_run)
        print(f"{INFO_EMOJI} Running {count} test(s)...")
        failed: list[str] = []
        results: list[tuple[str, bool]] = []

        for i, test in enumerate(tests_to_run, 1):
            print(f"\n--- [{i}/{count}] {test} ---")
            cmd = [
                "nix",
                "build",
                "-L",
                "--keep-failed",
                "--no-link",
                f".#legacyPackages.{system}.{test}",
                *nix_args,
            ]
            try:
                subprocess.run(cmd, check=True, cwd=self.repo_root)
                results.append((test, True))
                print(f"{SUCCESS_EMOJI} {test}")
            except subprocess.CalledProcessError:
                results.append((test, False))
                failed.append(test)
                print(f"{FAILURE_EMOJI} {test}", file=sys.stderr)

        print("\n--- Summary ---")
        all_passed = not failed
        if all_passed:
            print(f"{SUCCESS_EMOJI} All {count} test(s) passed!")
        else:
            print(f"{FAILURE_EMOJI} {len(failed)} of {count} test(s) failed:")
            for t in failed:
                print(f"  - {t}")

        self._write_github_summary(results, count, failed)
        return all_passed

    def _write_github_summary(
        self, results: list[tuple[str, bool]], total: int, failed: list[str]
    ) -> None:
        """Write a Markdown job summary to $GITHUB_STEP_SUMMARY when running in CI."""
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if not summary_path:
            return

        lines: list[str] = ["## nmt Test Results", ""]
        lines.append("| Test | Result |")
        lines.append("|------|--------|")
        for test, passed in results:
            icon = SUCCESS_EMOJI if passed else FAILURE_EMOJI
            status = "Passed" if passed else "Failed"
            lines.append(f"| `{test}` | {icon} {status} |")

        lines.append("")
        if not failed:
            lines.append(f"{SUCCESS_EMOJI} **All {total} test(s) passed.**")
        else:
            lines.append(
                f"{FAILURE_EMOJI} **{len(failed)} of {total} test(s) failed.**"
            )
        lines.append("")

        content = "\n".join(lines) + "\n"
        try:
            with open(summary_path, "a", encoding="utf-8") as f:
                f.write(content)
            print(f"{INFO_EMOJI} Job summary written to: {summary_path}", file=sys.stderr)
        except OSError as e:
            print(f"{FAILURE_EMOJI} Failed to write job summary: {e}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Test runner for the dotfiles nmt suite.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=dedent(
            """\
            Examples:
              %(prog)s                 Run all tests interactively (no filter).
              %(prog)s -l              List all available tests.
              %(prog)s config          Run tests whose name contains 'config'.
              %(prog)s -l disabled     List tests matching 'disabled'.
              %(prog)s -- --show-trace Pass --show-trace to every nix build.
            """
        ),
    )
    parser.add_argument(
        "-l", "--list", action="store_true", help="List available tests without running them."
    )
    parser.add_argument(
        "filters",
        nargs="*",
        help="Filter tests by name substring (multiple values are OR-ed).",
    )
    parser.add_argument(
        "nix_args",
        nargs=argparse.REMAINDER,
        help="Extra arguments forwarded to nix build (must follow --).",
    )
    args = parser.parse_args()
    nix_args = [a for a in args.nix_args if a != "--"]

    runner = TestRunner()
    try:
        print(f"{INFO_EMOJI} Discovering tests...", file=sys.stderr)
        all_tests = runner.discover_tests()
        if not all_tests:
            print("No tests found.", file=sys.stderr)
            sys.exit(1)

        tests = runner.filter_tests(all_tests, args.filters)
        if not tests:
            print("No tests match the provided filter(s).", file=sys.stderr)
            sys.exit(1)

        if args.list:
            print("\n".join(tests))
            print(f"\n{INFO_EMOJI} {len(tests)} test(s) found.", file=sys.stderr)
            return

        if not runner.run_tests(tests, nix_args):
            sys.exit(1)

    except TestRunnerError:
        sys.exit(1)


if __name__ == "__main__":
    main()
