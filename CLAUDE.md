# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal collection of standalone operational scripts — mostly Bash, one Python
(`uvalib/aws/cp-monitor`). There is no build system, test suite, package manifest, or
CI. Each script is self-contained and run directly; "developing" here means editing a
script and running it against live infrastructure. Most tooling targets **UVA Library /
Mandala** infrastructure (`uvalib/`); `git/` holds provider-agnostic helpers.

Read the per-directory README before touching a script — several encode hard-won design
rationale (notably `uvalib/aws/README.md` and `uvalib/host/README.md`), not just usage.

## Conventions that recur across scripts

These patterns are shared deliberately; match them when adding or editing scripts.

- **AWS credentials via a `*_run` wrapper.** AWS scripts (`alb-state`, `mandala-logs`,
  `scan-alerts`, `docker/peek-repo-image.sh`) never call `aws` bare. They define an
  `aws_run`/`vault_run` helper that prefers creds already in the environment
  (`AWS_ACCESS_KEY_ID`/`AWS_PROFILE`), else falls back to
  `aws-vault exec "$profile"`. The default profile is `staging`, overridable via env
  (`AWS_VAULT_PROFILE` / `VAULT_PROFILE`). Do this because shell aliases like
  `aws → aws-vault exec staging -- aws` are **not** inherited by a script subprocess —
  a bare `aws` inside a script silently uses raw/stale creds (see the "credential
  gotcha" note in `uvalib/aws/README.md`).

- **`config.json` drives behavior; edit config, not code.** `uvalib/aws/config.json`
  (pipeline filter, ALB target-group favorites) and `uvalib/solr/config.json`
  (environments, cores, count targets) are the intended edit surface for routine
  changes — new environment, new favorite, new count query. Scripts read them with `jq`.

- **`set -euo pipefail`** at the top of Bash scripts, with `SCRIPT_DIR` resolved via
  `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` to locate the sibling `config.json`.

- **Bash 3.2 (macOS default) compatibility.** No `mapfile`, no associative arrays
  (`declare -A`). Build lists with `while read` into indexed arrays; represent maps as
  parallel indexed arrays. Under `set -u`, expanding a possibly-empty array as
  `"${arr[@]}"` throws "unbound variable" on bash 3.2 — pass optional flags (e.g.
  `--region`) as plain strings instead.

- **Executable "commands" have no extension** (`solr-counts`, `alb-state`, `uvado`);
  `.sh` is reserved for sourced helpers / remote-execution templates. Scripts carry a
  usage header comment and `-h`/`--help`.

## Areas

- `uvalib/aws/` — AWS CLI monitoring/ops tools (CodePipeline, ALB target groups,
  CloudWatch logs & alarm forensics). Richest design notes live in its README.
- `uvalib/solr/` — Mandala Solr cross-environment count drift check (`solr-counts`).
- `uvalib/host/` — SSH-based Drupal/Mandala host admin (`collect-host-info`, `uvado`).
- `uvalib/ansible/` — playbooks + `build-inventory` (inventory generated from the
  Terraform repo; the generated file is gitignored, regenerate via the script).
- `uvalib/mussh/` — multi-host SSH execution with plain host inventory `.txt` files.
- `uvalib/docker/` — ECR image tagging / inspection helpers.
- `git/` — provider-agnostic git helpers (e.g. `ssh-remote-fix`).

## External dependencies

Scripts assume operator tooling is already installed and reach live systems:
`awscli` v2, `aws-vault`, `jq`, `curl`, `python3`, `expect` (for `uvado`), `ansible`,
`fzf` (optional, `peek-repo-image.sh`). UVA-internal targets
(`*.internal.lib.virginia.edu`) are reachable only from a network that can resolve
them.
