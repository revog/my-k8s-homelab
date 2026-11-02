# VolSync + Kopia Backup System (DRAFT)

This documents the VolSync backup system for this homelab. It uses Kopia as the backup engine with two backup destinations following a **2-2-1 strategy**: local NFS and offsite Cloudflare R2.

---

## Architecture Overview

### Backup Strategy

```
┌──────────────────────────────────────────┐
│              Application PVC             │
└──────────────────────┬───────────────────┘
                       │
         VolSync ReplicationSources
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
   ┌───────────┐               ┌───────────┐
   │ Local NFS │               │Cloudflare │
   │  (QNAP)   │               │    R2     │
   │ (primary  │               │ (offsite  │
   │  restore) │               │  DR only) │
   └─────┬─────┘               └───────────┘
         │
         │ QNAP Hybrid Backup
         │ (NAS-to-NAS mirror)
         ▼
   ┌───────────┐
   │  Offsite  │
   │    NAS    │
   │  device   │
   └───────────┘

  3 copies, 2 storage types, 1+ offsite  ✓ 3-2-1
```

**3 backup copies per app:**
- **Local NFS (QNAP)** — fast, low-latency, primary restore source
- **QNAP Hybrid Backup → Offsite NAS** — the local NFS share is automatically mirrored by QNAP Hybrid Backup to an offsite NAS device, providing a second physical copy without any Kubernetes involvement
- **Cloudflare R2** — offsite object storage, independent disaster recovery

This satisfies the **3-2-1 rule**: 3 copies, 2 storage types (NAS filesystem + S3 object storage), at least 1 offsite (both the offsite NAS mirror and R2 are offsite).

### Component Directory Structure

```
kubernetes/applications/components/volsync/
├── kustomization.yaml          # Root component: includes local-nfs + cloudflare-s3
├── local-nfs/
│   ├── kustomization.yaml      # NFS component
│   ├── pvc.yaml                # Bootstrap PVC (dataSourceRef → ReplicationDestination)
│   ├── replicationdestination.yaml  # One-time bootstrap restore from NFS
│   ├── replicationsource.yaml       # Recurring backup to NFS
│   └── secret.age.enc.yaml    # SOPS-encrypted Kopia repo credentials (NFS)
└── cloudflare-s3/
    ├── kustomization.yaml      # R2 component
    ├── replicationsource.yaml  # Recurring backup to Cloudflare R2
    └── secret.age.enc.yaml    # SOPS-encrypted Kopia repo credentials (R2)
```

> [!NOTE]
> `cloudflare-s3/pvc.yaml` and `cloudflare-s3/replicationdestination.yaml` exist but are commented out in the component kustomization. R2 is backup-only; restores use NFS. For an S3-only disaster recovery restore, create a `ReplicationDestination` manually.

> [!NOTE]
> **GitOps Workflow**: All changes are made by editing files in Git and pushing to trigger Flux reconciliation—never by running `kubectl apply` directly.

---

## Storage Backend

| Component | Value |
|-----------|-------|
| Storage driver | Longhorn v2 (SPDK / v2 data engine) |
| Default storage class | `longhorn-v2` |
| Snapshot class | `longhorn-v2-snapshots` |
| NFS server | `${STORAGE_IP}` (resolved via Flux substitution) |
| NFS path | `/volsync` |
| Copy method (source) | `Snapshot` |
| Copy method (destination) | `Direct` |
| Compression | `zstd-fastest` |

---

## How It Works

### NFS Mover Volume Injection

Kopia mover pods need access to the NFS repository share. The `moverVolumes` field in both source and destination specs injects the NFS share directly into the mover pod:

```yaml
moverVolumes:
  - mountPath: repository
    volumeSource:
      nfs:
        path: /volsync
        server: ${STORAGE_IP}
```

This mounts the NFS share at `/repository` inside the Kopia mover pod, which Kopia uses as the filesystem repository root. **No MutatingAdmissionPolicy is needed.**

### Credentials: SOPS-encrypted Secrets

Secrets are encrypted with SOPS + age and committed to Git. Flux decrypts them on apply via its SOPS integration (no ExternalSecrets operator needed for VolSync).

**NFS secret** (`${APP}-volsync-secret`):
```
KOPIA_FS_PATH       # Filesystem path inside NFS (e.g. /volsync/<app>)
KOPIA_PASSWORD      # Repository encryption password
KOPIA_REPOSITORY    # Kopia repository type identifier
```

**Cloudflare R2 secret** (`${APP}-volsync-s3-secret`):
```
KOPIA_PASSWORD          # Repository encryption password
KOPIA_S3_BUCKET         # R2 bucket name
KOPIA_S3_ENDPOINT       # R2 endpoint URL
AWS_ACCESS_KEY_ID       # R2 access key
AWS_SECRET_ACCESS_KEY   # R2 secret key
KOPIA_REPOSITORY        # Kopia repository type identifier
```

---

## Component Files

### `local-nfs/replicationsource.yaml` — NFS Backup

```yaml
apiVersion: volsync.backube/v1alpha1
kind: ReplicationSource
metadata:
  name: ${APP}
spec:
  sourcePVC: "${VOLSYNC_CLAIM:=${APP}}"
  trigger:
    schedule: "${VOLSYNC_SCHEDULE:=0 1 * * *}"   # default: daily at 1am
  kopia:
    cacheCapacity: ${VOLSYNC_CAPACITY:=1Gi}
    cacheStorageClassName: ${VOLSYNC_CACHE_SNAPSHOTCLASS:=longhorn-v2}
    compression: zstd-fastest
    copyMethod: ${VOLSYNC_COPYMETHOD:=Snapshot}
    moverSecurityContext:
      runAsUser: ${VOLSYNC_SHARE_UID:=1003}
      runAsGroup: ${VOLSYNC_SHARE_GID:=1003}
      fsGroup: ${VOLSYNC_GID:=1003}
      fsGroupChangePolicy: "Always"
    moverVolumes:
      - mountPath: repository
        volumeSource:
          nfs:
            path: /volsync
            server: ${STORAGE_IP}
    parallelism: 2
    repository: ${APP}-volsync-secret
    retain:
      hourly: 24
      daily: 7
      weekly: 2
    storageClassName: ${VOLSYNC_STORAGECLASS:=longhorn-v2}
    volumeSnapshotClassName: ${VOLSYNC_SNAPSHOTCLASS:=longhorn-v2-snapshots}
```

### `cloudflare-s3/replicationsource.yaml` — R2 Backup

Similar to NFS source but uses `${APP}-volsync-s3-secret` and schedule `${VOLSYNC_S3_SCHEDULE}`. Stagger the R2 schedule ~30 minutes after NFS to avoid contention.

### `local-nfs/replicationdestination.yaml` — Bootstrap Restore

```yaml
apiVersion: volsync.backube/v1alpha1
kind: ReplicationDestination
metadata:
  name: "${APP}-bootstrap"
  labels:
    kustomize.toolkit.fluxcd.io/ssa: IfNotPresent   # Never overwrite once created
  annotations:
    volsync.backube/paused: "true"                  # Paused after restore-once completes
spec:
  trigger:
    manual: restore-once
  kopia:
    copyMethod: Direct
    cleanupCachePVC: true     # Delete Kopia cache PVC after restore completes
    cleanupTempPVC: true      # Delete temp staging PVC after restore completes
    enableFileDeletion: true
    moverVolumes:
      - mountPath: repository
        volumeSource:
          nfs:
            path: /volsync
            server: ${STORAGE_IP}
    repository: ${APP}-volsync-secret
    sourceIdentity:
      sourceName: ${APP}      # Kopia snapshot identity to restore from
    storageClassName: ${VOLSYNC_STORAGECLASS:=longhorn-v2}
    capacity: "${VOLSYNC_CAPACITY:=1Gi}"
```

> [!IMPORTANT]
> `cleanupCachePVC: true` and `cleanupTempPVC: true` instruct VolSync to automatically remove the Kopia cache PVC and temporary staging PVC once the bootstrap restore completes. These are one-time volumes; after the app PVC is populated and running, they are never used again.

### `local-nfs/pvc.yaml` — Bootstrap PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${VOLSYNC_CLAIM}
  labels:
    kustomize.toolkit.fluxcd.io/ssa: IfNotPresent
spec:
  accessModes:
    - ${VOLSYNC_ACCESSMODES:=ReadWriteOnce}
  dataSourceRef:
    kind: ReplicationDestination
    apiGroup: volsync.backube
    name: ${APP}-bootstrap
  resources:
    requests:
      storage: ${VOLSYNC_CAPACITY:=1Gi}
  storageClassName: ${VOLSYNC_STORAGECLASS:=longhorn-v2}
```

> [!NOTE]
> The PVC is named `${VOLSYNC_CLAIM}` (the actual PVC the app mounts, e.g. `paperless-ngx-data`), while the `ReplicationDestination` it references is named `${APP}-bootstrap` (e.g. `paperless-bootstrap`). The `IfNotPresent` SSA label ensures Flux never replaces this PVC once it has been created and bound.


---

## Adding VolSync to an Application

### Step 1: Add the component in the app kustomization

```yaml
# kubernetes/applications/apps/<app>/app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml
  - namespace.yaml
components:
  - ../../../components/volsync
```

### Step 2: Set substitution variables in the Flux Kustomization

```yaml
# kubernetes/applications/apps/<app>/ks.yaml
spec:
  postBuild:
    substitute:
      APP: <app>                              # Used for resource names and Kopia identity
      VOLSYNC_CLAIM: <actual-pvc-name>        # The real PVC the app mounts
      VOLSYNC_CAPACITY: 5Gi                   # PVC size
      VOLSYNC_SCHEDULE: "30 0 * * *"          # NFS backup schedule (cron)
      VOLSYNC_S3_SCHEDULE: "0 1 * * *"        # R2 backup schedule (cron)
      VOLSYNC_UID: "1001"                     # App UID for mover security context
      VOLSYNC_GID: "1001"                     # App GID for mover security context
```

> [!NOTE]
> `APP` is used for naming VolSync resources (`<app>-bootstrap`, `<app>-volsync-secret`) and as the Kopia snapshot source identity.
> `VOLSYNC_CLAIM` is the PVC the `ReplicationSource` reads from. These are deliberately separate because StatefulSet PVCs often have names that differ from the app name (e.g. `pocketid-data-pocketid-0` vs `pocketid`).

### Step 3: Create SOPS-encrypted secrets

Create two encrypted secrets per app (NFS and R2) following the structure of existing secrets:
```
local-nfs/secret.age.enc.yaml     → produces ${APP}-volsync-secret
cloudflare-s3/secret.age.enc.yaml → produces ${APP}-volsync-s3-secret
```

---

## Backup Schedule Reference

| Destination | Variable | Default | Retention |
|-------------|----------|---------|-----------|
| Local NFS | `VOLSYNC_SCHEDULE` | `0 1 * * *` (1am daily) | 24 hourly, 7 daily, 2 weekly |
| Cloudflare R2 | `VOLSYNC_S3_SCHEDULE` | `0 2 * * *` (2am daily) | per-app |

**Live schedules:**

| App | NFS | R2 |
|-----|-----|----|
| paperless | `30 0 * * *` (12:30am) | `0 1 * * *` (1am) |
| pocketid | `0 */4 * * *` (every 4h) | `15 */4 * * *` (every 4h +15m) |

---

## Restoring Data

### Normal Restore (from NFS)

The `ReplicationDestination` (`<app>-bootstrap`) is paused after initial bootstrap. To re-trigger a restore from NFS (e.g. after accidental data loss):

1. Scale down the application
2. Delete the application's working PVC (`${VOLSYNC_CLAIM}`)
3. Patch the `ReplicationDestination` with a new manual trigger:
   ```bash
   kubectl patch replicationdestination <app>-bootstrap -n <ns> \
     --type merge -p '{"spec":{"trigger":{"manual":"restore-'$(date +%s)'"}}}'
   ```
4. Remove the paused annotation so VolSync picks it up:
   ```bash
   kubectl annotate replicationdestination <app>-bootstrap -n <ns> \
     volsync.backube/paused-
   ```
5. Wait for restore to complete:
   ```bash
   kubectl get replicationdestination <app>-bootstrap -n <ns> -w
   ```
6. Scale the application back up

### Disaster Recovery (from Cloudflare R2)

Since the R2 `ReplicationDestination` is not deployed by default, create a one-off manifest pointing to `${APP}-volsync-s3-secret`, apply it manually, then follow the same steps above.

---

## Troubleshooting

### Checking Backup Status

```bash
# All sources (shows last sync, duration, next sync)
kubectl get replicationsource -A

# All destinations (bootstrap state)
kubectl get replicationdestination -A

# Mover pod logs for a running job
kubectl logs -n <ns> -l volsync.backube/mover -f
```

### Force a Manual Backup

```bash
kubectl patch replicationsource <app> -n <ns> \
  --type merge -p '{"spec":{"trigger":{"manual":"force-'$(date +%s)'"}}}'
```

### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| Bootstrap PVC stuck `Pending` | `ReplicationDestination` paused before populator runs | Remove `volsync.backube/paused` annotation and patch trigger |
| `permission denied` on NFS mover | `runAsUser`/`runAsGroup` mismatch | Match `VOLSYNC_UID`/`VOLSYNC_GID` to app UID/GID |
| Backup never completes | Large PVC or slow NFS | Check mover pod logs; consider reducing `parallelism` |

---

## Key Variables Reference

| Variable | Used In | Description |
|----------|---------|-------------|
| `APP` | All resource names | App identifier; also used as Kopia snapshot source identity |
| `VOLSYNC_CLAIM` | `sourcePVC` | Actual PVC name the app mounts (may differ from `APP`) |
| `VOLSYNC_CAPACITY` | PVC size, cache size, destination capacity | Storage size |
| `VOLSYNC_SCHEDULE` | NFS source trigger | Cron schedule for NFS backup |
| `VOLSYNC_S3_SCHEDULE` | R2 source trigger | Cron schedule for R2 backup |
| `VOLSYNC_UID` / `VOLSYNC_GID` | moverSecurityContext | App user/group IDs |
| `VOLSYNC_STORAGECLASS` | PVC, destination | Longhorn storage class (default: `longhorn-v2`) |
| `VOLSYNC_SNAPSHOTCLASS` | Source snapshot | Longhorn snapshot class (default: `longhorn-v2-snapshots`) |
| `STORAGE_IP` | moverVolumes NFS server | NFS server IP (set globally in Flux cluster vars) |

---

## Glossary

| Term | Definition |
|------|------------|
| **VolSync** | Kubernetes operator that orchestrates PVC backup/restore via mover pods |
| **Kopia** | Backup engine with deduplication, compression, and encryption |
| **Mover Pod** | Temporary pod created by VolSync to run a backup or restore job |
| **ReplicationSource** | CRD defining a backup job (schedule, source PVC, retention) |
| **ReplicationDestination** | CRD defining a restore target; used for bootstrap and paused after first run |
| **Bootstrap** | One-time process of populating a fresh PVC from backup on first deploy |
| **`IfNotPresent` SSA** | Flux Server-Side Apply strategy that skips updating a resource if it already exists |
| **SOPS** | Secret encryption tool; secrets are age-encrypted and committed to Git |
