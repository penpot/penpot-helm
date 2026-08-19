#!/usr/bin/env python3
"""Check that every component image tag matches Chart.yaml's appVersion.

Components are discovered rather than listed, so this keeps working when a chart
gains a component or when another chart is added to the repository: any
top-level key holding an `image.tag` is treated as one.

The images of a chart are normally released together, so a version bump that
misses one of them ships a mismatched deployment. Cheap to check, easy to get
wrong by hand.

Usage:
    scripts/check-image-tags.py                       # every chart
    scripts/check-image-tags.py --chart charts/penpot
"""

from __future__ import annotations

import argparse
import os
import pathlib
import sys

import yaml



def log(level: str, msg: str, file: str | None = None) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        where = f" file={file}::" if file else "::"
        print(f"::{level}{where}{msg}")
    else:
        print(f"{level.upper()}: {msg}" + (f" ({file})" if file else ""))


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


def components(values: dict) -> dict[str, str]:
    """Top-level keys that carry an image.tag, mapped to that tag."""
    found = {}
    for key, value in (values or {}).items():
        if isinstance(value, dict) and isinstance(value.get("image"), dict):
            tag = value["image"].get("tag")
            if tag is not None:
                found[key] = str(tag)
    return found


def check(chart: str) -> bool:
    values_file = os.path.join(chart, "values.yaml")
    app_version = str(yaml.safe_load(open(os.path.join(chart, "Chart.yaml")))["appVersion"])
    found = components(yaml.safe_load(open(values_file)))

    if not found:
        print(f"{chart}: no components with an image tag, nothing to check")
        return True

    ok = True
    for component, tag in sorted(found.items()):
        if tag != app_version:
            log("error", f"{component}.image.tag is '{tag}' but appVersion is "
                         f"'{app_version}'", values_file)
            ok = False
        else:
            print(f"ok: {chart} {component}.image.tag == {app_version}")
    return ok


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chart", help="a single chart directory; defaults to every chart found")
    ap.add_argument("--charts-dir", default="charts",
                    help="where to look for charts when --chart is omitted")
    args = ap.parse_args()

    return 0 if all([check(c) for c in resolve_charts(args)]) else 1


if __name__ == "__main__":
    sys.exit(main())
