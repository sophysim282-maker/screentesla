#!/bin/bash
# macOS-native helper: no Python, Xcode, or third-party packages required.
set -euo pipefail
viewer=${1:-}
peer=${2:-10.7.0.1}
if [[ -z "$viewer" ]]; then
  read -r -p 'Paste the complete ScreenLink hotspot viewer link: ' viewer
fi
case "$viewer" in
  http://*:8080/\?token=*) ;;
  *) echo 'Use the complete http:// hotspot link copied from ScreenLink, including its token.' >&2; exit 1 ;;
esac
case "$peer" in
  *[!0-9.]*|'') echo 'The VPN peer must be an IPv4 address.' >&2; exit 1 ;;
esac
profile=$(mktemp -t screenlink-discovery)
children=()
cleanup() {
  for child in "${children[@]:-}"; do
    if [[ -n "$child" ]]; then kill "$child" 2>/dev/null || true; fi
  done
  rm -f "$profile"
}
trap cleanup EXIT
trap 'exit 0' INT TERM
endpoint="${viewer%%\?*}discovery.json?${viewer#*\?}"
/usr/bin/curl --noproxy '*' --connect-timeout 4 --max-time 6 --fail --silent --show-error "$endpoint" -o "$profile"
field() { /usr/bin/plutil -extract "$1" raw -o - "$profile"; }
if [[ "$(field externalDiscovery)" != true ]]; then
  echo 'Turn ON Mac VPN discovery in ScreenLink, stop/start the receiver, and copy its new link.' >&2
  exit 1
fi
port=$(field port)
host=$(field host)
case "$port" in *[!0-9]*|'') echo 'Invalid AirPlay port.' >&2; exit 1 ;; esac
publish() {
  local name="$1" service="$2" key="$3" index=0 value
  local records=()
  while value=$(/usr/bin/plutil -extract "$key.$index" raw -o - "$profile" 2>/dev/null); do
    records+=("$value")
    index=$((index+1))
  done
  if [[ ${#records[@]} -eq 0 ]]; then echo 'Receiver metadata is missing.' >&2; exit 1; fi
  /usr/bin/dns-sd -P "$name" "$service" local. "$port" "$host" "$peer" "${records[@]}" &
  children+=("$!")
}
publish "$(field name)" _airplay._tcp airplayTXT
publish "$(field raopName)" _raop._tcp raopTXT
echo
echo 'Keep this window open. On iPhone select ScreenLink VPN.'
echo 'Press Control-C to remove the advertisements.'
while kill -0 "${children[0]}" 2>/dev/null && kill -0 "${children[1]}" 2>/dev/null; do
  sleep 1
done
