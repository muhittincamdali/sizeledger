#!/bin/sh
# Times `sizeledger analyze` on a fixture with the release build and prints the median.
#
#   scripts/bench.sh                                   # SampleShop 2.0, 21 runs
#   scripts/bench.sh Fixtures/apps/SampleShop-1.0.ipa 51
#
# Each run starts the process, measures the app and writes the table to /dev/null, so the time
# includes process start-up. One untimed run comes first to warm the file cache. Timing uses
# Perl's Time::HiRes, which macOS and common Linux images include.
set -eu

cd "$(dirname "$0")/.."
input="${1:-Fixtures/apps/SampleShop-2.0.ipa}"
runs="${2:-21}"

case "$runs" in
  '' | *[!0-9]* | 0) echo "usage: scripts/bench.sh [input] [runs]; runs must be 1 or more" >&2; exit 64 ;;
esac
[ -e "$input" ] || { echo "scripts/bench.sh: $input does not exist" >&2; exit 2; }

swift build -c release --product sizeledger >&2
binary="$(swift build -c release --product sizeledger --show-bin-path)/sizeledger"
"$binary" analyze "$input" > /dev/null

perl -MTime::HiRes=time -e '
  my ($runs, @command) = @ARGV;
  open(my $saved, ">&", \*STDOUT) or die "cannot duplicate stdout: $!\n";
  open(STDOUT, ">", "/dev/null") or die "cannot open /dev/null: $!\n";
  my @times;
  for (1 .. $runs) {
    my $start = time;
    system { $command[0] } @command;
    die "sizeledger failed with status " . ($? >> 8) . "\n" if $? != 0;
    push @times, (time - $start) * 1000;
  }
  open(STDOUT, ">&", $saved) or die "cannot restore stdout: $!\n";
  @times = sort { $a <=> $b } @times;
  my $middle = int(@times / 2);
  my $median = @times % 2 ? $times[$middle] : ($times[$middle - 1] + $times[$middle]) / 2;
  printf "median %.1f ms (min %.1f, max %.1f) over %d runs\n", $median, $times[0], $times[-1], $runs;
' "$runs" "$binary" analyze "$input"
