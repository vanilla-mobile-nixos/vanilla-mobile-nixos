# Vanilla Mobile NixOS

Run standard NixOS on your mobile devices!

This is a WIP hub for packages, modules, and instructions for running NixOS on mobile
devices. I highly recommend trying NixOS out on a mobile device. It gets easier by the month.

Tested Devices:
- [Xiaomi POCO F1 (xiaomi-beryllium)](devices/xiaomi-beryllium/README.md)

Implemented but untested:
- SDM845 kernel with non-beryllium devices.
- Samsung Galaxy A2 Core U-Boot

## What does "Vanilla" mean?

It means installing NixOS on the device using a standard initramfs and bootloader. Some of
the advantages to this over how mobile-nixos usually works are switching kernels
without reflashing and keeping thing simpler and closer to a desktop config.
This is made possible on Android based devices by using U-Boot. Some awesome work has
been done on U-Boot to allow going from the Android bootloader to a UEFI environment.


## Acknowledgements

- [postmarketOS](https://postmarketos.org/). Their community is doing incredible work continually pushing things forward for everyone.
- [chayleaf](https://pavluk.org/). They made [a detailed blog post](https://pavluk.org/blog/2023/12/19/oneplus_6.html) on doing this with their OnePlus 6 that I wish I found sooner.
