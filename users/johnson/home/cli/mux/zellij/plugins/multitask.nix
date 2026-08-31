{
  config,
  lib,
  pkgs,
  ...
}:
let
  multitask = lib.getExe' pkgs.dot.multitask "multitask.wasm";
  shell = lib.getExe (builtins.getAttr config.my.shell pkgs);
in
{
  programs.zellij.settings = {
    plugins.multitask = {
      _props.location = "file:${multitask}";
      _children = [
        {
          inherit shell;
        }
      ];
    };
  };
}
