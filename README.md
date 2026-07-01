# Cursor Agent Backup

Back up, publish, restore, and run pinned versions of the Cursor Agent CLI.
The official `agent` command can keep using Cursor's updater while aliases such
as `agent2` remain fixed to a preserved version.

## Why GitHub Releases instead of Git LFS?

Release archives are intentionally excluded from Git history. Cloning this
repository downloads only the scripts. A requested version is downloaded from
its GitHub Release when it is installed or restored.

GitHub currently permits up to 1,000 assets per release, requires each asset to
be under 2 GiB, and documents no total-size or bandwidth limit for a release.
See [GitHub's release documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).

## Requirements

- macOS or Linux
- Bash, `tar`, `curl`, and either `shasum` or `sha256sum`
- `jq` only for listing remote versions
- GitHub CLI (`gh`) only for publishing releases

## Back up installed versions

Back up the version currently selected by `agent`:

```sh
bin/cursor-agent-backup
```

Back up every version still present in Cursor's managed versions directory:

```sh
bin/cursor-agent-backup --all
```

Back up selected versions:

```sh
bin/cursor-agent-backup \
  2026.06.24-00-45-58-9f61de7 \
  2026.06.26-7079533
```

Archives and SHA-256 sidecars are written to `dist/`, which is ignored by Git.
The complete version directory is archived because `cursor-agent` is only a
launcher and depends on the Node runtime, JavaScript bundles, and native
modules beside it.

## Publish archives

Authenticate GitHub CLI, then publish one or more versions:

```sh
gh auth login
bin/cursor-agent-publish \
  2026.06.24-00-45-58-9f61de7 \
  2026.06.26-7079533
```

Each version uses the tag `cursor-agent-<version>`. Archives include the
platform in their asset name, so other platform builds can be added later.

## Install a pinned alias

List published versions:

```sh
bin/cursor-agent-install --list
```

Install a version as `agent2`:

```sh
bin/cursor-agent-install 2026.06.26-7079533 --alias agent2
agent2 --version
```

Pinned versions live outside Cursor's managed versions directory:

```text
~/.local/share/cursor-agent-pinned/versions/<version>/<platform>/
```

This matters because Cursor's updater may clean older directories under
`~/.local/share/cursor-agent/versions`. The installer refuses to replace an
existing alias unless `--force` is passed. The names `agent` and
`cursor-agent` are reserved and cannot be used as pinned aliases.

## Restore the official command

Switch both official command aliases to a preserved version:

```sh
bin/cursor-agent-restore 2026.06.24-00-45-58-9f61de7
```

If the version is still installed locally, no download is needed. Otherwise
the archive is downloaded and verified first. Previous symlink targets are
recorded under:

```text
~/.local/share/cursor-agent/versions/.rollback/
```

Cursor may update the official `agent` command again unless its update channel
is configured to remain static. A pinned alias is independent of that setting.

## Important limitations

- These tools preserve the CLI program, not `~/.cursor` settings, sessions, or
  keychain credentials. Secrets must not be committed or attached to releases.
- An old client can stop working if Cursor changes its server protocol.
- Release archives contain Cursor binaries, not software covered by this
  repository's MIT license. Confirm that your use and distribution comply with
  Cursor's applicable license and terms.
- Only restore archives you trust. SHA-256 verification detects corruption but
  does not establish who originally produced an archive.

## Test

Tests use an isolated temporary home directory and a fake CLI payload:

```sh
tests/test.sh
```
