self:
{ lib, pkgs, ... }:
{
  imports = (lib.remove self.nixosModules.vanilla-mobile (lib.attrValues self.nixosModules)) ++ [
    (import ./sdm845.nix self)
    (import ./xiaomi-beryllium.nix self)
  ];

  # Enable Modem Manager quick suspend and resume support. Without it,
  # Modem Manager will crash and not resume properly after a suspend.
  # See <https://gitlab.freedesktop.org/mobile-broadband/ModemManager/-/work_items/1039>
  systemd.services.ModemManager.serviceConfig.ExecStart = [
    "" # Ignore original ExecStart
    "${pkgs.modemmanager}/bin/ModemManager --test-quick-suspend-resume"
  ];

  # People typically have single presses toggle the display/suspend, not a full poweroff.
  services.logind.settings = {
    Login.HandlePowerKey = lib.mkDefault "ignore";
    Login.HandlePowerKeyLongPress = lib.mkDeafult "poweroff";
  };
}
