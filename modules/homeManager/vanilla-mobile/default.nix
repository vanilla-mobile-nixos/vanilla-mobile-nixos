self:
{
  lib,
  ...
}:
{
  imports =
    (lib.remove self.homeManagerModules.vanilla-mobile (lib.attrValues self.homeManagerModules))
    ++ [
      (import ./mobile-config-firefox.nix self)
    ];
}
