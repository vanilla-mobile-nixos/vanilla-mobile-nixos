# Use Hyprgrass to configure touch gestures. This example adds the following gestures:
#
# --------------------------------------------------
# | Action                   | Gesture             |
# --------------------------------------------------
# | Change workspace         | ←→ bottom edge      |
# | Close window             | ↓↓↓                 |
# | Kill window              | ↓↓↓↓                |
# | Fullscreen window        | ↑↑↑                 |
# | Resize window            | Hold/drag borders   |
# | Float window             | 3 finger tap        |
# | Drag window              | 3 finger long press |
# | Move window +1 workspace | →→→                 |
# | Move window -1 workspace | ←←←                 |
# | Press back and Escape    | ←| or |→ from edges |
# | Press forward            | ↖| or |↗ from edges |
# | Toggle keyboard          | ↑ from bottom edge  |
# | Toggle app launcher      | ↗ from bottom left  |
# --------------------------------------------------
{
  lib,
  pkgs,
  ...
}:
let
  toggleKeyboardCommand = "systemctl --user kill --signal=SIGRTMIN wvkbd.service";
  # I don't yet have a good phone app launcher recommendation.
  toggleAppLauncherCommand = "walker";

  mkLua = lib.generators.mkLuaInline;
in
{
  wayland.windowManager.hyprland = {
    plugins = [ pkgs.hyprlandPlugins.hyprgrass ];

    settings = {
      config.gestures = {
        # Swipe of 10% or more will cause workspace change.
        workspace_swipe_cancel_ratio = 0.10;
      };
      config.plugin.hyprgrass = {
        sensitivity = 5.0;
        edge_margin = 30;
        # This is deprecated upstream, but still necessary.
        # See <https://github.com/horriblename/hyprgrass/issues/391>.
        workspace_swipe_edge = "d";
      };
      "plugin.hyprgrass.bind" = [
        {
          pattern = {
            kind = "swipe";
            fingers = 3;
            direction = "down";
          };
          action = mkLua "hl.dsp.window.close()";
        }
        {
          pattern = {
            kind = "swipe";
            fingers = 4;
            direction = "down";
          };
          action = mkLua "hl.dsp.window.kill()";
        }
        {
          pattern = {
            kind = "swipe";
            fingers = 3;
            direction = "up";
          };
          action = mkLua ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'';
        }

        {
          pattern = {
            kind = "tap";
            fingers = 3;
          };
          action = mkLua "hl.dsp.window.float()";
        }
        {
          pattern = {
            kind = "longpress";
            fingers = 3;
          };
          action = mkLua "hl.dsp.window.drag()";
          mouse = true;
        }

        {
          pattern = {
            kind = "swipe";
            fingers = 3;
            direction = "right";
          };
          action = mkLua ''hl.dsp.window.move({ workspace = "+1" })'';
        }
        {
          pattern = {
            kind = "swipe";
            fingers = 3;
            direction = "left";
          };
          action = mkLua ''hl.dsp.window.move({ workspace = "-1" })'';
        }

        {
          pattern = {
            kind = "edge";
            origin = "right";
            direction = "left";
          };
          action = mkLua /* lua */ ''
            function()
              window = hl.get_active_window() or hl.get_last_window()
              hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Back", window = window }))
              hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "Escape", window = window }))
            end
          '';
        }
        {
          pattern = {
            kind = "edge";
            origin = "left";
            direction = "right";
          };
          action = mkLua /* lua */ ''
            function()
              window = hl.get_active_window() or hl.get_last_window()
              hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Back", window = window }))
              hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "Escape", window = window }))
            end
          '';
        }
        {
          pattern = "edge:r:lu";
          action = mkLua /* lua */ ''
            function()
                window = hl.get_active_window() or hl.get_last_window()
                hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Forward", window = window }))
            end
          '';
        }
        {
          pattern = "edge:r:ru";
          action = mkLua /* lua */ ''
            function()
                window = hl.get_active_window() or hl.get_last_window()
                hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Forward", window = window }))
            end
          '';
        }

        {
          pattern = {
            kind = "edge";
            origin = "down";
            direction = "up";
          };
          action = mkLua ''hl.dsp.exec_cmd("${toggleKeyboardCommand}")'';
        }
        {
          pattern = "edge:d:ru";
          action = mkLua ''hl.dsp.exec_cmd("${toggleAppLauncherCommand}")'';
        }
      ];
    };
  };
}
