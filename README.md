# Vanilla Mobile NixOS

Run standard NixOS on your mobile devices!

This is a WIP hub for packages, modules, and instructions for running NixOS on mobile
devices. I highly recommend trying NixOS out on a mobile device. It gets easier by the month.

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

Tested Devices:
- [Xiaomi POCO F1 Tianma (xiaomi-beryllium)](docs/xiaomi-beryllium.md)

Implemented but untested:
- Xiaomi POCO F1 EBBG
- SDM845 kernel with non-beryllium devices.
  - OnePlus 6 (oneplus-enchilada)
  - OnePlus 6T 	(oneplus-fajita)
  - Samsung Galaxy S9	(samsung-starqltechn)
  - SHIFT SHIFT6mq (shift-axolotl)
- Samsung Galaxy A2 Core U-Boot

## What software should I use?

Depending on your tastes it's totally possible to keep your mobile config 95% identical
to your desktop config.

The first choice is what desktop environment to use.

### Desktop Environments

See [here](https://wiki.postmarketos.org/wiki/Category:Interface#Mobile_phones) for an
overview of what mobile specific desktop environments are available. I haven't tested
them on NixOS. If you lean more
towards standalone compositors or want to keep what you use on Desktop, don't worry!
It's surprisingly easy to get them working well. All it really takes are a few gestures
and an on-screen keyboard.

#### Sway and River

There's a project called Sxmo or Simple X Mobile dedicated to making these compositors
work well on mobile. I haven't tested it. You can also do it yourself similar to what I do for
Hyprland.

#### Hyprland

- Gestures: [hyprgrass](https://github.com/horriblename/hyprgrass)
- Auto Rotation: [iio-hyprland](https://github.com/JeanSchoeller/iio-hyprland/)

#### Niri

Promising for mobile. Good NixOS support. Have not tested yet.

- Auto Rotation: [iio-niri](https://github.com/Zhaith-Izaliel/iio-niri)

#### Catacomb

A Wayland compositor made specifically for smart phones. Gestures and window
management for free. No NixOS support or testing yet.

### General Software

If you're using a desktop environment it may already come with or have recommendations for
these categories of software.

#### Keyboard

- [wvkbd](https://github.com/jjsullivan5196/wvkbd) is simple, compatible, and easy to
set-up.
- [Stevia](https://gitlab.gnome.org/World/Phosh/stevia) is very featureful. I haven't
tried to set it up independent of Phosh where it's designed for.

## Acknowledgements

- [postmarketOS](https://postmarketos.org/). Their community is doing incredible work continually pushing things forward for everyone.
- [chayleaf](https://pavluk.org/). They made [a detailed blog post](https://pavluk.org/blog/2023/12/19/oneplus_6.html) on doing this with their OnePlus 6 that I wish I found sooner.
