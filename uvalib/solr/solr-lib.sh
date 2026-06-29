# solr-lib.sh — shared helpers for the Mandala Solr comparison tools.
#
# Sourced by solr-compare, solr-counts, and solr-idlists; not run on its own.
# Defines the environment/core lookups (from config.json) and the fetch +
# normalize pipeline that makes cross-environment diffs meaningful.

SOLR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SOLR_CONFIG:-$SOLR_LIB_DIR/config.json}"
MUNGE="${SOLR_MUNGE:-$SOLR_LIB_DIR/entity-munge}"

# Generated data locations (override via env). Default to CWD-relative dirs,
# matching how the originals were run from the directory holding the data.
TMPOUT="${SOLR_TMPOUT:-./tmpout}"
IDLISTS="${SOLR_IDLISTS:-./idlists}"
STATEDIR="${SOLR_STATEDIR:-.}"

# jq walk that strips volatile fields so docs from different environments
# compare equal. Edit here when a new volatile field needs ignoring.
DELPATHS='walk(if type == "object" then (del(._timestamp_)|del(._version_)|del(.updated_at)|del(.timestamp)|del(.visibility_s)|del(.visibility_i)|del(.cascading_position_i)|del(.kmaps_version)|del(.kmaps_timestamp)|del(.schema_version_i)|del(.solr_schema_checksum_s)) else . end)'

require() { command -v "$1" >/dev/null 2>&1 || { echo "Required tool not found: $1" >&2; exit 1; }; }
require jq
require curl
[[ -f "$CONFIG_FILE" ]] || { echo "Config not found: $CONFIG_FILE" >&2; exit 1; }

# Environment keys, in config order.
config_envs() { jq -r '.environments | keys_unsorted[]' "$CONFIG_FILE"; }
env_label()   { jq -r --arg e "$1" '.environments[$e].label // $e' "$CONFIG_FILE"; }

# load_envs — populate the global ENVS array with the environment keys.
# (Avoids `mapfile`, which is absent from the bash 3.2 shipped on macOS.)
load_envs() { ENVS=(); local e; while IFS= read -r e; do ENVS+=("$e"); done < <(config_envs); }

# compare_baseline ENV that every other env is diffed against (default libdev).
compare_baseline() { jq -r '.compare_baseline // "libdev"' "$CONFIG_FILE"; }

# core_url ENV CORE -> base URL for that core; non-zero exit if the env lacks it.
core_url() {
  jq -er --arg e "$1" --arg c "$2" \
    '.environments[$e] as $x | ($x.cores[$c] // "") as $n
     | if $n == "" then error("no core") else ($x.base + $n) end' \
    "$CONFIG_FILE" 2>/dev/null
}

# Per-core query shape: the terms core uses Solr block-join child docs.
core_sort() { case "$1" in terms) echo "uid_i asc";; *) echo "id asc";; esac; }
core_fl()   { case "$1" in terms) echo '*,[child parentFilter="block_type:parent"]';; *) echo '*';; esac; }

# fetch_doc ENV CORE QUERY OUTFILE — fetch a result set and normalize it:
# strip volatile fields (DELPATHS), drop stray \r, then canonicalize hostnames
# and HTML entities via entity-munge. Non-zero if the env lacks the core.
fetch_doc() {
  local env="$1" core="$2" query="$3" out="$4" url
  url="$(core_url "$env" "$core")" || return 1
  curl -s --get "$url/select" \
    --data wt=json --data indent=true --data rows=100 \
    --data-urlencode "q=$query" \
    --data-urlencode "sort=$(core_sort "$core")" \
    --data-urlencode "fl=$(core_fl "$core")" \
    | jq '.response.docs' | jq "$DELPATHS" | sed 's/\\r//g' | "$MUNGE" > "$out"
}

# solr_count ENV CORE QUERY -> numFound ("-" if env lacks core, "?" on error).
solr_count() {
  local url
  url="$(core_url "$1" "$2")" || { echo "-"; return; }
  curl -s --get "$url/select" --data wt=json --data rows=0 \
    --data-urlencode "q=$3" | jq -r '.response.numFound // "?"'
}
