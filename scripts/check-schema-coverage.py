#!/usr/bin/env python3
"""Assert every key in values.yaml is declared in values.schema.json.

The schema is deliberately permissive at runtime: unknown top-level keys are
accepted so that values files carried over from 0.x, YAML anchors and keys read
by external tooling do not break a user's install.

That leniency should not extend to us. A key added to values.yaml without a
matching entry in the schema would silently lose its validation and its editor
hover text, so this check keeps the two in step. Strict here, forgiving there.

    scripts/check-schema-coverage.py --chart charts/penpot
"""

from __future__ import annotations

import argparse
import os
import pathlib
import sys

import yaml
import json


def log(level: str, msg: str, file: str | None = None) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        where = f" file={file}::" if file else "::"
        print(f"::{level}{where}{msg}")
    else:
        print(f"{level.upper()}: {msg}" + (f" ({file})" if file else ""))


def declared_paths(schema: dict) -> set[str]:
    """Dotted paths the schema describes, following $ref into definitions."""
    found: set[str] = set()

    def resolve(node, depth=0):
        while isinstance(node, dict) and "$ref" in node and depth < 10:
            ref = node["$ref"]
            if not ref.startswith("#/definitions/"):
                return node
            node = schema["definitions"][ref.split("/")[-1]]
            depth += 1
        return node

    def walk(node, prefix=""):
        node = resolve(node)
        if not isinstance(node, dict):
            return
        for key, value in node.get("properties", {}).items():
            path = f"{prefix}.{key}" if prefix else key
            found.add(path)
            walk(value, path)
        for combinator in ("allOf", "anyOf", "oneOf"):
            for sub in node.get(combinator, []):
                walk(sub, prefix)

    walk(schema)
    return found


def value_paths(values) -> set[str]:
    found: set[str] = set()

    def walk(node, prefix=""):
        if isinstance(node, dict):
            for key, value in node.items():
                path = f"{prefix}.{key}" if prefix else key
                found.add(path)
                walk(value, path)

    walk(values)
    return found


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


def check(chart: str) -> bool:
    values_file = os.path.join(chart, "values.yaml")
    schema_file = os.path.join(chart, "values.schema.json")

    if not os.path.exists(schema_file):
        print(f"{chart}: no values.schema.json, skipping")
        return True

    values = yaml.safe_load(open(values_file))
    declared = declared_paths(json.load(open(schema_file)))
    paths = value_paths(values)
    missing = sorted(p for p in paths if p not in declared)

    if missing:
        for path in missing:
            log("error", f"'{path}' is in values.yaml but not described in "
                         "values.schema.json", schema_file)
        print(f"\n{chart}: {len(missing)} key(s) missing from the schema.")
        return False

    print(f"{chart}: all {len(paths)} keys in values.yaml are described in the schema")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--chart", help="a single chart directory; defaults to every chart found")
    parser.add_argument("--charts-dir", default="charts",
                        help="where to look for charts when --chart is omitted")
    args = parser.parse_args()

    return 0 if all([check(c) for c in resolve_charts(args)]) else 1


if __name__ == "__main__":
    sys.exit(main())
