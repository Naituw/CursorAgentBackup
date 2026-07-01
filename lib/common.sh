#!/usr/bin/env bash

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_version() {
  case "$1" in
    *[!A-Za-z0-9._-]*|'') die "Invalid version: $1" ;;
  esac
  case "$1" in
    [0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]*) ;;
    *) die "Version must begin with YYYY.MM.DD: $1" ;;
  esac
}

validate_alias() {
  case "$1" in
    *[!A-Za-z0-9._-]*|'') die "Invalid alias: $1" ;;
  esac
  case "$1" in
    agent|cursor-agent)
      die "Alias '$1' is reserved for the official installation; use cursor-agent-restore"
      ;;
  esac
}

platform_id() {
  local os arch
  case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    *) die "Unsupported operating system: $(uname -s)" ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    x86_64|amd64) arch=x64 ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
  printf '%s-%s\n' "$os" "$arch"
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    die "Neither shasum nor sha256sum is installed"
  fi
}

verify_archive() {
  local archive checksum_file expected actual
  archive=$1
  checksum_file=$2
  [ -f "$archive" ] || die "Archive not found: $archive"
  [ -f "$checksum_file" ] || die "Checksum file not found: $checksum_file"
  expected=$(awk 'NR == 1 {print $1}' "$checksum_file")
  [ "${#expected}" -eq 64 ] || die "Invalid checksum file: $checksum_file"
  case "$expected" in
    *[!0-9a-fA-F]*) die "Invalid checksum file: $checksum_file" ;;
    *) ;;
  esac
  actual=$(sha256_file "$archive")
  [ "$actual" = "$expected" ] || die "Checksum mismatch for $archive"
}

validate_archive_layout() {
  local archive version
  archive=$1
  version=$2
  require_command tar
  tar -tzf "$archive" | awk -v prefix="$version/" '
    BEGIN { found = 0 }
    /^\// { exit 2 }
    /(^|\/)\.\.(\/|$)/ { exit 2 }
    index($0, prefix) != 1 && $0 != substr(prefix, 1, length(prefix) - 1) { exit 2 }
    $0 == prefix "cursor-agent" { found = 1 }
    END { if (!found) exit 3 }
  ' || die "Archive has an invalid layout or lacks $version/cursor-agent"
}

download_archive() {
  local repo version destination platform base archive_name
  repo=$1
  version=$2
  destination=$3
  platform=$(platform_id)
  archive_name="cursor-agent-$version-$platform.tar.gz"
  base="https://github.com/$repo/releases/download/cursor-agent-$version"
  require_command curl
  printf 'Downloading %s\n' "$archive_name" >&2
  curl -fL --retry 3 --output "$destination/$archive_name" "$base/$archive_name"
  curl -fL --retry 3 --output "$destination/$archive_name.sha256" "$base/$archive_name.sha256"
  printf '%s\n' "$destination/$archive_name"
}

install_archive_tree() {
  local archive version target staging parent
  archive=$1
  version=$2
  target=$3
  parent=$(dirname "$target")
  mkdir -p "$parent"
  staging=$(mktemp -d "$parent/.install-$version.XXXXXX")
  if ! tar -xzf "$archive" -C "$staging"; then
    rm -rf "$staging"
    die "Failed to extract $archive"
  fi
  [ -x "$staging/$version/cursor-agent" ] ||
    die "Extracted cursor-agent is missing or not executable"
  if [ -e "$target" ]; then
    rm -rf "$staging"
    [ -x "$target/cursor-agent" ] || die "Existing target is invalid: $target"
    return
  fi
  mv "$staging/$version" "$target"
  rm -rf "$staging"
}

atomic_symlink() {
  local target link temp
  target=$1
  link=$2
  if [ -d "$link" ] && [ ! -L "$link" ]; then
    die "Refusing to replace directory with a symlink: $link"
  fi
  temp="$link.tmp.$$"
  rm -f "$temp"
  ln -s "$target" "$temp"
  mv -f "$temp" "$link"
}
