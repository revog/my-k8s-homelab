# Globals

This folder contains **cluster-wide, non–application-specific configuration** that is shared across multiple applications.

Typical examples of such _“not‑quite secrets”_ are:
- the base domain (`MY_DOMAIN`)
- cluster name
- environment identifiers

Although these values are not strictly secrets, I avoided commiting them in plaintext to public repositories.
The file is encrypted with SOPS, so sensitive or environment-specific data never appears in plaintext Git. Argo CD automatically decrypts this Secret during sync when SOPS is configured.

Global values are stored in a Kubernetes `Secret`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: global-config
  namespace: infra-argocd
stringData:
  MY_DOMAIN: example.com
````
## Looking-up global values in Helm
Helm-based applications read global values explicitly at render time using Helm’s lookup function.
```yaml
hosts:  - app.{{ (lookup "v1" "Secret" "argocd" "global-config").data.MY_DOMAIN | b64dec }}``
```
What this does:
1. Function `lookup` fetches an existing Kubernetes object from the cluster (Secret/global-config in the argocd namespace)
2. Reads the value `.data.MY_DOMAIN` from the Secret
3. The decoded value is injected into the manifest during Helm rendering

## Using global values with Kustomize/Raw YAML
Kustomize apps do not read globals at render time. Instead, they consume them at runtime using standard Kubernetes mechanisms:

```
env:
- name: MY_DOMAIN
  valueFrom:
      secretKeyRef:
        name: global-config
        key: MY_DOMAIN
```
The application will read the value during exection from the environment.
