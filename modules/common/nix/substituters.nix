{
  nix.settings = {
    # given the users in this list the right to specify additional substituters via:
    #    1. `nixConfig.substituers` in `flake.nix`
    #    2. command line args `--options substituers http://xxx`
    # substituers that will be considered before the official ones(https://cache.nixos.org)
    substituters = [
      # cache mirror located in China
      # "https://mirrors.ustc.edu.cn/nix-channels/store"
      # "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"

      # public binary cache hosted in Germany (TUM), queried before the official CDN
      # it is an additional cache, not a full cache.nixos.org mirror
      "https://cache.dos.cit.tum.de?priority=5"

      # official nix cache mirror, high priority
      "https://cache.nixos.org?priority=10"
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"

      "https://yazi.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://cache.numtide.com"
      "https://mst-mkt.cachix.org"
    ];
    trusted-public-keys = [
      "cache.dos.cit.tum.de-1:ZCSRbf/HsV0XwrrfR4dC6HyrjqwqKXmR/hDPsYyZ9Sg="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "mst-mkt.cachix.org-1:Ap1WSTd2tPEsFkNutQ7+X8OGtv7kOy9Q+xzvBvcL7FU="
    ];
  };
}
