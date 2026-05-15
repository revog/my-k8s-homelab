# Application deployments
Applications are categorized by type, which also defines naming and namespace conventions:

| Type  | Purpose                          | Namespace pattern |
|-------|----------------------------------|-------------------|
| app   | User-facing workloads            | `app-<name>`      |
| infra | Cluster infrastructure & tooling | `infra-<name>`    |

Examples:
* Flux → `infra-flux`
* HomeAssistant → `app-homeassistant`

Namespaces are created automatically by GitOps tooling (e.g. Flux with `targetNamespace` or ArgoCD with `CreateNamespace=true`) or explicitly via Kustomize per application. The folder name and type defines the namespace, ensuring:
* No collisions
* Clear ownership
* Predictable resource layout

## Repository Structure

```text
..
└── kubernetes/
    ├── applications/                   # All Kubernetes deployments (GitOps-managed)
    │   ├── infra/                      # Cluster / platform infrastructure
    │   │   └── flux/
    │   │       ├── kustomization.yaml
    │   │       └── app.yaml
    │   └── app/                        # End-user / workload applications
    │       └── homeasistant/
    │           ├── kustomization.yaml
    │           └── app.yaml
    └── bootstrap/                      # ArgoCD bootstrap / App-of-Apps / ApplicationSet
```

# Notes
* `bootstrap/` is applied once manually to install base components (chicken-egg-problem)
* Everything under `applications/` is continuously reconciled
* Designed for Flux patterns
