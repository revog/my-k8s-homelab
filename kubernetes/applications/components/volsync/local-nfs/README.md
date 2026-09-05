# 📝 How to manage VolSync Backups & Trigger a Manual PV Restore

Our GitOps pipeline uses a decoupled two-label system inside the application's `pvc.yaml` to safely separate ongoing backups from the initial volume restoration phase:
* `volsync.backube/backup: "true"` — Enables the cluster-wide `ReplicationSource` for active data protection.
* `volsync.backube/restore: "true"` — Inject the `dataSourceRef` populator (**Only use this during initial deployment if a backup already exists**).

---

## 🚀 Scenario A: Fresh App Deployment (No Existing Backup)

When bootstrapping a completely new application from scratch, you must prevent the PVC from deadlocking while waiting for non-existent backup snapshots.

1. Configure your application's `pvc.yaml` to **opt-out** of the initial restore:
   ```yaml
   metadata:
     name: app-pvc
     labels:
       volsync.backube/backup: "true"
       volsync.backube/restore: "false" # <-- Prevents the PVC from hanging in Pending
   ```
2. Commit and push. The empty volume provisions immediately and the app boots up.
3. Once the app generates its initial data, VolSync will automatically run its first backup schedule.

---

## 🔄 Scenario B: Disaster Recovery (Trigger a Manual Restore)

If an application or PVC was destroyed and you need to restore your historical data from the NFS/S3 backup repository without fighting the Flux GitOps reconciliation loop, follow this sequence:

### 1. Configure the Manifests for Recovery
Before pushing to Git, update the application's `pvc.yaml` to enable the volume populator engine:
```yaml
metadata:
  name: app-pvc
  labels:
    volsync.backube/backup: "true"
    volsync.backube/restore: "true" # <-- Instructs Kustomize to inject the dataSourceRef
```
Or use label `volsync.backube/restore-s3: "true"` if restore is done from S3.
Commit and push. The new PVC will generate and enter a `Pending` state, safely waiting for the data payload.

### 2. Temporarily pause Flux reconciliation
To prevent Flux from overwriting your manual execution triggers during the restoration process, pause reconciliation on the target resource:
```bash
kubectl annotate replicationdestination <RESTORE-NAME> fluxcd.io/reconcile=disabled -n <NAMESPACE>
```

### 3. Trigger the restore execution
Patch a unique trigger value (using the current Unix timestamp) into the `ReplicationDestination` resource to force VolSync to instantly pull down the latest backup snapshot:
```bash
kubectl patch replicationdestination <RESTORE-NAME> -n <NAMESPACE> --type merge -p '{"spec":{"trigger":{"manual":"restore-'\$(date +%s)'"}}}'
```

### 4. Monitor restore progress
Watch the replication lifecycle until it reports a successful, completed, and bound state:
```bash
kubectl get replicationdestination <RESTORE-NAME> -n <NAMESPACE> -w
```
*As soon as the snapshot payload is pulled down, the storage driver will automatically transition the PVC to `Bound` and spin up your application container.*

### 5. Re-enable Flux reconciliation
Once the application pod is up, running, and verified healthy, hand control back to Flux:
```bash
kubectl annotate replicationdestination <RESTORE-NAME> fluxcd.io/reconcile- -n <NAMESPACE>
```
