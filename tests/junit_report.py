"""Small JUnit XML writer shared by the repository's test runners."""

from dataclasses import dataclass
from pathlib import Path
import xml.etree.ElementTree as ET


@dataclass(frozen=True)
class TestResult:
    name: str
    passed: bool
    elapsed: float
    message: str | None = None


def write_junit_xml(
    output_path: Path,
    suite_name: str,
    results: list[TestResult],
) -> None:
    """Write one JUnit test suite to ``output_path``."""
    failures = sum(not result.passed for result in results)
    duration = sum(result.elapsed for result in results)
    root = ET.Element(
        "testsuites",
        {
            "name": "dotfiles",
            "tests": str(len(results)),
            "failures": str(failures),
            "time": f"{duration:.3f}",
        },
    )
    suite = ET.SubElement(
        root,
        "testsuite",
        {
            "name": suite_name,
            "tests": str(len(results)),
            "failures": str(failures),
            "time": f"{duration:.3f}",
        },
    )
    for result in results:
        case = ET.SubElement(
            suite,
            "testcase",
            {
                "name": result.name,
                "classname": suite_name,
                "time": f"{result.elapsed:.3f}",
            },
        )
        if not result.passed:
            failure = ET.SubElement(
                case,
                "failure",
                {"message": result.message or "command failed", "type": "command"},
            )
            failure.text = result.message or "command failed"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(root)
    ET.ElementTree(root).write(output_path, encoding="utf-8", xml_declaration=True)
