# 📦 Archive

This directory holds deprecated or currently unused Kubernetes deployments and configurations kept for reference.

## Structure

The folder mirrors the main repository layout from `/`:

```text
📁 .archive
├── 📁 kubernetes
|   ├── 📁 applications      # kubernetes deployments
|   |   ├── 📁 app           # end-user/workload deployments
|   |   ├── 📁 components    # reusable parts (backup, gpu, zeroscaler, ...)
|   |   └── 📁 infra         # cluster/platform infrastructure deployments
├── ...
└── 📁 talos                 # talos configuration files
    └── 📁 nodes             # talos node specific overrides
```

## Notes

- **Not reconciled:** Manifests in this directory are excluded from Flux CD and are not deployed to the cluster.
- **Excluded from automation:** Files here are ignored by Renovate (`.renovaterc.json5` & `/.renovate`) and CI validation pipelines.
