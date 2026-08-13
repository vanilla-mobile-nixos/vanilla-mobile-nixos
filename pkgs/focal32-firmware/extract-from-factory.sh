#!/usr/bin/env bash
#
# Extract the Fairphone 5 fingerprint TrustZone application ("focal32") from a
# stock factory image, in the split form the QSEECOM TEE driver loads it in
# (focal32.mdt + focal32.b00 .. focal32.b07).
#
# The application is proprietary and device-derived: it ships in no public
# firmware set, so it has to be pulled from the device's own factory image. It
# lives on the modem/firmware partition (NON-HLOS.bin, a FAT filesystem) under
# /image/, alongside a second TA (fingerpr.*), which is copied too.
#
# Usage:
#   extract-from-factory.sh FP5-XXXX-factory.zip [OUTDIR]
#
# OUTDIR defaults to ./focal32. Put the result inside your own configuration
# (it is proprietary and per-device, so it is not shipped with this flake) and
# point the module at it with
#   vanilla-mobile.soc.qcm6490.fingerprint.firmwarePath = ./path/to/focal32;
#
# Needs: unzip, and either mount (via sudo) or 7z. Root is used only to
# loop-mount the FAT image read-only; nothing is written to the device.
set -euo pipefail

ZIP=${1:?usage: extract-from-factory.sh FACTORY.zip [OUTDIR]}
OUT=${2:-./focal32}

[ -f "$ZIP" ] || { echo "no such file: $ZIP" >&2; exit 1; }

work=$(mktemp -d)
cleanup() {
	if mountpoint -q "$work/mnt" 2>/dev/null; then
		sudo umount "$work/mnt" 2>/dev/null || true
	fi
	rm -rf "$work"
}
trap cleanup EXIT

# The factory zip's top directory is named after the build (FP5-VT2Y-factory/),
# so match on the tail rather than a fixed prefix.
member=$(unzip -Z1 "$ZIP" | grep -E '(^|/)images/NON-HLOS\.bin$' | head -1)
[ -n "$member" ] || { echo "NON-HLOS.bin not found in $ZIP" >&2; exit 1; }

echo "extracting $member ..." >&2
unzip -p "$ZIP" "$member" > "$work/NON-HLOS.bin"

mkdir -p "$work/mnt" "$OUT"

# NON-HLOS.bin is a FAT16 image; loop-mount it read-only and copy the TAs out.
echo "mounting firmware partition (needs sudo) ..." >&2
sudo mount -o ro,loop "$work/NON-HLOS.bin" "$work/mnt"

copied=0
for ta in focal32 fingerpr; do
	if [ -f "$work/mnt/image/$ta.mdt" ]; then
		cp "$work/mnt/image/$ta.mdt" "$work/mnt/image/$ta.b"[0-9][0-9] "$OUT/"
		copied=$((copied + 1))
		echo "  $ta: $(ls "$OUT/$ta.mdt" "$OUT/$ta.b"* 2>/dev/null | wc -l) segments" >&2
	fi
done

sudo umount "$work/mnt"

[ "$copied" -gt 0 ] || { echo "no fingerprint TA found under /image" >&2; exit 1; }

chmod -R u+w "$OUT"
echo >&2
echo "extracted to $OUT:" >&2
( cd "$OUT" && sha256sum focal32.mdt 2>/dev/null ) >&2 || true
echo >&2
echo "The focal32.mdt + focal32.b00..b07 are the trusted application. Place" >&2
echo "them in pkgs/focal32-firmware/blobs/ (git-add so the flake sees them)." >&2
