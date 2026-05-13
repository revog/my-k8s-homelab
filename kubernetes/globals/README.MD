# Global values

This folder contains **cluster-wide, non–application-specific configuration** that is shared across multiple applications.

Typical examples of such _“not‑quite secrets”_ are:
- the base domain (`CLUSTER_DOMAIN`)
- cluster name
- environment identifiers

Although these values are not strictly secrets, I avoided commiting them in plaintext to public repositories.
The file is encrypted with SOPS using [age](https://github.com/filosottile/age), so sensitive or environment-specific data never appears in plaintext Git. Flux automatically decrypts this Secret during sync when SOPS is configured.

Global values are stored in a Kubernetes `Secret`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cluster-secret
  namespace: infra-flux
stringData:
  CLUSTER_DOMAIN: example.com
```

Or in a Kubernetes `ConfigMap`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: infra-flux
  name: cluster-config
data:
  CLUSTER_NAME: homelab
```

## Looking-up global values
In standard FluxCD setups, postBuild substitutions in Kustomizations can only reference secrets within the same namespace. This limitation can lead to redundancy and complexity. The [kustomize-mutating-webhook](https://github.com/xunholy/fluxcd-kustomize-mutating-webhook) addresses this challenge by enabling global configuration management.

The webhook listens for Kustomization resources creation or update events. On intercepting such an event, it dynamically injects substitution variables into the Kustomization resource. These variables are fetched from centralized ConfigMaps or Secrets, allowing for consistent and centralized management of configurations used across various namespaces.

## Using global values with Kustomize/Raw YAML
Every YAML manifest being applied in the cluster is processed by the webhook. It searches for variable names and replaces it with the matching value defined in the global secret/configmap.

Example:
```yaml
...

  hostnames:
    - 'webapp.${CLUSTER_DOMAIN}'
...
```
This would insert the cluster domain to get a fully qualified domain name `webapp.example.com`.