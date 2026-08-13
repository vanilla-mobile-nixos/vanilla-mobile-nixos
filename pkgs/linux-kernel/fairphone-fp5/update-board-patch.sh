#!/usr/bin/env bash
# Regenerates fairphone-fp5-board-support.patch.
# Usage: ./update-board-patch.sh <mainline tree> <sc7280-mainline tree>
set -euo pipefail
main="${1:?usage: $0 <mainline tree> <sc7280-mainline tree>}"
down="${2:?usage: $0 <mainline tree> <sc7280-mainline tree>}"
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

files=(drivers/media/i2c/Kconfig drivers/media/i2c/Makefile
       arch/arm64/boot/dts/qcom/qcm6490-fairphone-fp5.dts)
for f in "${files[@]}"; do
  [ -f "$main/$f" ] || { echo "ERROR: $f missing from $main" >&2; exit 1; }
  mkdir -p "$tmp/a/$(dirname "$f")" "$tmp/b/$(dirname "$f")"
  cp "$main/$f" "$tmp/a/$f"; cp "$main/$f" "$tmp/b/$f"
done

awk -v s="$here/imx858-kconfig" '
  /^config VIDEO_IMX412$/ && !i { while ((getline l < s) > 0) print l; i=1 }
  { print }
  END { if (!i) { print "ERROR: anchor \"config VIDEO_IMX412\" not found" > "/dev/stderr"; exit 1 } }
' "$tmp/a/drivers/media/i2c/Kconfig" > "$tmp/b/drivers/media/i2c/Kconfig"

echo 'obj-$(CONFIG_VIDEO_IMX858) += imx858.o' >> "$tmp/b/drivers/media/i2c/Makefile"
printf '\n#include "fp5-audio.dtsi"\n#include "fp5-camera.dtsi"\n' \
  >> "$tmp/b/arch/arm64/boot/dts/qcom/qcm6490-fairphone-fp5.dts"

[ -f "$down/drivers/media/i2c/imx858.c" ] || { echo "ERROR: imx858.c missing from $down" >&2; exit 1; }
cp "$down/drivers/media/i2c/imx858.c" "$tmp/b/drivers/media/i2c/imx858.c"
cp "$here/fp5-audio.dtsi" "$here/fp5-camera.dtsi" "$tmp/b/arch/arm64/boot/dts/qcom/"

{
  sed -n '1,/^$/p' "$here/fairphone-fp5-board-support.patch" | sed '/^diff /,$d'
  (cd "$tmp" && diff -Naur a b) || true
} > "$here/fairphone-fp5-board-support.patch"
echo "wrote fairphone-fp5-board-support.patch"
