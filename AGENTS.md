# Agents Guide

Nix flake packaging [copilot-api](https://github.com/ericc-ch/copilot-api) with a NixOS module.

## Project structure

- `flake.nix` — Flake definition with packages, overlay, and nixosModules outputs
- `package.nix` — Nix derivation using bun2nix to build copilot-api
- `bun.nix` — Auto-generated bun dependency lock (do not edit manually)
- `module.nix` — NixOS module exposing `services.copilot-api` with systemd service
- `update.sh` — Script to bump to latest upstream release (updates version, hash, and bun.nix)

## Key conventions

- Supported systems: `x86_64-linux`, `aarch64-linux`
- nixpkgs input is sourced from FlakeHub, published as `stfl/copilot-api`
- The NixOS module uses `DynamicUser` and `LoadCredential` for the GitHub token — secrets must never end up in the Nix store
- CLI flags are mapped to `services.copilot-api.settings` options using camelCase (e.g. `--account-type` becomes `accountType`)

## Updating to a new upstream version

Run `./update.sh` — it fetches the latest release, updates the source hash in `package.nix`, and regenerates `bun.nix`.

## Verification

Run `nix flake check` to validate the flake outputs and module evaluation.
