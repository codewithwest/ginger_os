# GingerOS Fleet Bootstrap & Update Design

**Status**: Design (approved 2026-08-15) — implementation pending
**Scope**: Installing GingerOS on a fleet of machines and bootstrapping the
Ginger application stack, with a self-made package manager (`ginger-pkg`)
and a brain-centric update flow.

---

## 1. Fleet topology

```
┌─ INTERNET ───────────────────────────────────────────────┐
│  OLLAMA CLOUD (remote inference)                          │
│  └── brain services point OLLAMA_BASE_URL at the cloud    │
└──────────────────────────────┬───────────────────────────┘
                               │ (only the brain needs internet)
┌────────────── i3 / 8GB ──────────────┐   ┌──────── i5 #1 / 8GB ────────┐
│  K3s DATA PLANE (single node)        │   │  BRAIN / COMPUTE PLANE      │
│  ├── postgres (ginger + surveil)     │   │  ├── LiveKit (never moves)  │
│  ├── redis  ├── chroma  ├── qdrant   │   │  ├── api, worker, audio     │
│  ├── neo4j  └── n8n (+ runners)      │   │  ├── surveillance            │
│  └── (cam → its room)                │   │  ├── face/vision agents      │
└──────────────────────────────────────┘   │  ├── ginger-update-server   │
                                          │  └── (cam → its room)       │
                                          └────────────┬───────────────┘
┌──────────────────────────────────────────────────────┴──────────────────┐
│ ROOM NODES (minimal; no internet)                        LAN           │
│  i5 #2 / 8GB (cam → room)    celeron / 4GB (cam → room)                 │
│  celeron / 2GB (cam → room, edge-agent only)                            │
│  each: edge-agent + voice node, pulls updates from brain over LAN       │
└─────────────────────────────────────────────────────────────────────────┘
```

**Rooms (5, each with a dedicated cam laptop)**
- 3 rooms  — i5 #2, celeron/4GB, celeron/2GB
- kitchen/sitting room — i5 #1 (brain cam)
- cinema room — i3 (k3s data-plane cam, edge-agent as a k3s pod)

**Key rules**
- Only the **brain** needs internet access. Room nodes get everything from the
  brain over LAN.
- The **data plane** (postgres, redis, chroma, qdrant, neo4j, n8n) runs as
  pods on a **k3s single node** (i3/8GB) on the **same LAN**, so latency is
  minimal. The brain connects to it directly over the network.
- **Ollama cloud**: no local model on the brain. The stack already reads
  `OLLAMA_BASE_URL` (docker-compose.yml) — point it at the cloud endpoint +
  key. This removes the ~4-5GB Ollama memory cost from the brain entirely.
- **LiveKit never moves to K8s** — WebRTC UDP (`7880/7881 tcp`,
  `50000-50100 udp`) must stay on the brain for room-node connectivity.
- A model upgrade happens once on the brain and the whole fleet inherits it.

## 2. Machine roles & requirements

### k3s single node — data plane (i3 / 8GB)

Runs the **stateful** services so the brain stays stateless and small:
postgres (`surveillance_hub` + `ginger` DBs), redis, chroma, qdrant, neo4j,
n8n (+ task-runners). k3s is the lightest way to get managed-style workloads
on an 8GB laptop.

Requirements:
- Same LAN as the brain (minimal latency) — a WAN hop to qdrant/neo4j would
  hurt.
- Stateful workloads: StatefulSets + PVCs for qdrant, chroma, neo4j, postgres.
- Runs a `ginger-edge-agent` pod for the cinema-room camera (its own cam).
- 8GB budget: postgres ~0.5-1G, qdrant ~1-2G, neo4j ~1-2G, chroma ~0.5G,
  redis ~0.1G, n8n ~0.5G — fits with room to spare.

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
- **No local Ollama** — using Ollama cloud (`OLLAMA_BASE_URL` → cloud), which
  removes the ~4-5GB model cost. On an 8GB brain this is the difference
  between tight and comfortable.

Moving the data plane to the k3s node frees ~6-8 GB from the brain (it no
longer hosts postgres, redis, chroma, qdrant, neo4j, n8n, litellm-proxy, otel,
dev-venv). The two dominant costs stay local by design: face-agent (8G cap,
rarely peaking) and api (4G cap). 8GB total works because the caps rarely
fill simultaneously.

GPU is **optional** — with Ollama cloud it only speeds up any locally-kept
models. Tier-5 "cloud" models in `config.yaml` are served remotely.

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
- [ ] Deploy the data plane to **k3s on the i3** (postgres, redis, chroma,
      qdrant, neo4j, n8n) as StatefulSets + PVCs; wire brain env URLs to the
      k3s service IPs over LAN.
- [ ] Point the brain stack at **Ollama cloud**: set `OLLAMA_BASE_URL` +
      key, keep litellm-proxy as the bridge, verify tier-5 calls.
- [ ] Five room definitions in the registry: 3 rooms, kitchen/sitting-room,
      cinema-room; assign ROOM_ID per cam laptop.
- [ ] edge-agent for the cinema cam as a k3s pod on the i3 (ROOM_ID
      filter already in main.go).
- [ ] update-agent polling interval + health reporting protocol.
- [ ] Room-node bundle: merge edge-agent + voice node into one binary first
      (separate design discussion).
- [ ] Inject the payload into the real `gingeros-lfs-rootfs.tar.gz` cache
      (run `sudo ./lfs/iso/inject-firstboot.sh gingeros-lfs-rootfs.tar.gz`;
      done automatically by the next `make-iso.sh` build).

## 7. Service → target mapping

| Service            | Target                  | Notes |
|--------------------|-------------------------|-------|
| postgres (ginger + surveillance_hub) | k3s data plane (i3) | StatefulSet + PVC, backups |
| redis              | k3s data plane (i3) | |
| chroma             | k3s data plane (i3) | holds memory/embeddings |
| qdrant             | k3s data plane (i3) | StatefulSet + PVC |
| neo4j              | k3s data plane (i3) | StatefulSet + PVC |
| n8n + task-runners | k3s data plane (i3) | |
| edge-agent (cinema cam) | k3s pod (i3) | ROOM_ID=cinema-room |
| Ollama             | **Ollama cloud** | OLLAMA_BASE_URL → cloud endpoint + key |
| litellm-proxy      | brain (or K8s) | thin bridge to Ollama cloud |
| ginger-api         | brain compute plane (i5 #1) | 4G cap |
| ginger-worker      | brain (stateless) | needs db + redis only |
| ginger-audio       | brain compute plane | |
| ginger-surveillance| brain compute plane | |
| ginger-livekit     | **brain, never K8s** | WebRTC UDP to room nodes |
| ginger-edge-agent  | brain / room nodes | LAN camera device |
| ginger-voice-node  | room nodes | |
| ginger-vision-agent| brain compute plane | |
| ginger-face-agent  | brain compute plane | 8G cap |
| Ollama (client)    | brain | OLLAMA_BASE_URL → Ollama cloud |
