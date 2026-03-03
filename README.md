# copilot-api-flake

Nix flake for [copilot-api](https://github.com/ericc-ch/copilot-api) — a server that exposes GitHub Copilot as an OpenAI/Anthropic-compatible API.

## Usage

### Run directly

```
nix run github:stefandanzl/copilot-api-flake
```

### NixOS module

Add the flake to your inputs:

```nix
{
  inputs.copilot-api.url = "github:stefandanzl/copilot-api-flake";
}
```

Apply the overlay and import the module:

```nix
{ inputs, ... }: {
  nixpkgs.overlays = [ inputs.copilot-api.overlays.default ];
  imports = [ inputs.copilot-api.nixosModules.default ];
}
```

Configure the service:

```nix
{
  services.copilot-api = {
    enable = true;
    githubTokenFile = "/run/secrets/github-token"; # e.g. from agenix/sops-nix
    settings = {
      port = 4141;
      accountType = "individual"; # or "business" / "enterprise"
      # verbose = true;
      # claudeCode = true;
    };
  };
}
```

### Authentication

copilot-api requires a GitHub token with Copilot access. To obtain one, run the bundled helper:

```
nix run github:ericc-ch/copilot-api#github-copilot-api
```

Follow the device-code flow, then place the resulting token in the file referenced by `githubTokenFile`. The NixOS module loads it via systemd `LoadCredential` so it never appears in the Nix store.

### Settings reference

| Option | Type | Default | Description |
|---|---|---|---|
| `port` | int | `4141` | Port to listen on |
| `verbose` | bool | `false` | Verbose logging |
| `accountType` | enum | `"individual"` | `individual`, `business`, or `enterprise` |
| `manual` | bool | `false` | Manual request approval |
| `rateLimit` | null or int | `null` | Rate limit in seconds |
| `wait` | bool | `false` | Wait on rate limit instead of error |
| `claudeCode` | bool | `false` | Claude Code mode |
| `showToken` | bool | `false` | Show tokens on fetch/refresh |
| `proxyEnv` | bool | `false` | Init proxy from env vars |