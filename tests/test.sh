#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cursor-agent-backup-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

HOME="$WORK/home"
export HOME
VERSIONS="$HOME/.local/share/cursor-agent/versions"
BIN="$HOME/.local/bin"
PINNED="$HOME/.local/share/cursor-agent-pinned/versions"
DIST="$WORK/dist"
VERSION=2026.01.02-test
mkdir -p "$VERSIONS/$VERSION" "$BIN" "$DIST"

cat > "$VERSIONS/$VERSION/cursor-agent" <<'EOF'
#!/usr/bin/env bash
printf 'fake cursor agent\n'
EOF
chmod +x "$VERSIONS/$VERSION/cursor-agent"
printf 'payload\n' > "$VERSIONS/$VERSION/index.js"
ln -s "$VERSIONS/$VERSION/cursor-agent" "$BIN/agent"
ln -s "$VERSIONS/$VERSION/cursor-agent" "$BIN/cursor-agent"
export PATH="$BIN:$PATH"

"$ROOT/bin/cursor-agent-backup" --versions-dir "$VERSIONS" --output "$DIST" "$VERSION"
ARCHIVE=$(find "$DIST" -name '*.tar.gz' -type f)
[ -f "$ARCHIVE.sha256" ]

rm -rf "$VERSIONS/$VERSION"
"$ROOT/bin/cursor-agent-install" "$VERSION" --alias agent2 \
  --archive "$ARCHIVE" --bin-dir "$BIN" --root "$PINNED"
[ "$("$BIN/agent2")" = "fake cursor agent" ]

if "$ROOT/bin/cursor-agent-install" "$VERSION" --alias agent2 \
  --archive "$ARCHIVE" --bin-dir "$BIN" --root "$PINNED" --force >/dev/null; then
  :
else
  exit 1
fi

"$ROOT/bin/cursor-agent-restore" "$VERSION" --archive "$ARCHIVE" \
  --bin-dir "$BIN" --versions-dir "$VERSIONS"
[ "$("$BIN/agent")" = "fake cursor agent" ]
[ "$("$BIN/cursor-agent")" = "fake cursor agent" ]

printf 'not a symlink\n' > "$BIN/agent3"
if "$ROOT/bin/cursor-agent-install" "$VERSION" --alias agent3 \
  --archive "$ARCHIVE" --bin-dir "$BIN" --root "$PINNED" >/dev/null 2>&1; then
  printf 'Expected alias collision to fail\n' >&2
  exit 1
fi

printf 'All tests passed\n'
