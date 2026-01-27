#!/usr/bin/env bash
set -euo pipefail

# Auto-detect primary interface (default route). Fallback to first UP non-lo interface.
IFACE="$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')"
if [[ -z "${IFACE:-}" ]]; then
  IFACE="$(ip -br link | awk '$1!="lo" && $2=="UP"{print $1; exit}')"
fi

if [[ -z "${IFACE:-}" ]]; then
  echo "ERROR: Could not detect an active network interface." >&2
  echo "Run: ip -br link" >&2
  exit 1
fi

# Allow overriding packet count: ./iran-geoip-sample.sh 200000
COUNT="${1:-50000}"
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: packet count must be a number, got: $COUNT" >&2
  exit 1
fi

echo "Using interface: $IFACE"
echo "Capturing UDP packets: $COUNT"
echo "Writing numbered GeoIP lines to: countries_numbered.txt"
echo

sudo tcpdump -ni "$IFACE" udp -c "$COUNT" | \
awk '{print $3}' | sed 's/\.[0-9]*$//' | sort -u | \
while read -r ip; do
  geoiplookup "$ip" 2>/dev/null || true
done | \
grep '^GeoIP Country Edition:' | \
nl -ba | tee countries_numbered.txt | \
awk '
  {total++}
  /, Iran, Islamic Republic of/ {ir++}
  END {
    if (total==0) {print "TOTAL=0 IR=0 PCT=0.00%"; exit}
    printf "\nTOTAL=%d\nIR=%d\nPCT=%.2f%%\n", total, ir, (ir*100.0/total)
  }
'
