# uvalib/host

Host-level admin helpers for the UVA Library Drupal/Mandala fleet.

## Scripts

- **`collect-host-info <host>...`** — SSH to each Drupal Docker host and report
  the `drupal-0` container's MySQL version, host + container OS, and `drush
  status` (JSON). Read-only inspection.
- **`uvado [-u USER] <command> [args...]`** — run a command as a privileged
  user through an `su - USER -c "sudo ..."` chain, prompting for the password
  only once (driven by `expect`). User defaults to `libadm`; override with `-u`
  or `$UVADO_USER`. Requires `expect` (`brew install expect`).

## Preserved technique: rsync over an SSH reverse tunnel

The retired `mandala-filesync.sh` (Aegir-era prod→staging file sync) is gone,
but its useful trick is worth keeping: to push files **from** a source host
**to** a target that only your laptop can route to, open a reverse tunnel on
the source back through your machine, then rsync over it.

```sh
# On your laptop: SRC_HOST opens a reverse tunnel (its localhost:50001 ->
# TARGET_HOST:TARGET_PORT via you), then runs rsync through that tunnel.
ssh -R localhost:50001:TARGET_HOST:TARGET_PORT \
    SRC_HOST -p SRC_PORT -l SRC_USER \
    'rsync -e "ssh -o StrictHostKeyChecking=accept-new -p 50001" -vuar \
        /path/on/src/ localhost:/path/on/target/'
```

Useful when source and target can't reach each other directly but both can
reach (or be reached from) your workstation.
