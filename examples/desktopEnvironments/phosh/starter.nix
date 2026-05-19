{
  config,
  pkgs,
  ...
}:
let
  # Set your username.
  # defaultUser = ;
in

{
  users.users.${defaultUser} = {
    isNormalUser = true;
    # Remember to change this after booting!
    initialPassword = "147258";
    extraGroups = [
      "wheel"
      "networkmanager"
      "feedbackd"
    ];
  };

  services.xserver.desktopManager.phosh = {
    enable = true;
    user = defaultUser;
    group = "users";
  };

  environment.systemPackages = [
    pkgs.alacritty
    # You can also configure declcaratively with `programs.dconf`.
    pkgs.phosh-mobile-settings
  ];
}
