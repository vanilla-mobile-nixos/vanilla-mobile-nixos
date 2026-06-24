# Mobile specific Hyprland Home Manager config. Additional non-mobile-specific config is
# needed to make this complete.
{
  lib,
  ...
}:
let
  keyboardNamespace = "wvkbd";
  showKeyboardCommand = "systemctl --user kill --signal=SIGUSR2 wvkbd.service";

  mkLua = lib.generators.mkLuaInline;
in
{
  imports = [
    ./gestures.nix
    ./hypridle.nix
    ./wvkbd.nix
  ];

  services.iio-hyprland.enable = true;

  wayland.windowManager.hyprland = {
    settings = {
      config = {
        cursor = {
          hide_on_touch = true;
          # Needed for hide_on_touch to consistently work.
          no_hardware_cursors = 1;
        };
      };

      layer_rule = [
        # Keyboard layer rule.
        {
          match.namespace = keyboardNamespace;
          # Show above app launcher.
          order = -1;
          above_lock = 2;
          animation = "slide";
          blur = true;
        }
      ];

      bind = [
        # Bind phone volume keys to volume up/down.
        {
          _args = [
            "code:115"
            (mkLua ''hl.dsp.exec_cmd("wpctl set-volume -l '1.0' @DEFAULT_AUDIO_SINK@ 1%+")'')
            {
              repeating = true;
              locked = true;
            }
          ];
        }
        {
          _args = [
            "code:114"
            (mkLua ''hl.dsp.exec_cmd("wpctl set-volume -l '1.0' @DEFAULT_AUDIO_SINK@ 1%-")'')
            {
              repeating = true;
              locked = true;
            }
          ];
        }

        # Power on/off/lock.
        {
          _args = [
            "XF86PowerOff"
            (mkLua /* lua */ ''
              function()
                hl.timer(function()
                  hl.dispatch(hl.dsp.dpms({ action = "off" }))
                  hl.dispatch(hl.dsp.exec_cmd("loginctl lock-session"))
                end, {timeout = 10, type = "oneshot"})
              end
            '')
          ];
        }
        {
          _args = [
            "XF86PowerOff"
            (mkLua /* lua */ ''
              function()
                hl.timer(
                  function()
                    hl.dispatch(hl.dsp.exec_cmd("hyprctl locked | grep true && hyprctl dispatch 'hl.dsp.dpms()'"))
                    -- Show keyboard for unlocking.
                    hl.dispatch(hl.dsp.exec_cmd("hyprctl locked | grep true && ${showKeyboardCommand}"))
                  end,
                  {timeout = 10, type = "oneshot"})
              end
            '')
            { locked = true; }
          ];
        }
      ];
    };
  };
}
