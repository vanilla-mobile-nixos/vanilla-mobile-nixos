self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.mobile-config-firefox;
in
{
  options.vanilla-mobile.mobile-config-firefox = {
    enable = lib.mkEnableOption "mobile-config-firefox";
    package = lib.mkPackageOption self.packages "mobile-config-firefox" { };

    firefoxPackage = lib.mkPackageOption pkgs "firefox" { };
  };

  config = lib.mkIf cfg.enable {
    # -- Firefox --

    programs.firefox.package = cfg.firefoxPackage.override (prev: {
      extraPoliciesFiles = (prev.extraPoliciesFiles or [ ]) ++ [
        "${cfg.package}/lib/firefox/distribution/policies.json"
      ];

      extraPrefs = (prev.autoConfig or "") + ''
        // Allow autoconfig to run regular JS code.
        pref('general.config.sandbox_enabled', false);

        // Enable touch density.
        pref('browser.uidensity', 2);
      '';
      extraPrefsFiles = (prev.autoConfigFiles or [ ]) ++ [
        "${cfg.package}/lib/firefox/mobile-config-autoconfig.js"
      ];
    });

    # -- Librewolf --
    # Not using policies file, since Librewolf already does most of what it does.

    home.file."${config.programs.librewolf.configPath}/librewolf.overrides.cfg".text = ''
      // Allow `librewolf.cfg` and `librewolf.overrides.cfg` (this file) to run regular JS code.
      pref('general.config.sandbox_enabled', false);

      // Enable touch density.
      pref('browser.uidensity', 2);

      import "${cfg.package}/lib/firefox/mobile-config-autoconfig.js";
    '';
  };
}
