# Xiaomi POCO F1 (xiaomi-beryllium)

## Setup Instructions

These instructions require `fastboot`. You can access it with `nix-shell -p android-tools`.
If you have trouble getting some `fastboot` commands to work, you may need to try other
USB cables/ports. Plugging into a multi-port external USB hub has worked for me.

### Prep Work

Before installing Linux on the POCO F1:

- Your device's bootloader needs to be unlocked. If it's unlocked, it will say so during
  the boot process. To unlock the bootloader, follow [these](https://wiki.lineageos.org/devices/beryllium/install/#unlocking-the-bootloader) instructions.
- Note down your device's touchscreen variant. You can find this out by following [these](https://wiki.postmarketos.org/wiki/Xiaomi_POCO_F1_(xiaomi-beryllium)#Know_your_touchscreen_variant) instructions.
- Update your device's firmware following [these](https://wiki.lineageos.org/devices/beryllium/fw_update) instructions.

### Installing NixOS

Installing NixOS on the POCO F1 is a bit different than the process for a PC. On a PC,
the standard process would be to flash the NixOS installer image to a thumb drive,
boot into the installer, and run the installation program. That program would
repartition your storage drive and then put NixOS on it.
With U-Boot, we can use the same partitions we're used to on a PC. The problem is it's
not safe to repartion most Android phones. Instead we have to reformat some of the
existing partitions to hold our data. Similar to how the NixOS installer image is
flashed to a thumb drive, we'll use `fastboot` to flash images to the the partitions
on the phone.

Here's the plan:

1. Create a simple "install" NixOS configuration for the phone.
2. Use `disko` to build the configuration into flashable images.
3. Flash U-Boot to the phone.
4. Flash the NixOS configuration images to the phone.
5. Boot into NixOS and customize your config.

Let's get started!

### NixOS Config

Copy `examples/installConfigs/xiaomi-beryllium` from this repository
into your NixOS configuration.

Now:
- Add `vanilla-mobile-nixos` and `disko` to your inputs.
- Add the `xiaomi-beryllium` example as a NixOS configuration.
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
      # Use disko fork until this PR is merged:
      # <https://github.com/nix-community/disko/pull/1008>
      url = "github:JuneStepp/disko/virtual-devices-option";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, vanilla-mobile-nixos, disko, ... }: {
    # Create a NixOS configuration for `xiaomi-beryllium`.
    nixosConfigurations.xiaomi-beryllium = nixpkgs.lib.nixosSystem {
      modules = [
        # Import the `vanilla-mobile` module.
        vanilla-mobile-nixos.nixosModules.vanilla-mobile
        # Import the `disko` module.
        disko.nixosModules.disko
        # Import the example config.
        ./hosts/xiaomi-beryllium/configuration.nix
      ];
    };
  };
}
```

For Home Manager users, there's an additional `homeManagerModules.vanilla-mobile` module
available.

Now open `xiaomi-beryllium/configuration.nix`, and set the value of the commented
out `vanilla-mobile.device.xiaomi-beryllium.displayPanel` to your device's display
variant you identified earlier.

Notice that `./disko-config.nix` is being imported. That file defines the filesystems
that will be flashed to the phone. It's configured to use a LUKS encrypted ext4 root
filesystem by default. If you prefer something else, you can find more example configs
in `examples/diskoConfigs`.

## NixOS Image Building

The POCO F1 is an aarch64 device. If you don't have an aarch64 computer to build the installer
on, you'll have to enable binfmt emulation.
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

Build the script that will generate the images. For flakes that looks like:
`nix build --option extra-substituters https://vanilla-mobile-nixos.cachix.org .#nixosConfigurations.xiaomi-beryllium.config.system.build.diskoImagesScript`

Now run the script. It's just `./result` if you aren't using LUKS encryption. If you
are, you'll have to pass in the encryption password like this:
`bash -c 'read -s -p "LUKS Password: " p; tmp=$(mktemp); trap "rm \"$tmp\"" EXIT; echo "$p" > "$tmp"; ./result --pre-format-files "$tmp" /tmp/nixos-root.key'`

This should create two images. One for the boot partition and one for the root.

### U-Boot

U-Boot is what will create a UEFI boot environment compatible with standard tools like systemd-boot.
It will be flashed to your device's `boot` partition (this is different from our NixOS
boot partition).

- Build the U-Boot boot image. For flakes that looks like:
  - `nix build --option extra-substituters https://vanilla-mobile-nixos.cachix.org .#nixosConfigurations.xiaomi-beryllium.config.vanilla-mobile.deviceInfo.uboot`
- Go into fastboot mode on the phone.
- Flash u-boot to the phone: `fastboot erase dtbo erase boot flash boot result/u-boot.img`
- Do not reboot or power off the phone yet.

### NixOS Image Flashing

- Flash the NixOS boot image to the phone's `system` partition:
  - `fastboot erase system flash system nixos-boot.raw`
- Flash the NixOS root image to the phone's `userdata` partition:
  - `fastboot erase userdata flash userdata nixos-root.raw`
  - It may hang with no output for a while. Be patient.
- Reboot the phone with `fastboot reboot`. It may take a while. DO NOT manually reboot
  or interrupt the command.

### SSH Access

Once booted, you should be able to SSH into the phone over USB with `ssh nixos@172.16.42.1`.
If you have a strict SSH config, you may need to do something like:
`ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=yes -o PreferredAuthentications=password nixos@172.16.42.1`

By default, you'll lose SSH once you activate a non-install config. If you want
to maintain the ability to have SSH access *only* over USB, you can add the following to
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
by selecting the "Developer" option in the notification that will appear when you plug
the phone into a computer.

### Starter Config

First, remove the `vanilla-mobile.installer` section from your configuration.

Now, you can add the rest of your config. See [What software should I use?](./software-info.md)
for information and example configs.

Once you've created your starter config, just send it over SSH and reboot:
`nixos-rebuild boot --flake .#xiaomi-beryllium --target-host "root@172.16.42.1"`

## Troubleshooting

- Trouble connecting to WiFi?
  - See [here](https://wiki.postmarketos.org/wiki/Xiaomi_POCO_F1_(xiaomi-beryllium)#WiFi) for common causes.
    The 5Gz issue, can be fixed in declarative Nix NetworkManager configurations
    with `ensureProfiles.profiles.<PROFILE>.wifi.band = "bg";`.

