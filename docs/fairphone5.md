# Fairphone 5 (fairphone-fp5)

## Setup Instructions

These instructions require `fastboot`. You can access it with `nix-shell -p android-tools`.

### Prep Work

Your device's bootloader needs to be unlocked. Follow the instructions on the
[postmarketOS Wiki](<https://wiki.postmarketos.org/wiki/Fairphone_5_(fairphone-fp5)>).

### How It Differs From Other Devices

The Fairphone 5 doesn't have a spare partition to hold the NixOS boot partition. Instead,
a single GPT disk image containing both the boot (ESP) and root partitions is flashed
to the `userdata` partition. U-Boot and the initrd both map `userdata` as a disk
to find the partitions inside it.

Because of this, `disko-config.nix` defines a single disk with a partition table,
instead of separate boot and root images like other devices. It's configured to use a
LUKS encrypted ext4 root filesystem by default. Set `encrypt = false;` at the top of
it for an unencrypted one.

### NixOS Config

Copy `examples/installConfigs/fairphone5` from this repository into your NixOS
configuration and add it as a NixOS configuration, like the
[POCO F1 instructions](./xiaomi-beryllium.md#nixos-config) show.

## NixOS Image Building

See the [POCO F1 instructions](./xiaomi-beryllium.md#nixos-image-building) for
binfmt and cache setup.

Build the script that will generate the image. For flakes that looks like:
`nix build --option extra-substituters https://vanilla-mobile-nixos.cachix.org .#nixosConfigurations.fairphone5.config.system.build.diskoImagesScript`

Now run the script. It's just `./result` if you aren't using LUKS encryption. If you
are, you'll have to pass in the encryption password like this:
`bash -c 'read -s -p "LUKS Password: " p; tmp=$(mktemp); trap "rm \"$tmp\"" EXIT; echo "$p" > "$tmp"; ./result --pre-format-files "$tmp" /tmp/nixos-root.key'`

This should create `nixos-fairphone5.raw`.

### U-Boot

- Build the U-Boot boot image. For flakes that looks like:
  - `nix build --option extra-substituters https://vanilla-mobile-nixos.cachix.org .#nixosConfigurations.fairphone5.config.vanilla-mobile.deviceInfo.uboot -o u-boot`
- Go into fastboot mode on the phone.
- Flash U-Boot to both slots: `fastboot erase dtbo_a erase dtbo_b flash boot_a u-boot/u-boot.img flash boot_b u-boot/u-boot.img`

### NixOS Image Flashing

- Flash the NixOS image to the phone's `userdata` partition:
  - `fastboot erase userdata flash userdata nixos-fairphone5.raw`
- Reboot the phone with `fastboot reboot`.

The root partition is grown to fill `userdata` on first boot.

### SSH Access and Starter Config

Same as the [POCO F1 instructions](./xiaomi-beryllium.md#ssh-access).

## Optional Hardware

### Fingerprint Sensor

Set `vanilla-mobile.device.fairphone5.fingerprint.enable = true;` and add
`"focal32-firmware"` to `nixpkgs.config.allowUnfreePackages`. The trusted application
it loads is extracted from the stock firmware. This sets up fprintd; enrol with
`fprintd-enroll`, and use `security.pam.services.<name>.fprintAuth` to unlock with it.

### Camera

libcamera's soft ISP tuning for the FP5 sensors is set up automatically. For correct
gain handling, apps can be built against `libcamera-fairphone5`, which adds the FP5
sensor helpers. It isn't used system-wide, since that would rebuild PipeWire.
