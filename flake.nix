{
  description = "GitHub Copilot as OpenAI/Anthropic-compatible API server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    bun2nix,
    ...
  }: let
    eachSystem = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
    pkgsFor = eachSystem (system:
      import nixpkgs {
        inherit system;
        overlays = [bun2nix.overlays.default];
      });
  in {
    packages = eachSystem (system: rec {
      copilot-api = pkgsFor.${system}.callPackage ./package.nix {};
      default = copilot-api;
    });

    overlays.default = final: prev: {
      copilot-api = (final.extend bun2nix.overlays.default).callPackage ./package.nix {};
    };
  };
}
