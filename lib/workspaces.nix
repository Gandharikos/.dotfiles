{ lib, ... }:
let
  inherit (lib.trivial) mod;

  mkWorkspaceBindings =
    commands: format: n:
    let
      wsDigit = mod n 10;
      key = toString wsDigit;
    in
    builtins.map (cmd: format cmd key (toString n)) commands;

  mkWorkspaces =
    commands: format: n:
    builtins.concatLists (builtins.genList (i: mkWorkspaceBindings commands format (i + 1)) n);

  hyprlandFormat =
    cmd: key: workspaceNum:
    lib.concatStringsSep ", " [
      cmd.modifier
      key
      (
        if cmd ? description then
          (if builtins.isFunction cmd.description then cmd.description workspaceNum else cmd.description)
        else
          cmd.action
      )
      cmd.action
      workspaceNum
    ];

  mkHyprWorkspaceDescription =
    action: workspaceNum:
    let
      isSplit = lib.strings.hasPrefix "split:" action;
      action' = if isSplit then lib.strings.removePrefix "split:" action else action;
      prefix = if isSplit then "Split: " else "";
    in
    if action' == "workspace" then
      "${prefix}Switch to workspace ${workspaceNum}"
    else if action' == "focusworkspaceoncurrentmonitor" then
      "${prefix}Focus workspace ${workspaceNum} (current monitor)"
    else if action' == "movetoworkspace" then
      "${prefix}Move window to workspace ${workspaceNum}"
    else if action' == "movetoworkspacesilent" then
      "${prefix}Move window to workspace ${workspaceNum} (silent)"
    else
      "${prefix}${action'} ${workspaceNum}";

  mkHyprWorkspaces =
    actions: n:
    let
      action0 = builtins.elemAt actions 0;
      action1 = builtins.elemAt actions 1;
      action2 = builtins.elemAt actions 2;
    in
    mkWorkspaces [
      {
        modifier = "$mod";
        action = action0;
        description = mkHyprWorkspaceDescription action0;
      }
      {
        modifier = "$mod SHIFT";
        action = action1;
        description = mkHyprWorkspaceDescription action1;
      }
      {
        modifier = "$mod CTRL";
        action = action2;
        description = mkHyprWorkspaceDescription action2;
      }
    ] hyprlandFormat n;

  mkHyprMoveTo =
    actions: n:
    let
      action0 = builtins.elemAt actions 0;
      action1 = builtins.elemAt actions 1;
    in
    mkWorkspaces [
      {
        modifier = "$mod";
        action = action0;
        description = mkHyprWorkspaceDescription action0;
      }
      {
        modifier = "$mod SHIFT";
        action = action1;
        description = mkHyprWorkspaceDescription action1;
      }
    ] hyprlandFormat n;

  aerospaceFormat = cmd: key: workspaceNum: {
    name = "${cmd.modifier}-${key}";
    value = "${cmd.action} ${workspaceNum}";
  };

  mkAerospaceWorkspaces =
    modKey: n:
    let
      ws = mkWorkspaces [
        {
          modifier = modKey;
          action = "workspace";
        }
        {
          modifier = "${modKey}-shift";
          action = "move-node-to-workspace";
        }
      ] aerospaceFormat n;
    in
    builtins.listToAttrs ws;

  mkOmniwmWorkspaces =
    modKey: n:
    let
      count = if n > 9 then 9 else n;
    in
    builtins.concatLists (
      builtins.genList (i: [
        {
          id = "switchWorkspace.${toString i}";
          binding = "${modKey}+${toString (i + 1)}";
        }
        {
          id = "moveToWorkspace.${toString i}";
          binding = "${modKey}+Shift+${toString (i + 1)}";
        }
      ]) count
    );
in
{
  inherit
    mkWorkspaces
    mkHyprWorkspaces
    mkHyprMoveTo
    mkAerospaceWorkspaces
    mkOmniwmWorkspaces
    ;
}
