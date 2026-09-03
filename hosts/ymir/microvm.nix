{
  inputs,
  lib,
  self,
  ...
}:
{
  imports = [ inputs.microvm.nixosModules.host ];

  microvm.vms.mimir = {
    evaluatedConfig = self.nixosConfigurations.mimir;
    autostart = false;
    restartIfChanged = true;
  };

  # The guest is stateless, so stop QEMU directly instead of waiting for QMP.
  systemd.services."microvm@mimir".serviceConfig.ExecStop = lib.mkForce "";
}
