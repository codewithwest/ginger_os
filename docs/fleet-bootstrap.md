# GingerOS Fleet Bootstrap & Update Design

**Status**: Design (approved 2026-08-15) — implementation pending
**Scope**: Installing GingerOS on a fleet of machines and bootstrapping the
Ginger application stack, with a self-made package manager (`ginger-pkg`)
and a brain-centric update flow.

---

## 1. Fleet topology

```
┌─ INTERNET ───────────────────────────────────────┐
│   HOSTED K8s CLUSTER (same LAN)                    │
│   DATA PLANE — managed infrastructure              │
│   ├── postgres (surveillance_hub + ginger DBs)     │
│   ├── redis  ├── chroma  ├── qdrant                │
│   ├── neo4j  └── n8n (+ task-runners)              │
│   (stateful, backed up, HA)                        │
└───────────────────────────────┬──────────────────┘
                                │ local network (same LAN, low latency)
        ┌───────────────────────┴──────────────────────┐
┌───────▼───────────────┐                    ┌──────────▼───────────┐
│ BRAIN machine          │                    │ ROOM NODES (minimal) │
│ COMPUTE PLANE          │                    │ edge-agent + voice   │
│ ├── Ollama (systemd)   │   LAN             │ pulls updates from   │
│ ├── LiteLLM → Ollama   │◄─────────────────►│ brain over LAN       │
│ ├── api, worker, audio │                    └──────────────────────┘
│ ├── surveillance, livekit, edge-agent
│ ├── face/vision agents
│ └── ginger-update-server (fleet registry)
└────────────────────────
```

**Key rules**
- Only the **brain** needs internet access. Room nodes get everything from the
  brain over LAN.
- The **data plane** (postgres, redis, chroma, qdrant, neo4j, n8n) lives on a
  hosted K8s cluster on the **same LAN**, so latency is minimal. The brain
  connects to it directly over the network.
- Ollama runs natively on the brain as a systemd service, reachable at
  `brain:11434` over the LAN route (no tunnel software).
- **LiveKit never moves to K8s** — WebRTC UDP (`7880/7881 tcp`,
  `50000-50100 udp`) must stay on the brain for room-node connectivity.
- A model upgrade happens once on the brain and the whole fleet inherits it.

## 2. Machine roles & requirements

### Hosted K8s cluster (data plane)

Runs the **stateful** services so the brain stays stateless and small:
postgres (`surveillance_hub` + `ginger` DBs), redis, chroma, qdrant, neo4j,
n8n (+ task-runners). Managed backups, HA, and scaling come from the cluster.

Requirements:
- Same LAN as the brain (minimal latency) — a WAN hop to qdrant/neo4j would
  hurt. If not on LAN, put a private overlay (VPC peering / WireGuard /
  Tailscale) in front; **never** expose managed postgres/qdrant publicly.
- Stateful workloads: StatefulSets + PVCs for qdrant, chroma, neo4j, postgres.

### Brain machine (compute plane)

| Resource | Minimum | Comfortable |
|----------|---------|-------------|
| CPU      | 8 cores  | 8-12 cores  |
| RAM      | 16 GB    | **32 GB**   |
| Disk     | 80 GB    | 120 GB+     |

Container memory caps that drive the floor (from docker-compose.yml):
- `ginger-api`: **4G** (was OOM-killing at 1G)
- `ginger-face-agent`: **8G** (insightface + decode, non-negotiable with faces)
- surveillance / livekit / edge-agent / voice-node / audio / worker: ~5G
- Ollama model RAM: `gemma3:4b` ≈ 4-5 GB

Moving the data plane to K8s frees ~6-8 GB from the brain (it no longer hosts
postgres, redis, chroma, qdrant, neo4j, n8n, litellm-proxy, otel, dev-venv).
The three dominant costs stay local by design: face-agent (8G), Ollama (5G),
api (4G).

GPU is **optional** — it only speeds up larger local models. Tier-5 "cloud"
models in `config.yaml` are served remotely and do not tax the brain.

### Room nodes (minimal)

Same LFS base, but only:
- `ginger-edge-agent` (camera → H.264 → LiveKit room)
- voice node (mic/speaker → brain `/ws/phone`)

Tiny footprint; no internet, no LLM, no storage beyond recordings.

## 3. Update flow (brain = fleet registry, nodes pull)

```
Brain                                    Room node
  ginger-update-server                     ginger-update-agent (systemd)
      │  /check (version)                     │  poll every N
      │  ── current, available ─────────────▶ │
      │  /bundle/<pkg>/<version>              │  download bundle
      │  ── signed .ginger-bundle ──────────▶ │  verify signature/checksum
      │                                       │  stage to /opt/ginger/bundles/
      │                                       │  atomic symlink swap:
      │                                       │    /opt/ginger/current -> v1.2
      │                                       │  systemctl restart <units>
      │                                       │  report result
```

- Versioned directories: `/opt/ginger/bundles/<name>/<version>/`
- Atomic activation: `/opt/ginger/current` is a symlink, flipped to the new
  version. Rollback = point the symlink back and restart.
- Never half-install: stage fully, verify, then swap.

## 4. `ginger-pkg` — the self-made package manager

Standalone static Go binary (same philosophy as the existing
`ginger-installer`: zero runtime deps). Runs on both brain and nodes.

### Layout

```
/opt/ginger/
├── bundles/
│   └── ginger-room-node/
│       ├── 1.0.0/
│       └── 1.1.0/
├── current -> bundles/ginger-room-node/1.1.0   (symlink, atomic swap)
├── manifests/
└── state.json                                  (installed set, versions)
```

### Package bundle

A `.ginger-bundle` is a tarball with:

```
manifest.json      name, version, deps, files, checksums, services, signature
files/             payload (binaries, configs, data)
```

Manifest sketch:

```json
{
  "name": "ginger-room-node",
  "version": "1.1.0",
  "deps": [],
  "files": [
    { "path": "usr/bin/ginger-room-node", "mode": "0755", "sha256": "..." }
  ],
  "services": ["ginger-room-node.service"],
  "signature": "ed25519-base64",
  "signing_key": "brain-ed25519-public"
}
```

### Commands

| Command | Behavior |
|---------|----------|
| `install <bundle>`   | verify signature+checksums, stage, symlink swap, start units |
| `remove <name>`      | stop units, remove bundle + current link |
| `upgrade <bundle>`   | install new version, keep previous for rollback |
| `list`               | show installed packages + active versions |
| `verify <name>`      | re-check file checksums against manifest |
| `status`             | running services, active bundle, health |
| `rollback <name>`    | flip symlink to previous version, restart |

### On the brain
`ginger-pkg` also manages the full stack (all bundled services). It doubles as
the registry that builds and signs bundles (`ginger-pkg bundle create ...`).

### Growth path
Day one has no dependency resolution — install/remove/upgrade/rollback over
versioned bundles. Later, `deps` in the manifest becomes a real resolver, and
the update-agent grows repo/A-B semantics without rearchitecting.

## 5. First-boot bootstrap (in the ISO rootfs) — implemented

`lfs/iso/firstboot/` ships a self-contained payload merged into the rootfs
tarball by `lfs/iso/inject-firstboot.sh` (called from `make-iso.sh`):

- `ginger-firstboot.service` (systemd **one-shot**) runs on first boot.
- `ginger-firstboot.sh` provisions `/opt/ginger`: installs the static
  `ginger-pkg` binary, the trusted `signing.pub`, the signed seed bundle,
  writes the brain address + package to `/opt/ginger/update-server`
  (a systemd EnvironmentFile), and enables `ginger-update.timer`.
- `ginger-update.{service,timer}` — the node pulls signed bundles from the
  brain every 30 min (OnBootSec=2min, OnUnitActiveSec=30min).
- A stamp file (`/opt/ginger/.provisioned`) makes the provisioning one-shot.
- Works fully offline for the base payload; subsequent versions come from the
  brain's update server.
- Injector is idempotent: a deterministic payload fingerprint
  (`<tarball>.firstboot` marker) skips re-merge when nothing changed, so the
  1.9G rootfs cache is rebuilt only once.

## 6. Open items (post-v1 bootstrap)

- [ ] Port the current docker-compose services into `ginger-pkg` bundles
      (native, no Docker on the target).
- [ ] Deploy the data plane (postgres, redis, chroma, qdrant, neo4j, n8n) to
      the hosted K8s cluster as StatefulSets + PVCs; wire brain env URLs to
      the cluster services over LAN.
- [ ] Ed25519 keypair generation + key distribution for signed bundles.
- [ ] update-agent polling interval + health reporting protocol.
- [ ] Room-node bundle: merge edge-agent + voice node into one binary first
      (separate design discussion).
- [ ] Inject the payload into the real `gingeros-lfs-rootfs.tar.gz` cache
      (run `sudo ./lfs/iso/inject-firstboot.sh gingeros-lfs-rootfs.tar.gz`;
      done automatically by the next `make-iso.sh` build).

## 7. Service → target mapping

| Service            | Target                  | Notes |
|--------------------|-------------------------|-------|
| postgres (ginger + surveillance_hub) | K8s data plane | StatefulSet + PVC, backups |
| redis              | K8s data plane | |
| chroma             | K8s data plane | holds memory/embeddings |
| qdrant             | K8s data plane | StatefulSet + PVC |
| neo4j              | K8s data plane | StatefulSet + PVC |
| n8n + task-runners | K8s data plane | |
| litellm-proxy      | brain (or K8s) | thin bridge to Ollama |
| ginger-api         | brain compute plane | 4G cap |
| ginger-worker      | brain (stateless) | needs db + redis only |
| ginger-audio       | brain compute plane | |
| ginger-surveillance| brain compute plane | |
| ginger-livekit     | **brain, never K8s** | WebRTC UDP to room nodes |
| ginger-edge-agent  | brain / room nodes | LAN camera device |
| ginger-voice-node  | room nodes | |
| ginger-vision-agent| brain compute plane | |
| ginger-face-agent  | brain compute plane | 8G cap |
| Ollama             | brain (systemd) | serves all models |
