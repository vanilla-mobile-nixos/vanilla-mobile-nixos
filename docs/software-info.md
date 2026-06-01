# What software should I use?

Depending on your tastes, it's possible to keep your mobile config 95% identical
to your desktop config or completely custom.

The first choice is what desktop environment to use:

## Desktop Environments

See [here](https://wiki.postmarketos.org/wiki/Category:Interface#Mobile_phones) for an
overview with pictures of what mobile specific desktop environments are available.
If you prefer standalone compositors and/or want to keep the one you use on Desktop,
don't worry! It's surprisingly easy to get compositors working well. All it really
takes are a few gestures and an on-screen keyboard.

### Phosh

The primary GNOME stack mobile desktop. A starter config is at
[examples/desktopEnvironments/phosh/starter.nix](../examples/desktopEnvironments/phosh/starter.nix).

Note that in the starter config, the keyboard seems to currently only show in some
applications.

### Plasma Mobile

Module is not in nixpkgs yet, but people have worked on it.
See <https://github.com/NixOS/nixpkgs/issues/432702>.

### Sway or River

There's a project called Sxmo or Simple X Mobile dedicated to making these compositors
work well on mobile. I haven't tested it. You can also do it yourself similar to what I do for
Hyprland.

### Hyprland

- Gestures: [hyprgrass](https://github.com/horriblename/hyprgrass)
- Auto Rotation: [iio-hyprland](https://github.com/JeanSchoeller/iio-hyprland/)

### Niri

Promising for mobile. Good NixOS support. Have not tested yet.

- Auto Rotation: [iio-niri](https://github.com/Zhaith-Izaliel/iio-niri)

### Catacomb

A Wayland compositor made specifically for smart phones. Gestures and window
management for free. No NixOS support or testing yet.

## General Software

If you're using a desktop environment it may already come with or have recommendations for
these categories of software.

A great place to browse for mobile friendly apps is <http://linuxphoneapps.org/>.

### Keyboard

- [wvkbd](https://github.com/jjsullivan5196/wvkbd) is simple, compatible, and easy to
set up.
- [Stevia](https://gitlab.gnome.org/World/Phosh/stevia) is featureful. I haven't
tried to set it up independent of Phosh where it's designed for.

### Terminal

There aren't many with support for touch gestures. I recommend using Alacritty.

Supported:
- [Alacritty](https://alacritty.org/)
- [Gnome Console](https://apps.gnome.org/Console/)
  - Only scrolling. No zoom or selection.
- [QMLKonsole](https://apps.kde.org/qmlkonsole/)
  - No zoom.

Unsupported:
- Ghostty
  - Feature request: <https://github.com/ghostty-org/ghostty/discussions/5562>
  - Has semi-working scrolling support.
- Kitty
  - Feature request: <https://github.com/kovidgoyal/kitty/issues/984>
- LXTerminal
  - Only selection.
- Wezterm

### Browser

There are multiple mobile focused low resource usage browsers available. It's also
possible to use a mobile customized Firefox. See [Firefox](#firefox).

#### Firefox

Firefox works great on mobile with a few changes from the [mobile-config-firefox](https://gitlab.postmarketos.org/postmarketOS/mobile-config-firefox) project.
You can easily add this to your existing NixOS or Home Manager Firefox or Librewolf config
with `vanilla-mobile.mobile-config-firefox.enable = true;`.
With this enabled, you should use `vanilla-mobile.mobile-config.firefox.firefoxPackage`
instead of `programs.firefox.package` when you need to change the Firefox package.
`librewolfPackage` for Librewolf.

