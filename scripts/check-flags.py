#!/usr/bin/env python3
"""Cross-check the Penpot flags used by the chart against the upstream flag list.

The schema enforces the *syntax* of `config.flags` (every token prefixed with
enable-/disable-). It cannot know which flag names exist, because Penpot's parser
accepts any name and silently does nothing with unknown ones, so a typo is a
no-op rather than an error.

This script reads the real list from the penpot repo, pinned to the tag matching
Chart.yaml's appVersion:

    https://github.com/penpot/penpot/blob/main/common/src/app/common/flags.cljc

**It reports warnings and exits 0 by default, on purpose.** Flags come and go
between Penpot versions, the file has moved before, and the chart may point at a
version that is not tagged yet. None of that should turn a CI run red on an
unrelated change; it should just leave a note on the PR. Pass --strict if you
want the mismatches to fail the build.

Usage:
    scripts/check-flags.py --chart charts/penpot
    scripts/check-flags.py --chart charts/penpot --strict
    scripts/check-flags.py --chart charts/penpot --flags-file /tmp/flags.cljc
"""

from __future__ import annotations

import argparse
import glob
import os
import pathlib
import re
import sys
import urllib.request

FLAGS_PATH = "common/src/app/common/flags.cljc"
RAW = "https://raw.githubusercontent.com/penpot/penpot/{ref}/" + FLAGS_PATH
FLAG_SETS = ("login", "email", "varia")

# Flags that are real and documented but never reach the Clojure parser, so they
# are absent from flags.cljc. `enable-air-gapped-conf` for instance is read by
# the nginx entrypoint of the frontend image. Anything consumed outside the
# parser has to be listed here by hand.
EXTRA_KNOWN = {"air-gapped-conf"}


def log(level: str, msg: str, file: str | None = None) -> None:
    """Print a GitHub Actions annotation, or a plain line when run locally."""
    if os.environ.get("GITHUB_ACTIONS") == "true":
        where = f" file={file}::" if file else "::"
        print(f"::{level}{where}{msg}")
    else:
        print(f"{level.upper()}: {msg}" + (f" ({file})" if file else ""))


def read_yaml(path: str):
    import yaml

    with open(path) as fh:
        return yaml.safe_load(fh) or {}


def fetch_flags_source(ref: str) -> tuple[str, str] | None:
    """Return (source, ref_used), or None if it could not be retrieved.

    Falls back to main when the tag does not exist yet (unreleased chart) or the
    file is not there under that ref.
    """
    for candidate in (ref, "main"):
        try:
            with urllib.request.urlopen(RAW.format(ref=candidate), timeout=30) as r:
                return r.read().decode("utf-8"), candidate
        except Exception as exc:  # noqa: BLE001 - any network/HTTP problem
            log("warning", f"could not fetch flags.cljc at ref {candidate}: {exc}")
    return None


def _balanced(src: str, start: int, opening: str, closing: str) -> str:
    """Return the substring of the form delimited at `start`, brackets balanced."""
    depth = 0
    for i in range(start, len(src)):
        if src[i] == opening:
            depth += 1
        elif src[i] == closing:
            depth -= 1
            if depth == 0:
                return src[start : i + 1]
    raise ValueError("unbalanced form in flags.cljc")


def parse_known_flags(src: str) -> set[str]:
    """Collect the flag names from the login/email/varia sets and the defaults.

    Returns an empty set if the upstream layout no longer matches; the caller
    treats that as "cannot check" rather than as a failure.
    """
    src = re.sub(r";;.*", "", src)  # drop comments, they mention flags too
    known: set[str] = set()

    for name in FLAG_SETS:
        m = re.search(rf"\(def\s+{name}\b", src)
        if not m:
            log("warning", f"could not find the '{name}' flag set upstream, "
                           "the file layout probably changed")
            return set()
        body = _balanced(src, src.index("#{", m.end()) + 1, "{", "}")
        known |= set(re.findall(r":([a-z0-9]+(?:-[a-z0-9]+)*)", body))

    # `default` lists already-prefixed flags and includes some (feature-*) that
    # are not members of the sets above.
    m = re.search(r"\(def\s+default\b", src)
    if m:
        body = _balanced(src, src.index("[", m.end()), "[", "]")
        for flag in re.findall(r":(?:enable|disable)-([a-z0-9]+(?:-[a-z0-9]+)*)", body):
            known.add(flag)

    return known


def flags_in(values: dict) -> list[str]:
    raw = ((values or {}).get("config") or {}).get("flags")
    return raw.split() if isinstance(raw, str) else []


def resolve_charts(args) -> list[str]:
    """Charts to act on: the one given, or every chart in the charts directory.

    The repository may grow more charts, so nothing here should assume there is
    exactly one, or that it is called penpot.
    """
    if args.chart:
        return [args.chart]
    root = pathlib.Path(args.charts_dir)
    found = sorted(str(p.parent) for p in root.glob("*/Chart.yaml"))
    if not found:
        raise SystemExit(f"error: no charts found under {root}/")
    return found


def chart_flag_files(chart: str) -> list[str]:
    """values.yaml plus the valid fixtures. Invalid ones are broken on purpose."""
    files = [os.path.join(chart, "values.yaml")]
    files += sorted(glob.glob(os.path.join(chart, "tests", "values", "valid", "*.yaml")))
    return files


def check(chart: str, known: set[str], used: str, level: str, strict: bool) -> tuple[bool, int]:
    failed, warned = False, 0
    for path in chart_flag_files(chart):
        for token in flags_in(read_yaml(path)):
            if not re.fullmatch(r"(enable|disable)-[a-z0-9]+(-[a-z0-9]+)*", token):
                # Not version dependent: the prefix is how the parser works, so
                # this one stays fatal.
                log("error", f"flag '{token}' has no enable-/disable- prefix, "
                             "Penpot will ignore it", path)
                failed = True
            elif token.split("-", 1)[1] not in known:
                log(level, f"unknown flag '{token}': not defined in penpot@{used}. "
                           "Either a typo, or a flag added/removed in another version",
                    path)
                failed = failed or strict
                warned += 1
        print(f"checked {path}")
    return failed, warned


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chart", help="a single chart directory; defaults to every chart found")
    ap.add_argument("--charts-dir", default="charts",
                    help="where to look for charts when --chart is omitted")
    ap.add_argument("--ref", help="override the penpot ref (defaults to appVersion)")
    ap.add_argument("--flags-file", help="use a local flags.cljc instead of fetching")
    ap.add_argument("--strict", action="store_true",
                    help="fail on unknown flags instead of only warning")
    args = ap.parse_args()
    level = "error" if args.strict else "warning"

    # Only charts that actually expose config.flags. Another chart in this
    # repository may have nothing to do with Penpot feature flags.
    charts = [c for c in resolve_charts(args)
              if flags_in(read_yaml(os.path.join(c, "values.yaml")))]
    if not charts:
        print("no chart declares config.flags, nothing to check")
        return 0

    failed, warned = False, 0
    for chart in charts:
        meta = read_yaml(os.path.join(chart, "Chart.yaml"))
        ref = args.ref or str(meta.get("appVersion", "main"))

        if args.flags_file:
            fetched = open(args.flags_file).read(), args.flags_file
        else:
            fetched = fetch_flags_source(ref)

        if fetched is None:
            log(level, f"{chart}: skipping the flag name check, upstream list unavailable")
            failed = failed or args.strict
            continue

        src, used = fetched
        known = parse_known_flags(src)
        if known:
            known |= EXTRA_KNOWN
        if not known:
            log(level, f"{chart}: skipping the flag name check, could not parse the list")
            failed = failed or args.strict
            continue
        print(f"{chart}: loaded {len(known)} known flags from {used}")

        chart_failed, chart_warned = check(chart, known, used, level, args.strict)
        failed = failed or chart_failed
        warned += chart_warned

    if failed:
        print("FAILED")
    elif warned:
        print(f"{warned} flag(s) not found upstream, see the warnings above")
    else:
        print("All flags are valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
