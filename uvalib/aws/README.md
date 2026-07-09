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
- **`alarm-watch`** — digest of current/recent alarm state across the sites in
  `config.json`'s `notifications` block, a `discover` command to browse what's
  available, and a `sync-filter` command to narrow your SNS subscription to just
  those sites. See below for design notes.
- **`alert-config`** — account-wide `status` of every SNS subscription and
  CodeStar notification rule tied to `config.json`'s `identities` block, plus
  administration (subscribe/unsubscribe, enable/disable a rule, add/remove a
  rule's SNS targets, and a generalized `sync-filter` for any subscription via
  `config.json`'s `filters` block). See below for design notes.

All six share the same credential pattern: prefer AWS creds already in the
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

## alarm-watch: design notes

Built after discovering that the personal SNS subscription behind these alarm
emails (`uva-site-urgent-production`, protocol `email-json`) had **no
`FilterPolicy` at all** — over 350 alarms across dozens of unrelated apps
(not just the Drupal/Mandala fleet the rest of this directory targets) were
all reaching one inbox, unfiltered, as double-JSON-wrapped email. `alarm-watch`
addresses both halves: what AWS actually sends you, and how you check on
things without relying on email at all.

**Why `services` x `environments` x `prefix_templates`, not a flat prefix list.**
The first version stored full prefixes directly (`uva-library-drupal-production`)
and used them for both CloudWatch polling and the SNS `FilterPolicy`. Running
`alarm-watch discover` against the live account after applying that filter showed
it was already wrong: `uva-failed-login-<service>-<env>` and
`uva-reboot-<service>-<env>` alarms put their category *before* the service name,
so a per-service prefix silently missed them — the just-applied filter was
dropping security (failed-login) and availability (reboot) alerts for every
configured site. `services` (bare identifiers), `environments` (naming tokens),
and `prefix_templates` (patterns with `{service}`/`{environment}` placeholders)
are now three separate, crossed lists, so a new alarm-naming shape only needs a
new template, applied uniformly to every service — not a manual prefix added per
service per category. `alarm-watch discover <substring>` exists specifically to
catch the next one of these before assuming a service is fully covered.

**Why `environments` doesn't change what `sync-filter` can actually deliver.**
staging/develop alarms publish to entirely different SNS topics than production
(e.g. `uva-site-notice-staging`, confirmed via `describe-alarms` on a staging
alarm's `AlarmActions` — not `uva-site-urgent-production`). Adding `"staging"` to
`environments` immediately makes `alarm-watch`'s own polling show staging alarm
state (no topic dependency — `describe-alarms --alarm-name-prefix` doesn't care
what a matched alarm's actions point to), but `sync-filter` only ever manages the
one `subscription_arn`/`topic_arn` pair in config — staging-shaped prefixes added
to that FilterPolicy are inert until there's a separate subscription on staging's
own topic, which this script doesn't create.

**Why `FilterPolicyScope=MessageBody`, not the default `MessageAttributes`.**
CloudWatch alarm actions publish to SNS without setting any message
attributes — the `AlarmName` field lives only in the JSON message body. The
default attribute-scoped filtering has nothing to match against, so the
subscription attribute has to be set explicitly to `MessageBody` before the
`FilterPolicy` (matching `AlarmName` by `prefix`) has any effect. Confirmed via
`aws sns set-subscription-attributes help`.

**Why `sync-filter` only ever touches one subscription ARN.** The topic has
multiple independent subscribers (`lib-aws-prod-support@...`, an SMS number,
etc.). `sync-filter` reads `notifications.subscription_arn` from config and
calls `set-subscription-attributes` against that ARN only — verified it's a
distinct, personally-owned subscription (`SubscriptionPrincipal` is your own
IAM user), so narrowing it can't affect what anyone else receives.

**Why `sync-filter` is diff-then-confirm, never automatic.** It prints current
vs. desired `FilterPolicy` and only pushes with an explicit `--apply`, gated by
a typed `yes` — the same confirmation pattern `alb-state` uses before
registering/deregistering ALB targets. This is a change to live, shared-account
notification routing; it shouldn't happen as a side effect of an unrelated run.

**Why the `email-json` → `email` protocol switch isn't scripted.** That's what
actually produces the double-JSON-wrapped envelope (the whole SNS `Notification`
object, `Message` field escaped inside it) instead of just the CloudWatch
alarm JSON. Fixing it means creating a *new* subscription and clicking the
confirmation link AWS emails you — a step no script can complete on your
behalf. Scripting "unsubscribe old, subscribe new" around that manual click
risks leaving you with zero working subscriptions if the confirmation email is
missed or delayed. Do it by hand, once:

```sh
# 1. Subscribe a new plain-email endpoint (keeps the old one active for now)
aws sns subscribe --topic-arn "$(jq -r .notifications.topic_arn config.json)" \
  --protocol email --notification-endpoint ys2n@virginia.edu

# 2. Check email, click the "Confirm subscription" link.

# 3. Find the new subscription's ARN, and point config.json at it
aws sns list-subscriptions-by-topic \
  --topic-arn "$(jq -r .notifications.topic_arn config.json)" \
  --query "Subscriptions[?Endpoint=='ys2n@virginia.edu']"
# -> update notifications.subscription_arn in config.json to the new ARN

# 4. Move the filter onto the new subscription (it starts with none)
./alarm-watch sync-filter --apply

# 5. Remove the old email-json subscription
aws sns unsubscribe --subscription-arn OLD_EMAIL_JSON_SUBSCRIPTION_ARN
```

## Current notification setup (as of this writing)

A snapshot of what's actually live, for context — `alert-config status` is
the authoritative up-to-date view; this just records *why* it looks the way
it does, since that reasoning won't be visible from the live state alone.

- **`uva-site-urgent-production`** (email-json, `ys2n@virginia.edu`) —
  filtered by `alarm-watch sync-filter` to the 4 Drupal/Mandala production
  sites (`library-drupal`, `mandala-drupal`, `dh-drupal`, `dsf-drupal`) ×
  base/failed-login/reboot alarm templates. Started with **no filter at
  all** — every alarm across ~350 unrelated apps on the account reached this
  one inbox before this work.
- **`uva-infrastructure-notice-staging`** (sms, confirmed cell) — filtered
  by `alert-config sync-filter staging-pipelines` to 7 staging Drupal
  CodePipeline pipelines (`dh`, `dsf`, `library`, `library-release`,
  `migrate-tools`, `netbadge`, `theme`). `dhportal` deliberately excluded —
  that project was handed off.
- **`uva-drupal-dh-staging-codepipeline-notification-rule-ys2n`** (CodeStar
  rule) — **disabled, not deleted.** Its 11 event types include
  stage/action-level detail and pipeline-level `Canceled` that the
  EventBridge-based filter above can't see (verified: no EventBridge rule
  covers pipeline cancellation for this pipeline at all). Kept disabled
  rather than removed specifically so that detail is one `rule-enable` away
  if ever needed — e.g. if a manual-approval gate gets added to this
  pipeline later (none exists today, so the rule's 3 manual-approval event
  types can't currently fire regardless).
- **`uva-drupal-notice-staging`** — subscription removed entirely (not just
  filtered). This was the source of ~7-9 SMS/day, every day for a year+,
  turned out to be a daily 6am staging-host reboot notice with no way to
  filter out just that piece — the CodePipeline events it also carried are
  now fully covered by the `uva-infrastructure-notice-staging` filter above.

## alert-config: design notes

Built because `alarm-watch` only ever manages one thing (the `FilterPolicy` on
one SNS subscription); the actual ask was "show me everything I'm wired into,
account-wide, so I can decide to cancel or add." Live discovery turned up a
CodeStar Notification Rule (`codestar-notifications` — a different AWS
service from CloudWatch/SNS alarms entirely, watching CodePipeline for
`uva-drupal-dh-codepipeline`) that nothing else here touches, plus a second
SNS subscription (`uva-drupal-notice-staging`) on the same confirmed phone
number that neither of us knew about until `status` found it by scanning
account-wide instead of trusting a fixed list.

**Why identity must be explicit and confirmed, never inferred — the whole
design pivots on a mistake.** The first pass at this treated a phone number
as "yours" because it was subscribed to the same topics as your (actually
yours) email address. You corrected that: the number belonged to someone
else entirely. A second phone number, found as a CodeStar rule's SMS target,
looked equally plausible for the same bad reasons (the rule's name contained
"ys2n", its `CreatedBy` was your IAM user) — but was only actually confirmed
when you stated it directly, in words. Proximity to something you own —
sharing a topic, being the target of a rule you created — is not proof of
endpoint ownership. `identities.emails`/`identities.phones` in `config.json`
are the *only* source of truth `alert-config` will ever treat as "you," and
nothing in the script adds to that list automatically. `status` labels every
resolved endpoint `[confirmed: you]` or `[unverified endpoint]` on an exact
match against that list — never a warning, just the honest default.

**Why rule ownership (`CreatedBy`) and endpoint identity are tracked
separately, not conflated.** `CreatedBy` matching your IAM `UserId` is real,
provable evidence that *you created a given CodeStar notification rule* —
unlike a phone number, nobody else's credentials could produce that field.
It's used to decide which rules `status` shows you at all. But it says
nothing about who the rule notifies; that's `identities` verification's job,
applied independently to each of the rule's targets.

**Why `--targets` on `update-notification-rule` is fetch-modify-replace, not
additive.** Confirmed via `aws codestar-notifications update-notification-rule
help`: `--targets` replaces the rule's entire target list. `rule-add-target`/
`rule-remove-target` therefore always `describe-notification-rule` first, add
or remove exactly one entry from the current list, and push the complete
result back — a naive "set this one target" call would silently drop every
other target the rule had. `rule-remove-target` also refuses outright if the
result would be an empty target list (a notification rule with nowhere to
notify); use `rule-disable` instead to silence a rule.

**Why `sync-filter` is generalized (config.json's `filters` key), not
hardcoded like alarm-watch's.** Investigating "where do my liked CodePipeline
texts actually come from" turned up ~30 EventBridge rules (`aws.codepipeline`
source, `CodePipeline Pipeline Execution State Change` detail-type) that
format a plain `{"status": "<pipeline> has <state>"}` message and fan each
one out to four different SNS topics at once — including
`uva-infrastructure-notice-staging`, which turned out to already carry
*every* staging pipeline's events account-wide (confirmed: the unrelated
EMMA project's pipeline fires into it too), with none of the reboot/instance-
stop noise (that goes to `uva-site-notice-staging`/`cloudwatch-alarm-active`
instead). Subscribing there and filtering by `status` prefix — same
`FilterPolicyScope=MessageBody` mechanism as alarm-watch, just matching a
different field — got the desired 7 staging Drupal pipelines with zero new
EventBridge rules. `filters.<name>` in config.json bundles a
`subscription_arn`, the message `field` to match on, and the allowed
`prefixes`, so the same `sync-filter <name> [--apply]` command works for any
subscription/field pair rather than being locked to one topic and
`AlarmName`, the way alarm-watch's version is.
