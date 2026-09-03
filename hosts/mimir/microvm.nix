{ inputs, ... }:
{
  imports = [ inputs.microvm.nixosModules.microvm ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    mem = 2560;
    machineId = "356f873d-454c-4afc-bc92-a499bce5d4ed";
    socket = null;

    interfaces = [
      {
        type = "user";
        id = "mimir";
        mac = "02:00:00:00:00:01";
      }
    ];

    forwardPorts = [
      {
        from = "host";
        host = {
          address = "127.0.0.1";
          port = 10022;
        };
        guest.port = 22;
      }
    ];

    shares = [
      {
        proto = "9p";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        readOnly = true;
      }
    ];
  };
}
