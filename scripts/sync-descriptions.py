#!/usr/bin/env python3
"""Sync the helm-docs descriptions from values.yaml into values.schema.json.

values.yaml is the single source of truth for descriptions: helm-docs renders
them into README.md, and this copies them into the schema so editors show the
same text on hover. Without it the two drift apart silently.

    scripts/sync-descriptions.py --chart charts/penpot            # write
    scripts/sync-descriptions.py --chart charts/penpot --check    # verify

Properties reached through a `$ref` live in a single shared node used by all four
components, so their description can only be synced when every component words it
the same way. When they disagree - usually because each sentence names its own
component ("Maximum number of backend replicas") - the definition keeps its
generic hand-written text and the script reports it, rather than letting the last
component silently win.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import pathlib
import re
import sys

KEY = re.compile(r"^(\s*)([A-Za-z_][\w.-]*):(.*)$")
DESC_START = re.compile(r"^\s*#\s*--\s?(.*)$")
COMMENT = re.compile(r"^\s*#\s?(.*)$")
HELM_DOCS_TAG = re.compile(r"^\s*#\s*@(section|default|ignored|raw|notationType)\b")


def log(level: str, msg: str, file: str | None = None) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        where = f" file={file}::" if file else "::"
        print(f"::{level}{where}{msg}")
    else:
        print(f"{level.upper()}: {msg}" + (f" ({file})" if file else ""))


def parse_descriptions(text: str) -> dict[str, str]:
    """Map dotted path -> helm-docs description for every annotated key."""
    descriptions: dict[str, str] = {}
    buffer: list[str] = []
    stack: list[tuple[int, str]] = []

    for line in text.splitlines():
        if not line.strip():
            buffer = []
            continue

        if line.lstrip().startswith("#"):
            buffer.append(line)
            continue

        match = KEY.match(line)
        if not match:
            buffer = []
            continue

        indent, key = len(match.group(1)), match.group(2)
        while stack and stack[-1][0] >= indent:
            stack.pop()
        stack.append((indent, key))
        path = ".".join(k for _, k in stack)

        description = extract(buffer)
        if description:
            descriptions[path] = description
        buffer = []

    return descriptions


def extract(buffer: list[str]) -> str | None:
    """Pull the description out of the comment block sitting above a key."""
    lines: list[str] = []
    started = False

    for line in buffer:
        if HELM_DOCS_TAG.match(line):
            continue  # @section/@default are helm-docs plumbing, not prose
        start = DESC_START.match(line)
        if start:
            started, lines = True, [start.group(1).rstrip()]
        elif started:
            comment = COMMENT.match(line)
            if comment:
                lines.append(comment.group(1).rstrip())

    if not started:
        return None
    return "\n".join(lines).strip() or None


def schema_nodes(schema: dict) -> tuple[dict[str, dict], dict[int, list[str]], dict[str, dict]]:
    """Map dotted path -> schema node, resolving $ref into definitions.

    Also returns, for every node reached through a $ref, the list of paths that
    share it. A shared node can only take a description all its users agree on.
    """
    found: dict[str, dict] = {}
    shared: dict[int, list[str]] = {}
    stubs: dict[str, dict] = {}

    def resolve(node):
        seen = 0
        while isinstance(node, dict) and "$ref" in node and seen < 10:
            ref = node["$ref"]
            if not ref.startswith("#/definitions/"):
                return node, False
            node = schema["definitions"][ref.split("/")[-1]]
            seen += 1
        return node, seen > 0

    def walk(node, prefix="", inherited=False):
        if not isinstance(node, dict):
            return
        for key, value in node.get("properties", {}).items():
            path = f"{prefix}.{key}" if prefix else key
            target, via_ref = resolve(value)
            is_shared = inherited or via_ref
            # The description goes on the node the editor actually reads: the
            # $ref stub carries no text of its own.
            found[path] = target if via_ref else value
            if via_ref:
                # The property itself is a $ref stub, so it can carry its own
                # description even though the constraints are shared.
                stubs[path] = value
            if is_shared:
                shared.setdefault(id(target if via_ref else value), []).append(path)
            walk(target, path, is_shared)
        for combinator in ("allOf", "anyOf", "oneOf"):
            for sub in node.get(combinator, []):
                target, via_ref = resolve(sub)
                walk(target, prefix, inherited or via_ref)

    walk(schema)
    return found, shared, stubs


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


def sync(chart: str, check: bool) -> bool:
    values_file = os.path.join(chart, "values.yaml")
    schema_file = os.path.join(chart, "values.schema.json")

    descriptions = parse_descriptions(open(values_file).read())
    schema = json.load(open(schema_file), object_pairs_hook=collections.OrderedDict)
    nodes, shared, stubs = schema_nodes(schema)

    # A node used by several components takes the description only if they all
    # agree on it; otherwise it keeps the generic hand-written one.
    conflicts: list[list[str]] = []
    blocked: set[int] = set()
    for node_id, paths in shared.items():
        wanted = {descriptions[p] for p in paths if p in descriptions}
        if len(wanted) > 1:
            blocked.add(node_id)
            conflicts.append(sorted(p for p in paths if p in descriptions))

    changed, stale, wrapped = [], [], []
    unresolved: list[list[str]] = []
    for path, node in nodes.items():
        wanted = descriptions.get(path)
        if wanted is None:
            continue

        if id(node) in blocked:
            stub = stubs.get(path)
            if stub is None:
                continue  # a leaf inside a shared definition: no place of its own
            # draft-07 ignores keywords next to $ref, so wrap it: the constraints
            # stay shared, the description becomes this property's own.
            if "$ref" in stub:
                stub["allOf"] = [collections.OrderedDict([("$ref", stub.pop("$ref"))])]
                wrapped.append(path)
            if stub.get("description") != wanted:
                stub["description"] = wanted
                changed.append(path)
            continue

        if node.get("description") != wanted:
            changed.append(path)
            node["description"] = wanted

    # Groups where no user could be given its own description.
    for group in conflicts:
        remaining = [p for p in group if p not in stubs]
        if remaining:
            unresolved.append(remaining)

    # Descriptions the schema carries for keys values.yaml never documents.
    for path, node in nodes.items():
        if "description" in node and path not in descriptions:
            stale.append(path)

    orphans = sorted(set(descriptions) - set(nodes))
    conflicts.sort()

    if check:
        if changed:
            for path in changed:
                log("error", f"description out of sync with values.yaml: {path}",
                    schema_file)
            print(f"\n{len(changed)} description(s) differ. Run "
                  "scripts/sync-descriptions.py to fix.")
            return False
        print(f"{chart}: all {len(descriptions)} descriptions are in sync")
        return True

    with open(schema_file, "w") as fh:
        json.dump(schema, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print(f"synced {len(changed)} description(s) into {schema_file}")
    if stale:
        print(f"\n{len(stale)} schema-only description(s), kept as written "
              "(no helm-docs comment in values.yaml):")
        for path in stale:
            print("  ", path)
    if wrapped:
        print(f"\nwrapped {len(wrapped)} $ref(s) in allOf so they can carry their "
              "own description")
    if unresolved:
        total = sum(len(g) for g in unresolved)
        print(f"\n{total} key(s) in {len(unresolved)} shared definition(s) keep the "
              "generic description (they are leaves inside a shared node):")
        for group in unresolved:
            print("  ", " | ".join(group))
    if orphans:
        print(f"\n{len(orphans)} documented key(s) with no schema property:")
        for path in orphans:
            print("  ", path)
    return True



def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--chart", help="a single chart directory; defaults to every chart found")
    parser.add_argument("--charts-dir", default="charts",
                        help="where to look for charts when --chart is omitted")
    parser.add_argument("--check", action="store_true",
                        help="report drift and exit non-zero instead of writing")
    args = parser.parse_args()

    results = []
    for chart in resolve_charts(args):
        if not os.path.exists(os.path.join(chart, "values.schema.json")):
            print(f"{chart}: no values.schema.json, skipping")
            continue
        results.append(sync(chart, args.check))
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
