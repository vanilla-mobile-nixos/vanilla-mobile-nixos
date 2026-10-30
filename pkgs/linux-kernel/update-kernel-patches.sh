#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash nixfmt
set -eu -o pipefail

if (( $# != 4 )); then
    echo "Usage: $(basename "$0") <soc> <path to kernel repo> <Linux ref> <SoC ref>"
    echo "Ex: $(basename "$0") sdm845 ~/src/sdm845-linux v7.1-rc1 sdm845-7.1-rc1-r0"
    echo "Ex: $(basename "$0") sc7280 ~/src/sc7280-linux v7.3 v7.3.0-sc7280"
    exit 1
fi

soc="$1"
kernel_repo="$2"
linux_ref="$3"
soc_ref="$4"
patches_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/$soc/kernel-patches
patches_list_file="$patches_dir/default.nix"

if [[ ! -d "$patches_dir/.." ]]; then
    >&2 echo "Unknown SoC: $soc"
    exit 1
fi

pushd "$kernel_repo"

if ! git rev-parse --verify --quiet "$soc_ref^{commit}" > /dev/null; then
    >&2 echo "$soc_ref doesn't exist. Fetch it first."
    exit 1
fi

if ! git rev-parse --verify --quiet "$linux_ref^{commit}" > /dev/null; then
    >&2 echo "Linux ref, $linux_ref doesn't exist. Searching for matching release commit."
    linux_ref=$(git log -n 1 --pretty=format:"%H" --grep "^Linux ${linux_ref#v}$" "$soc_ref~1000..$soc_ref")
    if [[ -z "$linux_ref" ]]; then
	>&2 echo "Linux commit not found."
	exit 1
    fi
    echo "Found matching Linux release commit: $linux_ref"
fi

mkdir -p "$patches_dir"
rm -f "$patches_dir"/*.patch

echo "[" > "$patches_list_file"
git format-patch "$linux_ref..$soc_ref" -o "$patches_dir" |
while read -r patch_path; do
    # Filter out patches with no changes. These are usually cover letters.
    if ! grep -q "diff --git a/" "$patch_path"; then
	echo "# Patch makes no changes." >> "$patches_list_file"
	p="#"
    else
	p=""
    fi
    echo "$p {" >> "$patches_list_file"
    echo "$p name = \"$(basename -s .patch "$patch_path")\";" >> "$patches_list_file"
    echo "$p patch = ./$(basename "$patch_path");" >> "$patches_list_file"
    echo "$p }" >> "$patches_list_file"
done
echo "]" >> "$patches_list_file"
nixfmt "$patches_list_file"

popd
