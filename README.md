# Vanilla Mobile NixOS

Everything you need to run standard NixOS on a mobile device.
See device support below. Contributions welcome.

## Why run NixOS on a mobile device?

NixOS's declarative configuration shines best when used with multiple devices. Being
able to use the same workflows, integrations, and software you've already configured
can be a huge benefit.

In a more general sense, freedom on mobile devices is in danger. It's more dire than
Windows and a place that Linux can similarly help. It's natural to point out the
potential problems and rough edges with mobile Linux, but just like the switch from
Windows to Linux, it keeps getting better. What's needed are more passionate people
like probably you, a NixOS user.

## What does "Vanilla" mean?

It means installing NixOS on the device using a standard initramfs and bootloader. Some of
the advantages to this over how mobile-nixos usually works are switching kernels
without reflashing and keeping things simpler and closer to a desktop config.
This is made possible on Android based devices by using U-Boot. Some awesome work has
been done on U-Boot to allow going from the Android bootloader to a UEFI environment.

## What devices are supported?

The main thing that's needed for most devices is U-Boot and kernel/drivers support.
Below is a list of what's already in this repository. For other devices, start with
looking at the [postmarketOS Wiki](https://wiki.postmarketos.org/wiki/Devices) and [this](https://gitlab.postmarketos.org/tauchgang/tauchgang-ci/-/blob/main/devices.toml)
list of devices supported by Tauchgang U-Boot.
Many of the devices that work best for mobile Linux are older devices you can buy
secondhand.

Tested Devices:
- [Xiaomi POCO F1 Tianma (xiaomi-beryllium)](docs/xiaomi-beryllium.md)
  - SIM card currently untested.

Implemented but untested:
- Xiaomi POCO F1 EBBG
  - Will need to be added to alsa-ucm-conf-sdm845 like I did for Tianma [here](https://gitlab.com/sdm845-mainline/alsa-ucm-conf/-/merge_requests/32).
    Run this command to find out what symlink needs to be added:
    `nix-shell -p alsa-utils --run "strace alsaucm reload"`
- SDM845 kernel with non-beryllium devices.
  - OnePlus 6 (oneplus-enchilada)
  - OnePlus 6T (oneplus-fajita)
  - Samsung Galaxy S9 (samsung-starqltechn)
  - SHIFT SHIFT6mq (shift-axolotl)
- Samsung Galaxy A2 Core U-Boot

## What software should I use?

Depending on your tastes, it's possible to keep your mobile config 95% identical
to your desktop config or completely custom. See [docs/software-info.md](./docs/software-info.md)
for specific details and instructions.

## Installation Instructions

See the instructions linked in [the devices list](#what-devices-are-supported) above.

## Acknowledgements

- [postmarketOS](https://postmarketos.org/). Their community is doing incredible work continually pushing things forward for everyone.
- [chayleaf](https://pavluk.org/). They made [a detailed blog post](https://pavluk.org/blog/2023/12/19/oneplus_6.html) on doing this with their OnePlus 6 that I wish I found sooner.
