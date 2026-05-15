# Kubernetes Cluster Bootstrap

This directory contains all manifests and instructions required to bring a cluster from **bare-metal Talos nodes (Day‑0)** to a fully functional **GitOps-managed cluster (Day‑1)**. The bootstrap layer is intentionally minimal and deterministic.

# Overview
Bootstrap follows a strict layering model:
```
Talos (Day‑0)
├── Cilium (networking)
└── Flux (GitOps engine)
Flux (Day‑1)
├── globals
├── infrastructure components
└── applications
```
# Bootstrap Flow
Cluster provisioning happens in this orchestrated order:

⚠️ Important rules: Bootstrap is reproducible and must not depend on Flux or any other tools like Helm - simple YAML manifests to be used!

## 1. Day-0: Talos node bootstrap
During deployment process of Talos, [Cilium manifest](cilium/cilium.yaml) (networking) and [Flux manifest](flux/flux.yaml) (GitOps) get applied:
```yaml
cluster:
    network:
        cni:
            name: custom
            urls:
                - https://raw.githubusercontent.com/revog/my-k8s-homelab/refs/heads/main/kubernetes/bootstrap/cilium/cilium.yaml
...
    extraManifests:
        - https://raw.githubusercontent.com/revog/my-k8s-homelab/main/kubernetes/bootstrap/flux/flux.yaml
```

Talos creates a Kubernetes Secret `gsm-auth` This Secret provides the needed credentials for External Secrets Operator (ESO) accessing **Google Secret Manager (GSM)** to fetch the relevant AGE key for future secret decryption. This is defined via `inlineManifests`:
```yaml
cluster:
  inlineManifests:
    - |
      apiVersion: v1
      kind: Secret
      metadata:
        name: gsm-auth
        namespace: infra-flux
      type: Opaque
      stringData:
        credentials.json: |
          {
            ... contents of eso-key.json ...
          }
```
This design intentionally solves the "secret bootstrap problem": Flux cannot decrypt secrets without a key
and the key cannot be stored in Git (sensitive!).

The solution is quite easy: Talos injects GSM auth credentials (encrypted in code) from where ESO the SOPS AGE key retrieves which enables Flux to decrypt encrypted manifests.

## 2. Day-1: Infrastructure bootstrap
Flux does reconsiliate the [infrastructure](/kubernetes/applications/infra) components. 
One of the components in Flux is the Flux controller which connects to Git repository and begins the reconciliation loop.

### Secret bootstrapping (GSM)
Beside other deployments the **External Secrets Operator (ESO)** gets deployed. 

Secrets are not stored in Git in plaintext. ESO uses the previously created `gsm-auth` Secret to authenticate against GSM and fetching SOPS AGE key. Once the AGE private key is retrieved, it is stored as a Kubernetes Secret `sops-age` and Flux is able to decrypt encrypted manifests.

## 3. Day-1: Application bootstrap
After the infratructure part Flux does reconsiliate the [applications](/kubernetes/applications/apps). 

## 4. Day-2: Live operations
Once Flux completes reconciliation the infrastructure becomes stable, applications are deployed and the cluster is fully GitOps-managed. 

New infrastructure components can be added easily to Git and deployed via Flux. Git is the **single source of truth** for the entire cluster. It is not allowed committing plaintext secrets to Git - use AGE encryption exclusively.
