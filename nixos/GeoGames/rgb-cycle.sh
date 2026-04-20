#!/usr/bin/env bash
# Cycles through msi-perkeyrgb presets for GS65
# State is stored in ~/.local/state/msi-rgb-preset

PRESETS=("aqua" "chakra" "default" "disco" "drain" "freeway" "plain" "rainbow-split" "roulette")

STATE_FILE="$HOME/.local/state/msi-rgb-preset"

mkdir -p "$(dirname "$STATE_FILE")"

# Read current index, default to 0
CURRENT=0
if [[ -f "$STATE_FILE" ]]; then
  CURRENT=$(cat "$STATE_FILE")
fi

# Advance to next preset
NEXT=$(( (CURRENT + 1) % ${#PRESETS[@]} ))
echo "$NEXT" > "$STATE_FILE"

PRESET="${PRESETS[$NEXT]}"
exec msi-perkeyrgb --model GS65 -p "$PRESET"
