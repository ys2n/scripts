# uvalib/solr

Tools for comparing the Mandala Solr search index across its four environments.
Distilled from the ad-hoc `compare-solr-*` scripts in the old `~/scripts`
junk drawer into a single config-driven set.

## Environments and cores

The index lives in four environments, defined in [`config.json`](config.json):

| key       | host                              | terms core     | assets core    | av core      |
|-----------|-----------------------------------|----------------|----------------|--------------|
| `ssprod`  | SearchStax prod (measuredsearch)  | `kmterms_prod` | `kmassets`     | `av`         |
| `ssdev`   | SearchStax dev (measuredsearch)   | `kmterms_dev`  | `kmassets_dev` | `av_dev`     |
| `libdev`  | UVA replica dev (internal.lib)    | `kmterms`      | `kmassets`     | `mandala-av` |
| `libprod` | UVA replica prod (internal.lib)   | `kmterms`      | `kmassets`     | `mandala-av` |

Three logical cores: **terms** (knowledge-map terms — places/subjects/terms,
using Solr block-join child docs), **assets** (digital assets — images, texts,
sources, visuals, audio-video), and **av** (audio/video transcripts and nodes).
To add an environment or rename a core, edit `config.json` only.

## Requirements

`jq`, `curl`, plus `jd` (structural JSON diff) and `gdbmtool` for `solr-compare`,
and Perl with `HTML::Entities` for `entity-munge`.

## Scripts

- **`solr-compare [FILTER]`** — per-document diff across environments. Reads the
  UID lists, fetches each doc from every environment, normalizes them, and diffs
  each environment against the baseline (`compare_baseline` in config, default
  `libdev`) with `jd`. Optional `FILTER` is an egrep over the uid list
  (e.g. `solr-compare '^places'`). Use `--av` to compare av-core docs (keyed by
  `id`) instead.
- **`solr-counts`** — document-count comparison: one row per `count_targets`
  entry, one column per environment (`-` = core absent, `?` = query failed).
- **`solr-idlists export [NAME_REGEX]`** — (re)generate the UID/ID lists that
  `solr-compare` consumes, from `export_targets` in config.
- **`entity-munge`** — Perl canonicalizer (decodes HTML entities, rewrites
  hostnames/URLs) so docs from different environments compare equal. Edit its
  regex list when the canonical form needs to change.
- **`solr-lib.sh`** — shared helpers (sourced, not run directly).

## Caching and data layout

`solr-compare` reads idlists from `./idlists` and caches fetched docs and diffs
in `./tmpout`; results go to `*.gdbm` databases. A document is skipped if its
per-env JSON is already cached — delete `tmpout/<uid>-test-*.json` to force a
refresh. These default to the current directory; override with `SOLR_IDLISTS`,
`SOLR_TMPOUT`, and `SOLR_STATEDIR`. Run from the directory holding your data,
or point the env vars at it. The generated `idlists/`, `tmpout/`, and `*.gdbm`
are not tracked.
