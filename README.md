# scripts
My personal collection of useful scripts

## Directory Structure

### uvalib
Scripts and configuration for UVA Library infrastructure management.

- `ansible/` - Ansible playbooks and configurations for server management and automation
- `mussh/` - Multi-host SSH execution scripts and inventory files
- `aws/` - AWS CLI scripts and monitoring tools
  - `cp-monitor` - Interactive CodePipeline monitoring tool
- `docker/` - ECR / image tagging and release helpers
- `solr/` - Mandala Solr cross-environment count check
- `host/` - Drupal/Mandala host admin helpers (collect-host-info, uvado)

### git
Provider-agnostic git helpers (e.g. `ssh-remote-fix`).

See individual directory README files for detailed documentation.
