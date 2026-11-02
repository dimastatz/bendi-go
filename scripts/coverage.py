"""Checks the LCOV report from `luau --coverage` against the minimum line coverage for src/core.

Every module in src/core must be required by at least one spec. A module that no spec loads
has no coverage data, and fails the check instead of being silently skipped.
"""

import os
import pathlib
import sys

THRESHOLD = 95.0
CORE_DIR = pathlib.Path("src/core")


def parse_lcov(report):
    """Returns {source path: {line number: hit count}} from an LCOV report."""
    files = {}
    current = None
    for line in report.read_text().splitlines():
        if line.startswith("SF:"):
            current = os.path.normpath(line[3:].lstrip("@")).replace(os.sep, "/")
            files.setdefault(current, {})
        elif line.startswith("DA:") and current is not None:
            number, hits = (int(part) for part in line[3:].split(",")[:2])
            files[current][number] = max(files[current].get(number, 0), hits)
    return files


def find_lines(files, module):
    """Returns the coverage lines for a module, matching paths with or without the extension."""
    names = (module.as_posix(), module.with_suffix("").as_posix())
    for source, lines in files.items():
        if any(source == name or source.endswith("/" + name) for name in names):
            return lines
    return None


def main():
    report = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "coverage.out")
    files = parse_lcov(report)
    modules = sorted(CORE_DIR.rglob("*.luau"))

    covered = total = 0
    untested = []
    print(f"\n{'Module':<50} {'Lines':>7} {'Covered':>8}")
    for module in modules:
        lines = find_lines(files, module)
        if lines is None:
            untested.append(module.as_posix())
            continue
        hit = sum(1 for hits in lines.values() if hits > 0)
        covered += hit
        total += len(lines)
        percent = 100.0 * hit / len(lines) if lines else 100.0
        print(f"{module.as_posix():<50} {len(lines):>7} {percent:>7.1f}%")

    percent = 100.0 * covered / total if total else 100.0
    print(f"{'Total':<50} {total:>7} {percent:>7.1f}%\n")

    failed = False
    if untested:
        print("No spec requires these modules:", *untested, sep="\n  ")
        print("Files in the coverage report:", *sorted(files), sep="\n  ")
        failed = True
    if percent < THRESHOLD:
        print(f"Line coverage {percent:.1f}% is below the required {THRESHOLD:.0f}%")
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
