# scripts
My personal collection of useful scripts

## Directory Structure

### uvalib
Scripts and configuration for UVA Library infrastructure management.

- `ansible/` - Ansible playbooks and configurations for server management and automation
- `mussh/` - Multi-host SSH execution scripts and inventory files
- `aws/` - AWS CLI scripts and monitoring tools
  - `cp-monitor` - Interactive CodePipeline monitoring tool
  - `scan-alerts` - Given a CloudWatch alarm name prefix, shows recent ALARM
    transitions and, for log-metric alarms, scans the backing log group via
    Logs Insights and aggregates by day/referer/failing line. Works against
    any uva-* alarm prefix (library-drupal, mandala-drupal, dh-drupal, ...).
- `docker/` - ECR / image tagging and release helpers
- `solr/` - Mandala Solr cross-environment count check
- `host/` - Drupal/Mandala host admin helpers (collect-host-info, uvado)

### git
Provider-agnostic git helpers (e.g. `ssh-remote-fix`).

See individual directory README files for detailed documentation.
