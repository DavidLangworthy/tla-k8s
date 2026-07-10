# Agent Instructions

This repository models Kubernetes-style Pod, node, GPU, and communication lifecycle behavior in TLA+.

## Verification

Use the Makefile targets:

```sh
make tools
make safety
make stable-liveness
make failure-liveness
```

`make tools` downloads `tla2tools.jar` into `.tools/` unless `TLA2TOOLS` points at a preinstalled jar. Do not vendor the jar in the repository.

The local Mac workspace intentionally does not need Java. Run TLC in GitHub Actions, Codespaces, or another remote Linux environment. In Codespaces, `TLA2TOOLS` points at `/opt/tla2tools/tla2tools.jar`, which is baked into the devcontainer image.

## Modeling Guidelines

- Keep Kubernetes API details abstract unless they affect scheduling, binding, lifecycle, or failure behavior.
- Preserve the split between failure-rich safety checking and stable-cluster liveness checking.
- Add invariants before adding more environment behavior.
- Keep configs small enough for CI; create separate larger exploration configs if needed.
