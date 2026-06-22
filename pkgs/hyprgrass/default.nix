# See <https://github.com/NixOS/nixpkgs/pull/526498>.
{
  hyprgrass,
  wf-touch,
  fetchFromGitHub,
}:
(hyprgrass.override {
  wf-touch = wf-touch.overrideAttrs {
    buildInputs = [ ];
    mesonFlags = [
      "-Dtests=disabled"
    ];
  };
}).overrideAttrs
  rec {
    version = "0.55.4";

    src = fetchFromGitHub {
      owner = "horriblename";
      repo = "hyprgrass";
      tag = "hl-${version}";
      hash = "sha256-tCt7FNc1RBHou/ym7B0XzoOqqNq8Df+dizEDkAgJ4U0=";
    };
  }
