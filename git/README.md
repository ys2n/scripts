# git

Provider-agnostic git helpers (not UVA-specific).

## Scripts

- **`ssh-remote-fix [REMOTE]`** — convert a repo's HTTPS GitHub remote URL to
  its SSH form (`git@github.com:owner/repo.git`), but only after verifying that
  SSH access to GitHub actually works. Defaults to the `origin` remote; no-ops
  if the remote isn't an HTTPS GitHub URL.
