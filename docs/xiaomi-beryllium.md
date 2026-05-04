# Xiaomi POCO F1 (xiaomi-beryllium)

## Setup Instructions

These instructions require `fastboot`. You can access it with `nix-shell -p android-tools`.
If you have trouble getting some `fastboot` commands to work, you may need to try other
USB cables/ports. Plugging into a multi-port external USB hub has worked for me.

## Prep Work

- Your device's bootloader needs to be unlocked. If it's unlocked, it will say so during
  the boot process. To unlock the bootloader, follow [these](https://wiki.lineageos.org/devices/beryllium/install/#unlocking-the-bootloader) instructions.
- Note down your device's touchscreen variant. You can find this out by following [these](https://wiki.postmarketos.org/wiki/Xiaomi_POCO_F1_(xiaomi-beryllium)#Know_your_touchscreen_variant) instructions.
- Update your device's firmware following [these](https://wiki.lineageos.org/devices/beryllium/fw_update) instructions.

## Add

### U-Boot

U-Boot is what will create a UEFI boot environment compatible with standard tools like systemd-boot.
It will be flashed to your devices `boot` partition.

- Build the U-Boot boot image. Which image to use depends on which display panel your phone has:
  - EBBG: `nix-build -A packagesCross.aarch64-multiplatform.ubootPackages.xiaomi-beryllium-ebbg-boot-image`
  - Tianma: `nix-build -A packagesCross.aarch64-multiplatform.ubootPackages.xiaomi-beryllium-tianma-boot-image`
- Go into fastboot mode on the phone.
- Flash u-boot to the phone: `fastboot erase dtbo erase boot flash boot result/u-boot.img`
- Run `fastboot reboot`. Do not reboot manually.

## Flash Your Installer Image

- Get the images builder script: `nix build .#nixosConfigurations.beryllium-installer.config.system.build.diskoImagesScript`
- Build the NixOS boot and root images: `./result --pre-format-files (read -s -P "LUKS Password: " | psub) /tmp/nixos-root.key`
- Flash the images: `fastboot erase system flash system nixos-boot.raw erase userdata flash userdata nixos-root.raw reboot`
- Flash the NixOS boot image to the phone's system partition: `fastboot erase system flash system nixos-boot.raw`
- Flash the NixOS root image to the phone's userdata partition: `fastboot erase userdata flash userdata nixos-root.raw`
- Reboot the phone with `fastboot reboot`. It may take a while. DO NOT manually reboot or interrupt the command.

## SSH Access

- `nix build .#nixosConfigurations.beryllium-installer.config.system.build.installerSSHWrapper -o installerSSHWrapper`

## Installation
- Build the system and add it to the device's bootloader: `NIX_SSHOPTS="$(cat installerSSHWrapper/bin/ssh-opts)" nixos-rebuild boot --flake .#<HOST_NAME> --target-host "root@<IP_ADDRESS>"`
- Reboot into the system!

