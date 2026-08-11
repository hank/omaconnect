#!/usr/bin/env bash
set -Eeuo pipefail

# Keep the QML process boundary stable: one tab-separated record per device,
# and a non-zero exit for missing dependencies, D-Bus errors, or bad replies.
base=/modules/kdeconnect

for command in gdbus sed grep tr; do
    command -v "$command" >/dev/null 2>&1 || exit 127
done

gdbus call --session --dest org.freedesktop.DBus \
    --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.NameHasOwner org.kde.kdeconnect \
    | grep -q '(true,)' || exit 69

property() {
    local path=$1 interface=$2 name=$3 reply
    reply=$(gdbus call --session --dest org.kde.kdeconnect \
        --object-path "$path" --method org.freedesktop.DBus.Properties.Get \
        "$interface" "$name") || return 1
    printf '%s\n' "$reply"
}

value() {
    # gdbus quotes strings as <'value'> and scalar values as <value>.
    printf '%s' "$1" | sed -E "s/^\((true|false),\)$/\1/; s/^\(<('([^']|\\\\')*'|[^>]+)>.*$/\1/; s/^<'(.*)'>,?$/\1/; s/^<([^>]*)>,?$/\1/; s/^'(.*)'$/\1/"
}

ids=$(gdbus call --session --dest org.kde.kdeconnect --object-path "$base" \
    --method org.kde.kdeconnect.daemon.devices false false) || exit 69
entries=$(printf '%s' "$ids" | sed -E 's/.*\[//; s/\].*//' | tr ',' '\n' \
    | sed -nE "s/^[[:space:]]*['\"]?([^'\"]+)['\"]?[[:space:]]*$/\1/p")
[[ -n "$entries" || "$ids" =~ \(\[[[:space:]]*\],[[:space:]]*\) ]] || exit 70

while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    path="$entry"
    [[ "$path" == /* ]] || path="$base/devices/$entry"
    id=${path##*/}
    name=$(value "$(property "$path" org.kde.kdeconnect.device name)") || exit 69
    type=$(value "$(property "$path" org.kde.kdeconnect.device type)") || exit 69
    paired=$(value "$(property "$path" org.kde.kdeconnect.device isPaired)") || exit 69
    reachable=$(value "$(property "$path" org.kde.kdeconnect.device isReachable)") || exit 69
    supported=$(property "$path" org.kde.kdeconnect.device supportedPlugins) || exit 69
    plugins=
    for plugin in kdeconnect_battery kdeconnect_ping kdeconnect_share kdeconnect_runcommand; do
        if [[ "$supported" == *"'$plugin'"* || "$supported" == *"<$plugin>"* ]]; then
            plugins="${plugins:+$plugins,}$plugin"
        fi
    done
    charge=-1
    charging=false
    if [[ "$plugins" == *kdeconnect_battery* ]]; then
        battery="$path/battery"
        charge_raw=$(value "$(property "$battery" org.kde.kdeconnect.device.battery charge)") || charge_raw=""
        [[ "$charge_raw" =~ ^[0-9]+$ ]] && charge=$charge_raw
        charging_raw=$(value "$(property "$battery" org.kde.kdeconnect.device.battery isCharging)") || charging_raw=false
        [[ "$charging_raw" == true ]] && charging=true
    fi
    printf 'DEVICE\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$name" "$type" "$paired" "$reachable" "$charge" "$charging" "$plugins"
done <<< "$entries"
