# Fairphone 5 (fairphone-fp5)

## Setup Instructions

These instructions require `fastboot`. You can access it with `nix-shell -p android-tools`.

### Prep Work

Your device's bootloader needs to be unlocked. Follow the instructions on the
[Nura Wiki](<https://wiki.nura.eco/wiki/Fairphone_5_(fairphone-fp5)>).

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

Copy `examples/installConfigs/fairphone5` from this repository
into your NixOS configuration.

Now:

- Add `vanilla-mobile-nixos` and `disko` to your inputs.
- Add the `fairphone5` example as a NixOS configuration.
- Import the `vanilla-mobile` and `disko` modules in that config.

Here's a simple example of that for flakes:

`flake.nix`

```nix
{
  inputs = {
    # You should use `nixos-unstable` as your nixpkgs version for this.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Don't set `inputs.nixpkgs.follows`, to avoid cache misses.
    vanilla-mobile-nixos.url = "github:vanilla-mobile-nixos/vanilla-mobile-nixos";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      vanilla-mobile-nixos,
      disko,
      ...
    }:
    {
      # Create a NixOS configuration for `fairphone5`.
      nixosConfigurations.fairphone5 = nixpkgs.lib.nixosSystem {
        modules = [
          # Import the `vanilla-mobile` module.
          vanilla-mobile-nixos.nixosModules.vanilla-mobile
          # Import the `disko` module.
          disko.nixosModules.disko
          # Import the example config.
          ./hosts/fairphone5/configuration.nix
        ];
      };
    };
}
```

For Home Manager users, there's an additional `homeManagerModules.vanilla-mobile` module
available.

## NixOS Image Building

The Fairphone 5 is an aarch64 device. If you don't have an aarch64 computer to build the
installer on, you'll have to enable binfmt emulation.
You can enable binfmt emulation by adding the following to your PC system configuration:

```nix
boot.binfmt.emulatedSystems = [
   (lib.mkIf (pkgs.stdenv.hostPlatform.system != "aarch64-linux") "aarch64-linux")
];
```

If you enable binfmt, you'll also need to set `vanilla-mobile.installer.buildSystem`
in your phone config to the output of `nix-instantiate --eval --expr "(import <nixpkgs> {}).stdenv.system"`.

Before continuing, make sure you've read through and understand the install config.

The cache enabled in the install config, won't work on your PC for building the image
unless you add it to your PC's Nix configuration. You can do that without having it
active all the time with:

```nix
nix.settings = {
  trusted-substituters = [
    "https://vanilla-mobile-nixos.cachix.org"
  ];
  trusted-public-keys = [
    "vanilla-mobile-nixos.cachix.org-1:nicMQxxTD4n6PM9dCvylqsCOCA6M2C6gybbCKrei8AQ="
  ];
};
```

Then, just add `--option extra-substituters https://vanilla-mobile-nixos.cachix.org`
to your build commands as shown below.

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

### SSH Access

Once booted, you should be able to SSH into the phone over USB with `ssh nixos@172.16.42.1`.
If you have a strict SSH config, you may need to do something like:
`ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=yes -o PreferredAuthentications=password nixos@172.16.42.1`

By default, you'll lose SSH once you activate a non-install config. If you want
to maintain the ability to have SSH access _only_ over USB, you can add the following to
your config:

```nix
services.openssh = {
   enable = true;
   # Only allowing SSH over USB.
   openFirewall = false;
   listenAddresses = [
     {
       addr = config.vanilla-mobile.usb-gadget.network.serverAddress;
     }
   ];
 };
```

When you want to use SSH with this, you'll first need to switch to USB developer mode
by selecting the "Developer" option in the notification that will appear on the phone
when you plug it into a computer.

### Starter Config

First, remove the `vanilla-mobile.installer` section from your configuration.

Now, you can add the rest of your config. See [What software should I use?](./software-info.md)
for information and example configs.

Once you've created your starter config, just send it over SSH and reboot:
`nixos-rebuild boot --flake .#fairphone5 --target-host "root@172.16.42.1"`

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
