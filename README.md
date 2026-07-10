# Kubernetes Pod/Node/GPU Lifecycle Model

This repository contains a small TLA+ model for reasoning about a Kubernetes-style scheduler/plugin under Pod lifecycle, node lifecycle, slow/faulty GPU, cordon, node failure, and transient communication failures.

The model is intentionally abstract. It treats Kubernetes `Pod` phase as too coarse to be the source state machine and instead models the obligations a scheduler/plugin must preserve around scheduling, reserve/permit/bind, kubelet admission, observed-vs-actual node state, and controller recreation.

## Files

- `K8sPodNodeGpu.tla` is the model.
- `K8sPodNodeGpuSafety.cfg` explores failure-rich behavior and checks safety invariants.
- `K8sPodNodeGpuStableLiveness.cfg` disables disruptive environment actions and checks that schedulable Pods eventually run.
- `K8sPodNodeGpuFailureLiveness.cfg` keeps failures enabled and checks that persistent node/link/GPU faults eventually manifest in Pod state under fair detection.
- `Makefile` wraps TLC commands if `tla2tools.jar` is available.

## Run

```sh
make tools
make safety TLA2TOOLS=/path/to/tla2tools.jar
make stable-liveness TLA2TOOLS=/path/to/tla2tools.jar
make failure-liveness TLA2TOOLS=/path/to/tla2tools.jar
```

In Codespaces, the devcontainer image includes Java and `tla2tools.jar`, so the plain `make safety`, `make stable-liveness`, and `make failure-liveness` targets should work.

## Codespaces

Create a Codespace on `main` with the larger VM and an idle timeout:

```sh
gh codespace create \
  -R DavidLangworthy/tla-k8s \
  -b main \
  --machine standardLinux32gb \
  --idle-timeout 30m \
  --retention-period 72h \
  --devcontainer-path .devcontainer/devcontainer.json
```

To cache the fully built container, enable a Codespaces prebuild in the GitHub UI:

1. Open the repository on GitHub.
2. Go to **Settings > Codespaces > Prebuild configurations**.
3. Add a prebuild for the target branch and `.devcontainer/devcontainer.json`.
4. Use the same region you normally create Codespaces in.

The repository also builds and pushes the devcontainer image to GitHub Container Registry. New Codespaces use `ghcr.io/davidlangworthy/tla-k8s-devcontainer:main`, so Java, TLC, tmux, GitHub CLI helpers, and Codex CLI are already in warm container layers before post-create setup runs.

The checked-in TLC configs are intentionally small enough for CI. To explore a
larger state space, increase `Pods`, `Nodes`, `MaxGeneration`, or
`NodeCapacity` in a copy of the relevant `.cfg` file and run TLC from
Codespaces.

Equivalent direct command:

```sh
java -cp /path/to/tla2tools.jar tlc2.TLC -config K8sPodNodeGpuSafety.cfg K8sPodNodeGpu
```

## Modeling Notes

- `generation[p]` represents controller recreation. A Kubernetes Pod incarnation is scheduled at most once; a replacement Pod is modeled by incrementing the generation after deletion.
- `seenNodeState`, `seenGpuState`, and `seenCordoned` are the scheduler's view. They refresh only when `link[n] = "Up"`, so stale observations can cause realistic bad decisions.
- `nodeState`, `gpuState`, `cordoned`, and `link` are actual environment state.
- `Slow` GPU is not automatically fatal. The model includes `MarkGpuSlow` and `EvictSlowPod` so a plugin/operator policy can either tolerate degraded execution or evict it.
- `cordoned[n]` blocks new scheduling once observed, but it does not evict already-bound Pods.

## Main Checks

Safety invariants include:

- `SingleBinding`: each Pod generation binds to at most one node.
- `NoLeakedReservations`: reserve/permit/bind failures clean up scheduler reservations.
- `NoCapacityOvercommit`: bound and reserved Pods do not exceed abstract node capacity.
- `AssignedImpliesBindHistory`: assigned Pods have a recorded bind event.
- `GateConsistency`: scheduling gates only move from present to removed.

Liveness properties include:

- `StableEventuallyServed`: in a stable healthy cluster, every Pod eventually reaches `Running`, `Degraded`, or `Succeeded`.
- `PersistentContactLossManifests`: if an active Pod loses communication forever, it eventually becomes `Unknown`, `Failed`, `Deleting`, or `Deleted`.
- `PersistentNodeFailureManifests`: persistent node failure eventually manifests in the Pod lifecycle.
- `PersistentSlowGpuHandled`: a persistent slow-GPU degradation is eventually completed, failed, or deleted under fair detection.
- `PersistentReachabilityRefreshesObservation`: once communication to a node remains up, stale scheduler observations are refreshed infinitely often.
