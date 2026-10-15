#!/usr/bin/env bash
# Prints Formula/sizeledger.rb for muhittincamdali/homebrew-tap from a release's checksums:
#
#   scripts/homebrew-formula.sh <version> <SHA256SUMS file of the release>
#
# The formula installs the prebuilt binaries the release attaches: one universal macOS binary
# (arm64 and x86_64) and one for each Linux architecture. Building from source would need Swift,
# which Homebrew only bottles for macOS, so a Linux install would compile the toolchain first.
set -euo pipefail

version="${1:-}"
sums="${2:-}"
if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || [ ! -f "$sums" ]; then
  echo "usage: $0 <version, e.g. 0.1.0> <SHA256SUMS>" >&2
  exit 64
fi

checksum() {
  local file="sizeledger-$version-$1.tar.gz"
  local sum
  sum="$(awk -v file="$file" '$2 == file || $2 == "*" file || $2 == "./" file { print $1 }' "$sums")"
  if ! printf '%s' "$sum" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "error: no SHA-256 for $file in $sums" >&2
    exit 1
  fi
  printf '%s' "$sum"
}

macos="$(checksum macos-universal)"
linux_x86_64="$(checksum linux-x86_64)"
linux_aarch64="$(checksum linux-aarch64)"
base="https://github.com/muhittincamdali/sizeledger/releases/download/v$version"

cat <<FORMULA
class Sizeledger < Formula
  desc "Show where every megabyte of an iOS app comes from"
  homepage "https://github.com/muhittincamdali/sizeledger"
  version "$version"
  license "MIT"

  # Homebrew's style rules do not allow url inside on_macos/on_linux blocks; OS and CPU checks
  # pick the archive instead.
  if OS.mac?
    url "$base/sizeledger-$version-macos-universal.tar.gz"
    sha256 "$macos"
  elsif Hardware::CPU.intel?
    url "$base/sizeledger-$version-linux-x86_64.tar.gz"
    sha256 "$linux_x86_64"
  else
    url "$base/sizeledger-$version-linux-aarch64.tar.gz"
    sha256 "$linux_aarch64"
  end

  def install
    bin.install "sizeledger"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/sizeledger --version").strip
    (testpath/"Demo.app/Demo").write "x" * 5000
    output = shell_output("#{bin}/sizeledger analyze #{testpath}/Demo.app --format json")
    assert_match "\"bytes\" : 5000", output
  end
end
FORMULA
