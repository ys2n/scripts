# uvalib/solr

Drift check for the Mandala Solr search index across its four environments.

The fuller per-document comparison machinery (`solr-compare`, `solr-idlists`,
`entity-munge`) existed to verify parity during the SearchStax → self-hosted
migration. That migration is over, so only the lightweight count check remains;
the rest is recoverable from git history and the old `~/scripts` if ever needed.

## Environments and cores

The index lives in four environments, defined in [`config.json`](config.json):

| key       | host                              | terms core     | assets core    | av core      |
|-----------|-----------------------------------|----------------|----------------|--------------|
| `ssprod`  | SearchStax prod (measuredsearch)  | `kmterms_prod` | `kmassets`     | `av`         |
| `ssdev`   | SearchStax dev (measuredsearch)   | `kmterms_dev`  | `kmassets_dev` | `av_dev`     |
| `libdev`  | UVA replica dev (internal.lib)    | `kmterms`      | `kmassets`     | `mandala-av` |
| `libprod` | UVA replica prod (internal.lib)   | `kmterms`      | `kmassets`     | `mandala-av` |

Three logical cores: **terms** (knowledge-map terms — places/subjects/terms),
**assets** (digital assets — images, texts, sources, visuals, audio-video), and
**av** (audio/video transcripts and nodes). To add an environment, rename a
core, or change what gets counted, edit `config.json` only.

## Usage

```
solr-counts
```

Prints one row per `count_targets` entry and one column per environment
(`-` = core absent in that environment, `?` = query failed). Requires `jq` and
`curl`. Reaches the UVA-internal replicas only from a network that can resolve
`*.internal.lib.virginia.edu`.
