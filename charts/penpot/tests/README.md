# Chart test fixtures

Values files used by `.github/workflows/values-schema.yml` to check that
`values.schema.json` accepts what it should and rejects what it shouldn't.

They live under the chart because they describe this chart, and `.helmignore`
keeps them out of the published package. The pattern there is `/tests/`, anchored
on purpose: a bare `tests/` would also match `templates/tests/`, which holds the
helm test hook and has to ship.

The scripts that consume them live in the repository's `scripts/` directory,
alongside the existing shell tooling. `check-*` verify and are run by CI;
`sync-*` writes and is run by pre-commit.

Those scripts are not tied to this chart. With no `--chart` they act on every
directory under `charts/` that holds a `Chart.yaml`, skipping the ones with
nothing to check — no `values.schema.json`, no `config.flags` — and the workflow
builds its matrix the same way. A second chart added to this repository is
covered without touching either.

- `valid/` — realistic overrides that **must** pass `helm lint` and `helm template`.
- `invalid/` — overrides that **must** be rejected by the schema. The workflow
  also asserts the failure comes from schema validation and not from a template
  error, so a broken template can't make these pass by accident.

Each file is merged on top of the chart defaults, so fixtures only contain the
keys under test.

## Adding a case

Drop a new `.yaml` file into `valid/` or `invalid/` with a comment on the first
line explaining what it covers. Nothing else to wire up; the workflow globs both
directories.

The numeric prefixes only give the files a stable reading order, roughly from
general to specific. They are not identifiers and nothing refers to them, so
renumber freely when adding or removing a case rather than leaving a gap.

## Running it locally

```sh
helm lint charts/penpot
for f in charts/penpot/tests/values/valid/*.yaml; do
  helm lint charts/penpot --values "$f"
done
for f in charts/penpot/tests/values/invalid/*.yaml; do
  helm lint charts/penpot --values "$f" && echo "UNEXPECTED PASS: $f"
done
```

## Descriptions

`values.yaml` is the single source of truth for descriptions: helm-docs renders
them into `README.md`, and `scripts/sync-descriptions.py` copies them into
`values.schema.json` so editors show the same text on hover. Write the prose once,
in the `# --` comment.

```sh
scripts/sync-descriptions.py --chart charts/penpot            # write
scripts/sync-descriptions.py --chart charts/penpot --check    # CI mode
```

Add it to `.pre-commit-config.yaml` after the helm-docs hook, so both run off the
same edit:

```yaml
  - repo: local
    hooks:
      - id: sync-schema-descriptions
        name: Sync values.schema.json descriptions
        entry: scripts/sync-descriptions.py --chart charts/penpot
        language: system
        files: ^charts/penpot/values\.(yaml|schema\.json)$
        pass_filenames: false
```

A property that is a bare `$ref` gets wrapped in `allOf` so it can carry its own
description without touching the shared constraints.

Descriptions of the same key across components are worded identically on purpose
("Maximum number of replicas." rather than "…of backend replicas."). The README
table already shows the full key path in its own column, so naming the component
in the prose is redundant, and identical wording lets the four components share
one node in the schema. Keep it that way when adding keys: the script reports any
group that disagrees instead of letting one component overwrite the others.

## Upstream consistency

`scripts/` holds three checks that the schema alone cannot cover:

- `check-image-tags.py` — the backend, frontend, exporter and mcp image tags
  must all equal `Chart.yaml`'s `appVersion`.
- `check-flags.py` — cross-checks `config.flags` against the real flag list in
  `common/src/app/common/flags.cljc`, pinned to the tag matching `appVersion`.
  The schema can only enforce the `enable-`/`disable-` prefix, because Penpot's
  parser accepts any name and silently ignores the ones it doesn't know, so a
  typo becomes a no-op instead of an error.

  **Unknown names are warnings, not failures.** Flags change between Penpot
  versions, the appVersion may not be tagged yet, and some legitimate flags
  never reach that parser at all — `enable-air-gapped-conf` is documented but
  lives in the frontend image's nginx entrypoint, so it is allowlisted in the
  script. A missing enable-/disable- prefix *is* fatal: that one does not depend
  on the version. Use `--strict` if you want unknown names to fail too.

Both run offline-friendly:

```sh
scripts/check-image-tags.py --chart charts/penpot
scripts/check-flags.py --chart charts/penpot            # fetches from GitHub
scripts/check-flags.py --chart charts/penpot --flags-file ./flags.cljc
```

## Rules the templates already own

Two guards live in the templates and fail with a written explanation. Helm
validates `values.schema.json` *before* rendering, so a schema rule covering the
same ground replaces those messages with a generic one. The schema deliberately
stays quiet on both, and a workflow step asserts each message still fires:

| Guard | Message |
|---|---|
| `install-validation.yaml` | the 1.0.0 Bitnami migration is blocked until the globals are gone |
| `httproute.yml` | `gateway.enabled=true requires gateway.parentRefs to be set` |

Neither case can live in `invalid/`: those fixtures must fail *for schema
reasons*, and these fail at render time on purpose.

## Why `global` is open

`templates/install-validation.yaml` blocks the upgrade with a written explanation
when `global.postgresqlEnabled`, `valkeyEnabled` or `redisEnabled` are still set,
which is the 1.0.0 Bitnami migration gate.

Helm validates `values.schema.json` *before* rendering templates. If the schema
closed `global`, those values files would die on a generic schema error and the
user would never see that message. So `global` stays open on purpose, and the
workflow asserts the migration message is what actually fires.

That case cannot live in `invalid/`: those fixtures must fail *for schema
reasons*, and this one deliberately fails at render time instead. It is a
separate step in the workflow.

## How strict the schema is, and where

Sections (`backend`, `config`, `ingress`, …) use `additionalProperties: false`,
so a key that Helm would silently ignore is an error instead — that is what
catches `backend.replicaCounts` or `exporter.image.pullPolicyy`.

**The root is deliberately open.** The schema ships inside the released chart and
runs on every user's `helm install`, so a stray top-level key must not break
somebody's deployment: values files carried over from 0.x still carrying
`postgresql:`, YAML anchors, and keys read by GitOps tooling all pass. See
`valid/11-foreign-root-keys.yaml`.

`global` is open too, for a different reason: a parent chart injects the globals
of every other subchart into it (`global.storageClass`, `global.imageRegistry`).

The drift guard that root strictness used to provide now lives in CI instead:
`scripts/check-schema-coverage.py` fails if `values.yaml` grows any key the
schema does not describe. Strict for maintainers, forgiving for users.

## Note on schema drift

Because the schema uses `"additionalProperties": false`, any new key added to
`values.yaml` without a matching entry in `values.schema.json` makes the
`helm lint charts/penpot` step fail. That is intentional: it keeps the schema
from silently falling behind the chart.
