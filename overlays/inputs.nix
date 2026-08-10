{ inputs, ... }:
{
  # Export overlays coming from inputs directly
  llm-agents = inputs.llm-agents.overlays.shared-nixpkgs;
  ethereum = inputs.ethereum.overlays.default;
  emacs = inputs.emacs-overlay.overlay;
}
