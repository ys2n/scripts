# uvalib/aws

AWS CLI scripts and monitoring tools for the UVA Library / Mandala fleet.

## Scripts

- **`cp-monitor`** — interactive curses dashboard of CodePipeline executions,
  filtered by `config.json`'s `pipeline_filter`.
- **`alb-state`** — inspect/add/remove hosts in an ALB target group, with a
  favorites dashboard (`config.json`) and a `--watch` mode that polls until
  targets stabilize.
- **`mandala-logs`** — list/tail/grep `uva-mandala*` CloudWatch log groups.
- **`scan-alerts`** — given a CloudWatch alarm name prefix, show recent ALARM
  transitions and, for log-metric alarms, scan the backing log group and
  aggregate the hits. See below for the design rationale.

All four share the same credential pattern: prefer AWS creds already in the
environment, otherwise fall back to `aws-vault exec $AWS_VAULT_PROFILE` (env
var, default `staging`).

## scan-alerts: design notes

Built to answer a recurring question — "an alarm paged me, what actually
happened?" — for library-drupal-production PHP OOM alerts, then generalized
once it was clear the same alarm-naming and log-metric-filter conventions
hold across every `uva-*` site (mandala-drupal, dh-drupal, etc.), not just one.

**Why alarm *history*, not alarm *state*.** By the time you go looking,
`describe-alarms` almost always reports `OK` — these alarms self-clear within
minutes. The signal lives in `describe-alarm-history` (`StateUpdate` items),
which also records the datapoint value and threshold *at the time it fired* —
useful since thresholds get tuned after the fact (this happened here: the
`php-*-errors` alarms were originally tripping at a threshold of 1, then someone
raised it to 10 to cut noise).

**Why Logs Insights, not `filter-log-events`.** These log groups hold millions
of records; `filter-log-events` over a multi-day range reliably times out
(hit this directly — a 4-day scan hung past 2 minutes). `start-query` /
`get-query-results` (Logs Insights) scans the same data server-side in seconds
and is what the whole log-scanning half of the script is built on.

**Why `-q` bypasses the "what fired" filter.** The alarm → metric-filter →
log-group chain is only followed for alarms in the log-metric namespace
(`LogMetrics`). If the alarm that actually fired is a non-log alarm (e.g. an
ELB `TargetResponseTime` alarm), the naive approach finds nothing to scan even
though the logs might still hold the answer. So an explicit `-q PATTERN` always
scans every log-metric alarm in the prefix, not just the ones that fired —
this surfaced for real scanning `uva-mandala-drupal-production`, where only the
latency alarm had tripped but the PHP/4xx log alarms (quiet) were still worth
searching directly.

**Bash 3.2 (macOS default) compatibility.** No `mapfile`, no `declare -A` —
both are bash-4+. Alarm/log-group lists are built with `while read` into plain
indexed arrays; the alarm→loggroup→pattern map is two parallel indexed arrays
(`LG_KEYS`/`LG_SUBS`) instead of an associative array. Also: an *empty* array
expanded under `set -u` (`"${arr[@]}"`) throws "unbound variable" on bash 3.2,
so options that may end up empty (e.g. `--region`) are passed as a plain
string, not an array.

**The credential gotcha that looked like a script bug but wasn't.** Mid-session
the script started failing with "Your session has expired" even though `aws
sts get-caller-identity` worked fine moments earlier as a plain shell command.
Root cause: `aws` was aliased in the interactive shell to
`aws-vault exec staging -- aws`. Shell aliases are not inherited by a script's
own `#!/usr/bin/env bash` subprocess (nor by a nested `bash -c`), so a bare
`aws` call *inside* a script silently falls through to the raw binary with
whatever (possibly stale) default credentials it finds — a completely
different failure mode than what the interactive shell sees. This is why
`scan-alerts` (and `alb-state`/`mandala-logs` before it) implement `aws_run`
explicitly rather than relying on the caller's shell aliasing to paper over
auth.
