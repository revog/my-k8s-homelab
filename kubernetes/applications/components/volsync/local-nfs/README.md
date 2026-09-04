# 📝 How to trigger a manual PV restore via kubectl

When an app is wiped and redeployed, Flux defaults to generating a blank volume. 
To trigger a safe data restore without battling the Flux GitOps reconciliation loop, execute the following sequence.

## 1. Temporarily pause Flux reconciliation
Disable Flux reconciliation for the restore resource:
```bash
kubectl annotate replicationdestination <RESTORE-NAME> fluxcd.io/reconcile=disabled -n <NAMESPACE>
```

## 2. Trigger the restore
Patch a unique trigger value (for example, the current Unix timestamp) to initiate the restore:
```bash 
kubectl patch replicationdestination <RESTORE-NAME> -n <NAMESPACE> --type merge -p '{"spec":{"trigger":{"manual":"restore-'$(date +%s)'"}}}'
```
                              
## 3. Monitor restore progress
Watch the restore resource until it reports a successful and ready state:
```bash 
kubectl get replicationdestination <RESTORE-NAME> -n <NAMESPACE> -w
```

## 4. Re-enable Flux reconciliation
Once the application pod has started successfully, hand control back to Flux:
```bash 
kubectl annotate replicationdestination <RESTORE-NAME> fluxcd.io/reconcile- -n <NAMESPACE>
```
